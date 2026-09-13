pub const ray = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("rlgl.h");
});

pub const stb = @cImport({
    @cInclude("stb_image.h");
    @cInclude("stb_image_write.h");
});

pub const c = @cImport({
    @cInclude("stb_image.h");
    @cInclude("stb_image_write.h");
});
