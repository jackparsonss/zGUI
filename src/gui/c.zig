pub const glfw = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub const glad = @cImport({
    @cInclude("glad/glad.h");
});

pub const trueType = @cImport({
    @cInclude("stb_truetype.h");
});

pub const image = @cImport({
    @cInclude("stb_image.h");
});

pub const Window = ?*glfw.GLFWwindow;
