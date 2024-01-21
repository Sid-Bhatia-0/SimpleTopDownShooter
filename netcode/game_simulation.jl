import Statistics

struct DebugInfo
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

function start()
    target_frame_rate = 60
    total_frames = target_frame_rate * 2
    target_ns_per_frame = 1_000_000_000 ÷ target_frame_rate

    debug_info = DebugInfo(Int[], Int[], Int[], Int[])
    game_state = GameState(time_ns(), 1, target_frame_rate, target_ns_per_frame)

    while game_state.frame_number <= total_frames
        # GLFW.PollEvents()

        simulate_update!(game_state, debug_info)

        sleep_to_achieve_target_frame_rate!(game_state, debug_info)

        game_state.frame_number = game_state.frame_number + 1
    end

    println("total time: $(round(get_time(game_state.reference_time) / 1e6, digits = 2)) ms")
    println("avg. total time per frame: $(round((get_time(game_state.reference_time) / total_frames) / 1e6, digits = 2)) ms")
    println("avg. update time theoretical: $(round(Statistics.mean(debug_info.update_time_theoretical_buffer) / 1e6, digits = 2)) ms")
    println("avg. update time observed: $(round(Statistics.mean(debug_info.update_time_observed_buffer) / 1e6, digits = 2)) ms")
    println("avg. sleep time theoretical: $(round(Statistics.mean(debug_info.sleep_time_theoretical_buffer) / 1e6, digits = 2)) ms")
    println("avg. sleep time observed: $(round(Statistics.mean(debug_info.sleep_time_observed_buffer) / 1e6, digits = 2)) ms")

    return nothing
end

start()
