import DataStructures as DS
import SimpleDraw as SD
import StaticArrays as SA

const Vec = SA.SVector{2, Int}

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

struct Player
    position::Vec
    diameter::Int
    direction::Vec
end

mutable struct GameState
    frame_number::Int
    player::Player
    camera::SD.Rectangle{Int}
    cursor_position::Vec
    walls::Vector{SD.FilledRectangle{Int}}
    background_color::UInt32
    player_color::UInt32
end
