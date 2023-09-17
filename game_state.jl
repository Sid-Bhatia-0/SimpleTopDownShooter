import SimpleDraw as SD

struct Player
    drawable::SD.FilledCircle{Int}
end

struct Camera
    rectangle::SD.Rectangle{Int}
end

function get_camera_view(camera, shape)
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
    shape_wrt_camera = get_camera_view(camera, shape)
    i_shape_wrt_render_region = map_segment(camera.rectangle.height, render_region_height, shape_wrt_camera.position.i)
    j_shape_wrt_render_region = map_segment(camera.rectangle.width, render_region_width, shape_wrt_camera.position.j)
    f = render_region_height // camera.rectangle.height
    shape_wrt_render_region = SD.move(scale(shape_wrt_camera, f), i_shape_wrt_render_region - shape_wrt_camera.position.i, j_shape_wrt_render_region - shape_wrt_camera.position.j)
    return shape_wrt_render_region
end
