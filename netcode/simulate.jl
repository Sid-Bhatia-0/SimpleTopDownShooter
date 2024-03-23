import Base64
import DataFrames as DF
import GarishPrint as GP
import HTTP
import Random
import SHA
import Sockets
import Sodium
import Statistics

include("protocol_constants.jl")
include("types.jl")
include("serialization.jl")

const NULL_NETCODE_ADDRESS = NetcodeAddress(0, 0, 0, 0)

const NULL_CLIENT_SLOT = ClientSlot(false, NULL_NETCODE_ADDRESS)

const PROTOCOL_ID = parse(TYPE_OF_PROTOCOL_ID, bytes2hex(SHA.sha3_256(cat(NETCODE_VERSION_INFO, Vector{UInt8}("Netcode.jl"), dims = 1)))[1:16], base = 16)

const RNG = Random.MersenneTwister(0)

const SERVER_SIDE_SHARED_KEY = rand(RNG, UInt8, SIZE_OF_KEY)

const ROOM_SIZE = 3

const TIMEOUT_SECONDS = TYPE_OF_TIMEOUT_SECONDS(5)

const CONNECT_TOKEN_EXPIRE_SECONDS = 10

const AUTH_SERVER_ADDRESS = Sockets.InetAddr(Sockets.localhost, 10000)

const APP_SERVER_ADDRESSES = [Sockets.InetAddr(Sockets.localhost, 10001)]

const APP_SERVER_ADDRESS = APP_SERVER_ADDRESSES[1]

@assert 1 <= length(APP_SERVER_ADDRESSES) <= MAX_NUM_SERVER_ADDRESSES

# TODO: salts must be randomly generated during user registration
const USER_DATA = DF.DataFrame(username = ["user$(i)" for i in 1:3], salt = ["$(i)" |> SHA.sha3_256 |> bytes2hex for i in 1:3], hashed_salted_hashed_password = ["password$(i)" |> SHA.sha3_256 |> bytes2hex |> (x -> x * ("$(i)" |> SHA.sha3_256 |> bytes2hex)) |> SHA.sha3_256 |> bytes2hex for i in 1:3])

const CLIENT_USERNAME = "user1"
const CLIENT_PASSWORD = "password1"

function pprint(x)
    GP.pprint(x)
    println()
    return nothing
end

function get_time(reference_time)
    # get time (in units of nanoseconds) since reference_time
    # places an upper bound on how much time can the program be running until time wraps around giving meaningless values
    # the conversion to Int will actually throw an error when that happens

    t = time_ns()

    if t >= reference_time
        return Int(t - reference_time)
    else
        return Int(t + (typemax(t) - reference_time))
    end
end

function simulate_update!(game_state, debug_info)
    update_time_theoretical = 2_000_000
    push!(debug_info.update_time_theoretical_buffer, update_time_theoretical)
    update_start_time = get_time(game_state.reference_time)
    sleep(update_time_theoretical / 1e9)
    update_end_time = get_time(game_state.reference_time)
    push!(debug_info.update_time_observed_buffer, update_end_time - update_start_time)

    return nothing
end

function sleep_to_achieve_target_frame_rate!(game_state, debug_info)
    sleep_time_theoretical = max(0, game_state.target_ns_per_frame * game_state.frame_number - get_time(game_state.reference_time))
    push!(debug_info.sleep_time_theoretical_buffer, sleep_time_theoretical)

    sleep_start_time = get_time(game_state.reference_time)
    sleep(sleep_time_theoretical / 1e9)
    sleep_end_time = get_time(game_state.reference_time)
    push!(debug_info.sleep_time_observed_buffer, sleep_end_time - sleep_start_time)

    return nothing
end

function create_df_debug_info(debug_info)
    return DF.DataFrame(
        # :frame_end_time_buffer => debug_info.frame_end_time_buffer,
        :frame_time => debug_info.frame_time_buffer,
        :update_time_theoretical => debug_info.update_time_theoretical_buffer,
        :update_time_observed => debug_info.update_time_observed_buffer,
        :sleep_time_theoretical => debug_info.sleep_time_theoretical_buffer,
        :sleep_time_observed => debug_info.sleep_time_observed_buffer,
    )
end

function start_app_server(app_server_address, room_size)
    room = fill(NULL_CLIENT_SLOT, room_size)

    socket = Sockets.UDPSocket()

    Sockets.bind(socket, app_server_address.host, app_server_address.port)

    @info "Server started listening"

    while true
        client_address, data = Sockets.recvfrom(socket)

        if isempty(data)
            continue
        end

        if data[1] == PACKET_TYPE_CONNECTION_REQUEST_PACKET
            connection_request_packet = try_read(data, ConnectionRequestPacket)

            if !isnothing(connection_request_packet)
                @info "Received PACKET_TYPE_CONNECTION_REQUEST_PACKET"
                pprint(connection_request_packet)

                for i in 1:room_size
                    if !room[i].is_used
                        client_slot = ClientSlot(true, NetcodeAddress(client_address))
                        room[i] = client_slot
                        @info "Client accepted" client_address
                        break
                    end
                end

                if all(client_slot -> client_slot.is_used, room)
                    @info "Room full" app_server_address room
                    break
                end
            else
                @info "Received malformed PACKET_TYPE_CONNECTION_REQUEST_PACKET"
            end
        else
            @info "Received unknown packet type"
        end
    end

    return nothing
end

function start_client(auth_server_address, username, password)
    hashed_password = bytes2hex(SHA.sha3_256(password))

    response = HTTP.get("http://" * username * ":" * hashed_password * "@" * string(auth_server_address.host) * ":" * string(auth_server_address.port))

    connect_token_packet = try_read(copy(response.body), ConnectTokenPacket)
    if isnothing(connect_token_packet)
        error("Invalid connect token packet received")
    end

    connection_request_packet = ConnectionRequestPacket(connect_token_packet)
    pprint(connection_request_packet)

    socket = Sockets.UDPSocket()

    connection_request_packet_data = get_serialized_data(connection_request_packet)

    app_server_address = get_inetaddr(first(connect_token_packet.netcode_addresses))
    @info "Client obtained app_server_address" app_server_address

    Sockets.send(socket, app_server_address.host, app_server_address.port, connection_request_packet_data)

    return nothing
end

function auth_handler(request)
    i = findfirst(x -> x.first == "Authorization", request.headers)

    if isnothing(i)
        return HTTP.Response(400, "ERROR: Authorization not found in header")
    else
        if startswith(request.headers[i].second, "Basic ")
            base_64_encoded_credentials = split(request.headers[i].second)[2]
            base_64_decoded_credentials = String(Base64.base64decode(base_64_encoded_credentials))
            username, hashed_password = split(base_64_decoded_credentials, ':')

            i = findfirst(==(username), USER_DATA[!, :username])

            if isnothing(i)
                return HTTP.Response(400, "ERROR: Invalid credentials")
            else
                if bytes2hex(SHA.sha3_256(hashed_password * USER_DATA[i, :salt])) == USER_DATA[i, :hashed_salted_hashed_password]
                    connect_token_info = ConnectTokenInfo(i)

                    pprint(connect_token_info)

                    connect_token_packet = ConnectTokenPacket(connect_token_info)

                    data = get_serialized_data(connect_token_packet)

                    return HTTP.Response(200, data)
                else
                    return HTTP.Response(400, "ERROR: Invalid credentials")
                end
            end
        else
            return HTTP.Response(400, "ERROR: Authorization type must be Basic authorization")
        end
    end
end

start_auth_server(auth_server_address) = HTTP.serve(auth_handler, auth_server_address.host, auth_server_address.port)

function start()
    target_frame_rate = 60
    total_frames = target_frame_rate * 2
    target_ns_per_frame = 1_000_000_000 ÷ target_frame_rate

    debug_info = DebugInfo(Int[], Int[], Int[], Int[], Int[], Int[])
    game_state = GameState(time_ns(), 1, target_frame_rate, target_ns_per_frame)

    while game_state.frame_number <= total_frames
        # GLFW.PollEvents()

        simulate_update!(game_state, debug_info)

        sleep_to_achieve_target_frame_rate!(game_state, debug_info)

        push!(debug_info.frame_end_time_buffer, get_time(game_state.reference_time))
        if game_state.frame_number == 1
            push!(debug_info.frame_time_buffer, first(debug_info.frame_end_time_buffer))
        else
            push!(debug_info.frame_time_buffer, debug_info.frame_end_time_buffer[game_state.frame_number] - debug_info.frame_end_time_buffer[game_state.frame_number - 1])
        end

        game_state.frame_number = game_state.frame_number + 1
    end

    df_debug_info = create_df_debug_info(debug_info)
    display(df_debug_info)
    display(DF.describe(df_debug_info, :min, :max, :mean, :std))

    return nothing
end

if length(ARGS) == 1
    if ARGS[1] == "--app_server"
        @info "Running as app_server" APP_SERVER_ADDRESS AUTH_SERVER_ADDRESS

        start_app_server(APP_SERVER_ADDRESS, ROOM_SIZE)

    elseif ARGS[1] == "--auth_server"
        @info "Running as auth_server" APP_SERVER_ADDRESS AUTH_SERVER_ADDRESS

        start_auth_server(AUTH_SERVER_ADDRESS)

    elseif ARGS[1] == "--client"
        @info "Running as client" APP_SERVER_ADDRESS AUTH_SERVER_ADDRESS

        start_client(AUTH_SERVER_ADDRESS, CLIENT_USERNAME, CLIENT_PASSWORD)

    else
        error("Invalid command line argument $(ARGS[1])")
    end
elseif length(ARGS) > 1
    error("This script accepts at most one command line flag")
end

# start()
