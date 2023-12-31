import SimpleDraw as SD

function draw_game!(game_state)
    render_region = game_state.render_region
    render_region_height, render_region_width = size(render_region)

    SD.draw!(render_region, SD.Background(), game_state.background_color)

    player = game_state.player
    player_shape = get_player_shape(player)

    player_shape_wrt_render_region = get_shape_wrt_render_region(game_state.camera, render_region_height, render_region_width, player_shape)

    player_direction_shape_wrt_render_region = get_player_direction_shape_wrt_render_region(game_state, player_shape_wrt_render_region)

    SD.draw!(render_region, player_shape_wrt_render_region, game_state.player_color)

    SD.draw!(render_region, player_direction_shape_wrt_render_region, game_state.player_direction_color)

    for bullet in game_state.bullets
        bullet_shape = get_player_shape(bullet)
        bullet_shape_wrt_render_region = get_shape_wrt_render_region(game_state.camera, render_region_height, render_region_width, bullet_shape)

        SD.draw!(render_region, bullet_shape_wrt_render_region, game_state.bullet_color)
    end

    for wall in game_state.walls
        wall_wrt_render_region = get_shape_wrt_render_region(game_state.camera, render_region_height, render_region_width, wall)

        SD.draw!(render_region, wall_wrt_render_region, game_state.wall_color)
    end

    for drawable in game_state.ui_context.draw_list
        # if isa(drawable, ShapeDrawable)
            # SD.draw!(render_region, drawable.shape, drawable.color)
        # else
            SD.draw!(game_state.render_region, drawable)
        # end
    end

    return nothing
end
