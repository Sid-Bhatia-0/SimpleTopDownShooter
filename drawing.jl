import SimpleDraw as SD

function draw_game!(render_region, game_state)
    render_region_height, render_region_width = size(render_region)

    SD.draw!(render_region, SD.Background(), 0x00cccccc)

    player = game_state.player
    player_shape = get_player_shape(player)

    player_shape_wrt_render_region = get_shape_wrt_render_region(game_state.camera, render_region_height, render_region_width, player_shape)

    player_direction_shape_wrt_render_region = get_player_direction_shape_wrt_render_region(game_state, player_shape_wrt_render_region)

    SD.draw!(render_region, player_shape_wrt_render_region, 0x000000ff)

    SD.draw!(render_region, player_direction_shape_wrt_render_region, 0x00000000)

    reference_circle_wrt_render_region = get_shape_wrt_render_region(game_state.camera, render_region_height, render_region_width, game_state.reference_circle)

    SD.draw!(render_region, reference_circle_wrt_render_region, 0x00ff0000)

    for wall in game_state.walls
        wall_wrt_render_region = get_shape_wrt_render_region(game_state.camera, render_region_height, render_region_width, wall)

        SD.draw!(render_region, wall_wrt_render_region, 0x00000000)
    end

    return nothing
end
