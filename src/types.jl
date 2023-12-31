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

struct Bullet
    is_alive::Bool
    position::Vec
    diameter::Int
    velocity_magnitude::Int
    direction::Vec
    time_remaining::Int
end

mutable struct GameState
    frame_number::Int
    player::Player
    bullets::Vector{Bullet}
    camera::SD.Rectangle{Int}
    cursor_position::Vec
    walls::Vector{SD.FilledRectangle{Int}}
    background_color::UInt32
    player_color::UInt32
    player_direction_color::UInt32
    bullet_color::UInt32
    wall_color::UInt32
    window_frame_buffer::Matrix{UInt32}
    render_region::SubArray{UInt32, 2, Matrix{UInt32}, Tuple{UnitRange{Int64}, UnitRange{Int64}}, false}
    ui_context::SI.UIContext{SI.WidgetID{String, Int64}, Int64, Int64, UInt32, Any}
end
