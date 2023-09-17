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
