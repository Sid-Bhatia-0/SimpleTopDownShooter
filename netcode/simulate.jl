import Base64
import DataFrames as DF
import HTTP
import Sockets
import Statistics

const ROOM_SIZE = 3

const GAME_SERVER_ADDR = Sockets.InetAddr(Sockets.localhost, 10000)

const AUTH_SERVER_ADDR = Sockets.InetAddr(Sockets.localhost, 10001)

const NULL_TCP_SOCKET = Sockets.TCPSocket()

const VALID_CREDENTIALS = Set(Base64.base64encode("user$(i):password$(i)") for i in 1:3)

const CLIENT_USERNAME = "user1"

const CLIENT_PASSWORD = "password1"

struct ClientSlot
    is_used::Bool
    socket::Sockets.TCPSocket
end

const NULL_CLIENT_SLOT = ClientSlot(false, NULL_TCP_SOCKET)

struct DebugInfo
    frame_end_time_buffer::Vector{Int}
    frame_time_buffer::Vector{Int}
    update_time_theoretical_buffer::Vector{Int}
    update_time_observed_buffer::Vector{Int}
    sleep_time_theoretical_buffer::Vector{Int}
    sleep_time_observed_buffer::Vector{Int}
end

mutable struct GameState
    reference_time::Int
    frame_number::Int
    target_frame_rate::Int
    target_ns_per_frame::Int
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

function start_game_server(game_server_addr, room_size)
    room = fill(NULL_CLIENT_SLOT, 3)

    game_server = Sockets.listen(game_server_addr)
    @info "Server started listening"

    for i in 1:ROOM_SIZE
        client_slot = ClientSlot(true, Sockets.accept(game_server))
        room[i] = client_slot

        client_addr = Sockets.InetAddr(Sockets.getpeername(client_slot.socket)...)

        @info "Socket accepted" client_addr
    end

    @info "Room full" game_server room

    return nothing
end

function start_client(auth_server_addr, username, password)
    response = HTTP.get("http://" * username * ":" * password * "@" * string(auth_server_addr.host) * ":" * string(auth_server_addr.port))

    game_server_host_string, game_server_port_string = split(String(response.body), ":")

    game_server_addr = Sockets.InetAddr(game_server_host_string, parse(Int, game_server_port_string))

    @info "Client obtained game_server_addr" game_server_addr

    socket = Sockets.connect(game_server_addr)

    client_addr = Sockets.InetAddr(Sockets.getsockname(socket)...)

    @info "Client connected to game_server" client_addr

    return nothing
end

function auth_handler(request)
    try
        i = findfirst(x -> x.first == "Authorization", request.headers)

        if isnothing(i)
            return HTTP.Response(400, "ERROR: Authorization not found in header")
        else
            if startswith(request.headers[i].second, "Basic ")
                if split(request.headers[i].second)[2] in VALID_CREDENTIALS
                    return HTTP.Response(200, string(GAME_SERVER_ADDR.host) * ":" * string(GAME_SERVER_ADDR.port))
                else
                    return HTTP.Response(400, "ERROR: Invalid credentials")
                end
            else
                return HTTP.Response(400, "ERROR: Authorization type must be Basic authorization")
            end
        end
    catch e
        return HTTP.Response(400, "ERROR: $e")
    end
end

start_auth_server(auth_server_addr) = HTTP.serve(auth_handler, auth_server_addr.host, auth_server_addr.port)

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

@assert length(ARGS) == 1

if ARGS[1] == "--game_server"
    @info "Running as game_server" GAME_SERVER_ADDR AUTH_SERVER_ADDR

    start_game_server(GAME_SERVER_ADDR, ROOM_SIZE)

elseif ARGS[1] == "--auth_server"
    @info "Running as auth_server" GAME_SERVER_ADDR AUTH_SERVER_ADDR

    start_auth_server(AUTH_SERVER_ADDR)

elseif ARGS[1] == "--client"
    @info "Running as client" GAME_SERVER_ADDR AUTH_SERVER_ADDR

    start_client(AUTH_SERVER_ADDR, CLIENT_USERNAME, CLIENT_PASSWORD)

else
    error("Invalid command line argument $(ARGS[1])")
end

# start()
