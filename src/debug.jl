import DataStructures as DS

mutable struct DebugInfo
    show_messages::Bool
    # show_collision_boxes::Bool
    messages::Vector{String}
    frame_start_time_buffer::DS.CircularBuffer{Int}
    event_poll_time_buffer::DS.CircularBuffer{Int}
    # dt_buffer::DS.CircularBuffer{Int}
    # update_time_buffer::DS.CircularBuffer{Int}
    # drawing_system_time_buffer::DS.CircularBuffer{Int}
    draw_time_buffer::DS.CircularBuffer{Int}
    texture_upload_time_buffer::DS.CircularBuffer{Int}
    buffer_swap_time_buffer::DS.CircularBuffer{Int}
    # sleep_time_theoretical_buffer::DS.CircularBuffer{Int}
    # sleep_time_observed_buffer::DS.CircularBuffer{Int}
end

function DebugInfo()
    show_messages = true
    # show_collision_boxes = true
    messages = String[]
    sliding_window_size = 30

    frame_start_time_buffer = DS.CircularBuffer{Int}(sliding_window_size + 1)
    push!(frame_start_time_buffer, 0)

    event_poll_time_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    push!(event_poll_time_buffer, 0)

    # dt_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    # push!(dt_buffer, 0)

    # update_time_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    # push!(update_time_buffer, 0)

    # drawing_system_time_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    # push!(drawing_system_time_buffer, 0)

    draw_time_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    push!(draw_time_buffer, 0)

    texture_upload_time_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    push!(texture_upload_time_buffer, 0)

    # sleep_time_theoretical_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    # push!(sleep_time_theoretical_buffer, 0)

    # sleep_time_observed_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    # push!(sleep_time_observed_buffer, 0)

    buffer_swap_time_buffer = DS.CircularBuffer{Int}(sliding_window_size)
    push!(buffer_swap_time_buffer, 0)

    return DebugInfo(
        show_messages,
        # show_collision_boxes,
        messages,
        frame_start_time_buffer,
        event_poll_time_buffer,
        # dt_buffer,
        # update_time_buffer,
        # drawing_system_time_buffer,
        draw_time_buffer,
        texture_upload_time_buffer,
        buffer_swap_time_buffer,
        # sleep_time_theoretical_buffer,
        # sleep_time_observed_buffer,
    )
end
