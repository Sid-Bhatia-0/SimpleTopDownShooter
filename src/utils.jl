import GLFW
import SimpleIMGUI as SI

function get_time(reference_time)
    # get time (in units of nanoseconds) since reference_time
    # places an upper bound on how much time can the program be running until time wraps around giving meaningless values
    # the conversion to Int will actually throw an error when that happens

    t = time_ns()

    if t >= reference_time
        return Int(t - reference_time)
    else
        return Int(t + (typemax(t) - reference_time))
    end
end

function update_button(button, action)
    if action == GLFW.PRESS
        return SI.press(button)
    elseif action == GLFW.RELEASE
        return SI.release(button)
    else
        return button
    end
end

function integer_sqrt(i::Integer)
    @assert i >= 0

    if i <= 1
        return i
    end

    # maybe something smarter like i ÷ 3 or even adaptive i/(i>>(i>>2))?
    left = 0
    right = i ÷ 2

    while true
        if left ^ 2 <= i && (left + 1) ^ 2 > i
            return left
        end

        if right ^ 2 <= i && (right + 1) ^ 2 > i
            return right
        end

        j = (left + right) ÷ 2

        if j ^ 2 <= i && (j + 1) ^ 2 > i
            return j
        end

        if j ^ 2 > i
            right = j
        elseif (j + 1) ^ 2 <= i
            left = j
        end
    end
end
