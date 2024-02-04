import DataFrames as DF
import Sockets
import Statistics

const ROOM_SIZE = 3

const SERVER_HOST = Sockets.localhost
const SERVER_PORT = 10000

const NULL_TCP_SOCKET = Sockets.TCPSocket()

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

function start_server_and_fill_room(server_host, server_port, room_size)
    room = fill(NULL_CLIENT_SLOT, 3)

    server = Sockets.listen(server_host, server_port)
    @info "Server started listening"

    for i in 1:ROOM_SIZE
        client_slot = ClientSlot(true, Sockets.accept(server))
        room[i] = client_slot

        peername = Sockets.getpeername(client_slot.socket)
        client_host = peername[1]
        client_port = Int(peername[2])

        @info "Socket accepted" client_host client_port
    end

    @info "Room full" server room

    return server, room
end

function start_client(server_host, server_port)
    socket = Sockets.connect(server_host, server_port)

    sockname = Sockets.getsockname(socket)
    client_host = sockname[1]
    client_port = Int(sockname[2])

    @info "Client connected to server" client_host client_port

    return socket
end

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

if ARGS[1] == "--server"
    IS_SERVER = true

    @info "Running as server" SERVER_HOST SERVER_PORT
elseif ARGS[1] == "--client"
    IS_SERVER = false

    @info "Running as client" SERVER_HOST SERVER_PORT
else
    error("Invalid command line argument $(ARGS[1])")
end

if IS_SERVER
    server, room = start_server_and_fill_room(SERVER_HOST, SERVER_PORT, ROOM_SIZE)
else
    socket = start_client(SERVER_HOST, SERVER_PORT)
end

# start()
