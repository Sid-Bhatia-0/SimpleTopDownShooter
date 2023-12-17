import StaticArrays as SA
import SimpleDraw as SD

const Vec = SA.SVector{2, Int}

Vec(point::SD.Point) = Vec(point.i, point.j)
SD.Point(vector::Vec) = SD.Point(vector[1], vector[2])

get_projection(rectangle, vector) = Vec(clamp(vector[1], SD.get_i_extrema(rectangle)...), clamp(vector[2], SD.get_j_extrema(rectangle)...))

function is_colliding(rectangle, circle)
    center = Vec(SD.get_center(circle))
    projection = get_projection(rectangle, center)
    vector = center - projection
    radius = SD.get_radius(circle)
    return sum(vector .* vector) < radius * radius
end
