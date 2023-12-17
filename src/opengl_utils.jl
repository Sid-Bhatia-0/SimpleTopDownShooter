import ModernGL as MGL
import GLFW

function setup_window_hints()
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 3)
    GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)

    return nothing
end

function setup_vertex_shader()
    vertex_shader_source =
    "#version 330 core
    layout (location = 0) in vec3 aPos;
    layout (location = 1) in vec2 aTexCoord;

    out vec2 TexCoord;

    void main()
    {
        gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
        TexCoord = vec2(aTexCoord.x, aTexCoord.y);
    }"
    vertex_shader = MGL.glCreateShader(MGL.GL_VERTEX_SHADER)
    MGL.glShaderSource(vertex_shader, 1, Ptr{MGL.GLchar}[pointer(vertex_shader_source)], C_NULL)
    MGL.glCompileShader(vertex_shader)
    vertex_shader_success_ref = Ref{MGL.GLint}(0)
    MGL.glGetShaderiv(vertex_shader, MGL.GL_COMPILE_STATUS, vertex_shader_success_ref)
    @assert vertex_shader_success_ref[] == 1 "Vertex shader setup failed"

    return vertex_shader
end

function setup_fragment_shader()
    fragment_shader_source =
    "#version 330 core
    out vec4 FragColor;

    in vec2 TexCoord;

    uniform sampler2D texture1;

    void main()
    {
        FragColor = texture(texture1, TexCoord);
    }"
    fragment_shader = MGL.glCreateShader(MGL.GL_FRAGMENT_SHADER)
    MGL.glShaderSource(fragment_shader, 1, Ptr{MGL.GLchar}[pointer(fragment_shader_source)], C_NULL)
    MGL.glCompileShader(fragment_shader)
    fragment_shader_success_ref = Ref{MGL.GLint}(0)
    MGL.glGetShaderiv(fragment_shader, MGL.GL_COMPILE_STATUS, fragment_shader_success_ref)
    @assert fragment_shader_success_ref[] == 1 "Fragment shader setup failed"

    return fragment_shader
end

function setup_shader_program(vertex_shader, fragment_shader)
    shader_program = MGL.glCreateProgram()
    MGL.glAttachShader(shader_program, vertex_shader)
    MGL.glAttachShader(shader_program, fragment_shader)
    MGL.glLinkProgram(shader_program)
    shader_program_success_ref = Ref{MGL.GLint}(0)
    MGL.glGetProgramiv(shader_program, MGL.GL_LINK_STATUS, shader_program_success_ref)
    MGL.glDeleteShader(vertex_shader)
    MGL.glDeleteShader(fragment_shader)
    @assert shader_program_success_ref[] == 1 "Shader program setup failed"

    return shader_program
end

function setup_vao_vbo_ebo()
    vertices = MGL.GLfloat[
     1.0f0,  1.0f0, 0.0f0, 0.0f0, 1.0f0,  # top right
     1.0f0, -1.0f0, 0.0f0, 1.0f0, 1.0f0,  # bottom right
    -1.0f0, -1.0f0, 0.0f0, 1.0f0, 0.0f0,  # bottom left
    -1.0f0,  1.0f0, 0.0f0, 0.0f0, 0.0f0,  # top left
    ]
    indices = MGL.GLuint[
    0, 1, 3,  # first Triangle
    1, 2, 3   # second Triangle
    ]

    VAO_ref = Ref{MGL.GLuint}(0)
    MGL.glGenVertexArrays(1, VAO_ref)

    VBO_ref = Ref{MGL.GLuint}(0)
    MGL.glGenBuffers(1, VBO_ref)

    EBO_ref = Ref{MGL.GLuint}(0)
    MGL.glGenBuffers(1, EBO_ref)

    MGL.glBindVertexArray(VAO_ref[])

    MGL.glBindBuffer(MGL.GL_ARRAY_BUFFER, VBO_ref[])
    MGL.glBufferData(MGL.GL_ARRAY_BUFFER, sizeof(vertices), vertices, MGL.GL_STATIC_DRAW)

    MGL.glBindBuffer(MGL.GL_ELEMENT_ARRAY_BUFFER, EBO_ref[])
    MGL.glBufferData(MGL.GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, MGL.GL_STATIC_DRAW)

    MGL.glVertexAttribPointer(0, 3, MGL.GL_FLOAT, MGL.GL_FALSE, 5 * sizeof(MGL.GLfloat), Ptr{Cvoid}(0))
    MGL.glEnableVertexAttribArray(0)

    MGL.glVertexAttribPointer(1, 2, MGL.GL_FLOAT, MGL.GL_FALSE, 5 * sizeof(MGL.GLfloat), Ptr{Cvoid}(3 * sizeof(MGL.GLfloat)))
    MGL.glEnableVertexAttribArray(1)

    MGL.glBindBuffer(MGL.GL_ARRAY_BUFFER, 0)

    MGL.glBindVertexArray(0)

    return VAO_ref, VBO_ref, EBO_ref
end

function setup_texture(image)
    height_image, width_image = size(image)

    texture_ref = Ref{MGL.GLuint}(0)
    MGL.glGenTextures(1, texture_ref)
    MGL.glActiveTexture(MGL.GL_TEXTURE0)
    MGL.glBindTexture(MGL.GL_TEXTURE_2D, texture_ref[])

    MGL.glTexParameteri(MGL.GL_TEXTURE_2D, MGL.GL_TEXTURE_WRAP_S, MGL.GL_REPEAT)
    MGL.glTexParameteri(MGL.GL_TEXTURE_2D, MGL.GL_TEXTURE_WRAP_T, MGL.GL_REPEAT)

    MGL.glTexParameteri(MGL.GL_TEXTURE_2D, MGL.GL_TEXTURE_MIN_FILTER, MGL.GL_NEAREST)
    MGL.glTexParameteri(MGL.GL_TEXTURE_2D, MGL.GL_TEXTURE_MAG_FILTER, MGL.GL_NEAREST)

    MGL.glTexImage2D(MGL.GL_TEXTURE_2D, 0, MGL.GL_RGBA, height_image, width_image, 0, MGL.GL_RGBA, MGL.GL_UNSIGNED_BYTE, image)

    return texture_ref
end

function clear_display()
    MGL.glClearColor(0.0f0, 0.0f0, 0.0f0, 1.0f0)
    MGL.glClear(MGL.GL_COLOR_BUFFER_BIT)

    return nothing
end

function update_back_buffer(image)
    height_image, width_image = size(image)

    MGL.glTexSubImage2D(MGL.GL_TEXTURE_2D, 0, MGL.GLint(0), MGL.GLint(0), MGL.GLsizei(height_image), MGL.GLsizei(width_image), MGL.GL_RGBA, MGL.GL_UNSIGNED_BYTE, image)
    MGL.glDrawElements(MGL.GL_TRIANGLES, 6, MGL.GL_UNSIGNED_INT, Ptr{Cvoid}(0))

    return nothing
end
