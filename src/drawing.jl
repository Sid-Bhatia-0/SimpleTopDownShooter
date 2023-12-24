import SimpleDraw as SD

function draw_game!(render_region, game_state)
    render_region_height, render_region_width = size(render_region)

    SD.draw!(render_region, SD.Background(), game_state.background_color)

    player = game_state.player
    player_shape = get_player_shape(player)

    player_shape_wrt_render_region = get_shape_wrt_render_region(game_state.camera, render_region_height, render_region_width, player_shape)

    player_direction_shape_wrt_render_region = get_player_direction_shape_wrt_render_region(game_state, player_shape_wrt_render_region)

    SD.draw!(render_region, player_shape_wrt_render_region, 0x000000ff)

    SD.draw!(render_region, player_direction_shape_wrt_render_region, 0x00000000)

    for wall in game_state.walls
        wall_wrt_render_region = get_shape_wrt_render_region(game_state.camera, render_region_height, render_region_width, wall)

        SD.draw!(render_region, wall_wrt_render_region, 0x00777777)
    end

    return nothing
end
