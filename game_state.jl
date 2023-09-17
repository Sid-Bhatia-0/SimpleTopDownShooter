import SimpleDraw as SD

struct Player
    drawable::SD.FilledCircle{Int}
end

struct Camera
    rectangle::SD.Rectangle{Int}
end
