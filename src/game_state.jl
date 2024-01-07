import Accessors
import SimpleDraw as SD

get_player_shape(player) = SD.FilledCircle(SD.Point(player.position...), player.diameter)
get_bullet_shape(bullet) = SD.FilledCircle(SD.Point(bullet.position...), bullet.diameter)

function get_shape_wrt_camera(camera, shape)
    I = typeof(camera.position.i)
    return SD.move(shape, -camera.position.i + one(I), -camera.position.j + one(I))
end

function map_segment(a, b, x)
    if isone(a)
        return one(x)
    else
        ((b - one(b)) * (x - one(x))) ÷ (a - one(a)) + one(x)
        # linearly map Base.OneTo(a) to Base.OneTo(b), such that when x = 1, y == 1, and when x = a, y == b
        # There is some kind of rounding down that happens. For example:
        # julia> map_segment(20, 5, 16)
        # 4

        # julia> map_segment(20, 5, 15)
        # 3

        # julia> map_segment(20, 5, 17)
        # 4

        # julia> map_segment(20, 5, 18)
        # 4

        # julia> map_segment(20, 5, 19)
        # 4

        # julia> map_segment(20, 5, 20)
        # 5
    end
end

# world coordinate is world space coordinate, like actual entire game world
# camera is essentially a rectangle somewhere in the world. camera coordinate is simply the position of something in the world with respect to the camera (just translated such that top left cell of the camera is (1, 1))
world_coordinate_to_camera_coordinate(i_shape_wrt_world, i_camera_wrt_world) = i_shape_wrt_world - i_camera_wrt_world + one(i_shape_wrt_world)

world_coordinate_to_camera_coordinate(position_shape_wrt_world::Vec, position_camera_wrt_world::Vec) = world_coordinate_to_camera_coordinate.(position_shape_wrt_world, position_camera_wrt_world)

camera_coordinate_to_render_region_coordinate(camera_height, render_region_height, i_shape_wrt_camera) = map_segment(camera_height, render_region_height, i_shape_wrt_camera)

camera_coordinate_to_render_region_coordinate(camera_size::Vec, render_region_size::Vec, position_shape_wrt_camera::Vec) = camera_coordinate_to_render_region_coordinate.(camera_size, render_region_size, position_shape_wrt_camera)

function world_coordinate_to_render_region_coordinate(camera_height, render_region_height, i_shape_wrt_world, i_camera_wrt_world)
    i_shape_wrt_camera = world_coordinate_to_camera_coordinate(i_shape_wrt_world, i_camera_wrt_world)
    i_shape_wrt_render_region = camera_coordinate_to_render_region_coordinate(camera_height, render_region_height, i_shape_wrt_camera)
    return i_shape_wrt_render_region
end

function world_coordinate_to_render_region_coordinate(camera_size::Vec, render_region_size::Vec, position_shape_wrt_world::Vec, position_camera_wrt_world::Vec)
    position_shape_wrt_camera = world_coordinate_to_camera_coordinate(position_shape_wrt_world, position_camera_wrt_world)
    position_shape_wrt_render_region = camera_coordinate_to_render_region_coordinate(camera_size, render_region_size, position_shape_wrt_camera)
    return position_shape_wrt_render_region
end

function get_shape_from_extrema(shape::SD.AbstractCircle, i_min, j_min, i_max, j_max)
    @assert i_max - i_min >= zero(i_max)
    @assert j_max - j_min >= zero(j_max)
    diameter = max(i_max - i_min + one(i_max), j_max - j_min + one(j_max))
    return typeof(shape)(SD.Point(i_min, j_min), diameter)
end

function get_shape_from_extrema(shape::SD.AbstractRectangle, i_min, j_min, i_max, j_max)
    @assert i_max - i_min >= zero(i_max)
    @assert j_max - j_min >= zero(j_max)
    height = i_max - i_min + one(i_max)
    width = j_max - j_min + one(j_max)
    return typeof(shape)(SD.Point(i_min, j_min), height, width)
end

function get_shape_wrt_render_region(camera, render_region_height, render_region_width, shape)
    camera_size = Vec(camera.height, camera.width)
    render_region_size = Vec(render_region_height, render_region_width)
    top_left_shape_wrt_world = Vec(SD.get_position(shape))
    bottom_right_shape_wrt_world = Vec(SD.get_i_max(shape), SD.get_j_max(shape))
    position_camera_wrt_world = Vec(camera.position)

    top_left_shape_wrt_render_region = world_coordinate_to_render_region_coordinate(camera_size, render_region_size, top_left_shape_wrt_world, position_camera_wrt_world)
    bottom_right_shape_wrt_render_region = world_coordinate_to_render_region_coordinate(camera_size, render_region_size, bottom_right_shape_wrt_world, position_camera_wrt_world)

    shape_wrt_render_region = get_shape_from_extrema(shape, top_left_shape_wrt_render_region..., bottom_right_shape_wrt_render_region...)

    return shape_wrt_render_region
end

update_camera(camera, player) = SD.Rectangle(SD.move(SD.get_center(get_player_shape(player)), -camera.height ÷ 2, -camera.width ÷ 2), camera.height, camera.width)

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

move(player, displacement) = Accessors.@set player.position = player.position + displacement

function try_move_player!(game_state, displacement)
    player = game_state.player

    new_player = move(player, displacement)

    new_player_shape = get_player_shape(new_player)

    for wall in game_state.walls
        if is_colliding(wall, new_player_shape)
            return nothing
        end
    end

    game_state.player = new_player

    return nothing
end

function get_cursor_position_wrt_render_region(render_region_position, render_region_height, render_region_width, cursor_position)
    i_window = cursor_position[1]
    j_window = cursor_position[2]
    top_padding, left_padding = render_region_position[1] - 1, render_region_position[2] - 1

    I = typeof(top_padding)

    i_render_region = clamp(i_window - top_padding + one(I), one(I), render_region_height)
    j_render_region = clamp(j_window - left_padding + one(I), one(I), render_region_width)

    return Vec(i_render_region, j_render_region)
end

function update_cursor_position!(game_state)
    cursor_position_wrt_window = Vec(game_state.ui_context.user_input_state.cursor.position.i, game_state.ui_context.user_input_state.cursor.position.j)
    render_region = game_state.render_region
    render_region_position = Vec(render_region.indices[1].start, render_region.indices[2].start)
    game_state.cursor_position = get_cursor_position_wrt_render_region(render_region_position, size(render_region)..., cursor_position_wrt_window)

    return nothing
end

function update_player_direction!(game_state)
    render_region_height, render_region_width = size(game_state.render_region)
    player_drawable_wrt_render_region = get_shape_wrt_render_region(game_state.camera, render_region_height, render_region_width, get_player_shape(game_state.player))

    player_center_wrt_render_region = SD.get_center(player_drawable_wrt_render_region)

    i_player_center_wrt_render_region = player_center_wrt_render_region.i
    j_player_center_wrt_render_region = player_center_wrt_render_region.j

    i_cursor_position = game_state.cursor_position[1]
    j_cursor_position = game_state.cursor_position[2]

    i_player_direction = i_cursor_position - i_player_center_wrt_render_region
    j_player_direction = j_cursor_position - j_player_center_wrt_render_region

    if iszero(i_player_direction) && iszero(j_player_direction)
        j_player_direction = one(j_player_direction)
    end

    player = game_state.player
    game_state.player = Accessors.@set player.direction = Vec(i_player_direction, j_player_direction)

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

function reset_ui_layout!(game_state)
    game_state.ui_context.layout.reference_bounding_box = SD.Rectangle(SD.Point(1, 1), size(game_state.render_region)...)
    return nothing
end

function try_shoot!(game_state)
    for (i, bullet) in enumerate(game_state.bullets)
        if !bullet.is_alive
            bullet_radius = bullet.diameter ÷ 2
            new_bullet_position = Vec(SD.get_center(get_bullet_shape(game_state.player))) .- bullet_radius
            new_bullet = Bullet(
                true,
                new_bullet_position,
                bullet.diameter,
                bullet.velocity_magnitude,
                game_state.player.direction,
                get_time(game_state.reference_time),
                bullet.lifetime,
            )

            game_state.bullets[i] = new_bullet
            break
        end
    end

    return nothing
end

function get_velocity(velocity_magnitude, direction)
    direction_magnitude_squared = direction[1] ^ 2 + direction[2] ^ 2
    return Vec(
        sign(direction[1]) * isqrt((velocity_magnitude * direction[1]) ^ 2 ÷ direction_magnitude_squared),
        sign(direction[2]) * isqrt((velocity_magnitude * direction[2]) ^ 2 ÷ direction_magnitude_squared),
    )
end

function update_bullets!(game_state)
    t = get_time(game_state.reference_time)
    for (i, bullet) in enumerate(game_state.bullets)
        if bullet.is_alive
            new_bullet = bullet
            if t - bullet.time_created >= bullet.lifetime
                Accessors.@reset new_bullet.is_alive = false
            else
                Accessors.@reset new_bullet.position = new_bullet.position + get_velocity(new_bullet.velocity_magnitude, new_bullet.direction)

                new_bullet_shape = get_bullet_shape(new_bullet)
                for wall in game_state.walls
                    if is_colliding(wall, new_bullet_shape)
                        Accessors.@reset new_bullet.is_alive = false
                        break
                    end
                end
            end

            game_state.bullets[i] = new_bullet
        end
    end

    return nothing
end
