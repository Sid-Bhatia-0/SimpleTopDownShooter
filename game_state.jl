import SimpleDraw as SD

struct Player
    position::Vec
    diameter::Int
    direction::Vec
end

get_player_shape(player) = SD.FilledCircle(SD.Point(player.position...), player.diameter)

struct Camera
    rectangle::SD.Rectangle{Int}
end

mutable struct GameState
    frame_number::Int
    player::Player
    camera::Camera
    cursor_position::SD.Point{Int}
    reference_circle::SD.FilledCircle{Int}
end

function get_shape_wrt_camera(camera, shape)
    I = typeof(camera.rectangle.position.i)
    return SD.move(shape, -camera.rectangle.position.i + one(I), -camera.rectangle.position.j + one(I))
end

function map_segment(a, b, x)
    if isone(a)
        return one(x)
    else
        ((b - one(b)) * (x - one(x))) ÷ (a - one(a)) + one(x) # linearly map Base.OneTo(a) to Base.OneTo(b), such that when x = 1, y == 1, and when x = a, y == b
    end
end

scale(shape::SD.FilledCircle, f::Rational) = typeof(shape)(shape.position, (shape.diameter * f.num) ÷ f.den)

function get_shape_wrt_render_region(camera, render_region_height, render_region_width, shape)
    shape_wrt_camera = get_shape_wrt_camera(camera, shape)
    i_shape_wrt_render_region = map_segment(camera.rectangle.height, render_region_height, shape_wrt_camera.position.i)
    j_shape_wrt_render_region = map_segment(camera.rectangle.width, render_region_width, shape_wrt_camera.position.j)
    f = render_region_height // camera.rectangle.height
    shape_wrt_render_region = SD.move(scale(shape_wrt_camera, f), i_shape_wrt_render_region - shape_wrt_camera.position.i, j_shape_wrt_render_region - shape_wrt_camera.position.j)
    return shape_wrt_render_region
end

update_camera(camera, player) = Camera(SD.Rectangle(SD.move(SD.get_center(get_player_shape(player)), -camera.rectangle.height ÷ 2, -camera.rectangle.width ÷ 2), camera.rectangle.height, camera.rectangle.width))

function update_camera!(game_state)
    game_state.camera = update_camera(game_state.camera, game_state.player)
    return nothing
end

function get_render_region(window_frame_buffer, camera_height_over_camera_width)
    window_height, window_width = size(window_frame_buffer)

    f = min(window_height ÷ camera_height_over_camera_width.den, window_width ÷ camera_height_over_camera_width.num)
    render_region_height = f * camera_height_over_camera_width.den
    render_region_width = f * camera_height_over_camera_width.num

    top_padding = (window_height - render_region_height) ÷ 2
    left_padding = (window_width - render_region_width) ÷ 2

    render_region = @view window_frame_buffer[top_padding + 1 : top_padding + render_region_height, left_padding + 1 : left_padding + render_region_width]

    return render_region
end

move(player, displacement) = Player(player.position + displacement, player.diameter, player.direction)

function get_cursor_position_wrt_render_region(render_region, cursor_position)
    i_window = cursor_position.i
    j_window = cursor_position.j
    render_region_height, render_region_width = size(render_region)
    top_padding, left_padding = render_region.indices[1].start - 1, render_region.indices[2].start - 1

    I = typeof(top_padding)

    i_render_region = clamp(i_window - top_padding + one(I), one(I), render_region_height)
    j_render_region = clamp(j_window - left_padding + one(I), one(I), render_region_width)

    return SD.Point(i_render_region, j_render_region)
end

function update_cursor_position!(game_state, render_region, cursor_position_wrt_window)
    game_state.cursor_position = get_cursor_position_wrt_render_region(render_region, cursor_position_wrt_window)

    return nothing
end

function update_player_direction!(game_state, render_region_height, render_region_width)
    player_drawable_wrt_render_region = get_shape_wrt_render_region(game_state.camera, render_region_height, render_region_width, get_player_shape(game_state.player))

    player_center_wrt_render_region = SD.get_center(player_drawable_wrt_render_region)

    i_player_center_wrt_render_region = player_center_wrt_render_region.i
    j_player_center_wrt_render_region = player_center_wrt_render_region.j

    i_cursor_position = game_state.cursor_position.i
    j_cursor_position = game_state.cursor_position.j

    i_player_direction = i_cursor_position - i_player_center_wrt_render_region
    j_player_direction = j_cursor_position - j_player_center_wrt_render_region

    if iszero(i_player_direction) && iszero(j_player_direction)
        j_player_direction = one(j_player_direction)
    end

    game_state.player = Player(game_state.player.position, game_state.player.diameter, Vec(i_player_direction, j_player_direction))

    return nothing
end

function get_player_direction_shape_wrt_render_region(game_state, player_drawable_wrt_render_region)
    player_radius_wrt_render_region = SD.get_radius(player_drawable_wrt_render_region)

    player_center_wrt_render_region = SD.get_center(player_drawable_wrt_render_region)
    delta_i = player_center_wrt_render_region.i
    delta_j = player_center_wrt_render_region.j

    i_player_direction = game_state.player.direction[1]
    j_player_direction = game_state.player.direction[2]

    player_direction_magnitude_squared = i_player_direction ^ 2 + j_player_direction ^ 2
    i_circumference = sign(i_player_direction) * isqrt(((player_radius_wrt_render_region * i_player_direction) ^ 2) ÷ player_direction_magnitude_squared)
    j_circumference = sign(j_player_direction) * isqrt(((player_radius_wrt_render_region * j_player_direction) ^ 2) ÷ player_direction_magnitude_squared)

    return SD.Line(player_center_wrt_render_region, SD.move(SD.Point(i_circumference, j_circumference), player_center_wrt_render_region.i, player_center_wrt_render_region.j))
end
