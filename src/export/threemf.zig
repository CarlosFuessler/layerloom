const std = @import("std");
const zip_mod = @import("zip.zig");
const ZipWriter = zip_mod.ZipWriter;
const heightfield = @import("../core/heightfield.zig");
const HeightfieldMesh = heightfield.HeightfieldMesh;
const Vec3 = heightfield.Vec3;
const filament_mod = @import("../core/filament.zig");
const FilamentStack = filament_mod.FilamentStack;
const LayerSwapInfo = filament_mod.LayerSwapInfo;

pub const ThreeMFExportOptions = struct {
    title: []const u8 = "2MF Filament Painting",
    designer: []const u8 = "2MF Optical Engine",
    first_layer_height: f32 = 0.16,
    layer_height: f32 = 0.08,
};

pub fn export3MF(
    allocator: std.mem.Allocator,
    mesh: *const HeightfieldMesh,
    stack: *const FilamentStack,
    options: ThreeMFExportOptions,
    file_path: []const u8,
) !void {
    var zip = ZipWriter.init(allocator);
    defer zip.deinit();

    // 1. [Content_Types].xml
    const content_types_xml =
        \\<?xml version="1.0" encoding="UTF-8"?>
        \\<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        \\  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        \\  <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>
        \\</Types>
    ;
    try zip.addFile("[Content_Types].xml", content_types_xml);

    // 2. _rels/.rels
    const rels_xml =
        \\<?xml version="1.0" encoding="UTF-8"?>
        \\<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        \\  <Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>
        \\</Relationships>
    ;
    try zip.addFile("_rels/.rels", rels_xml);

    // 3. Build 3D/3dmodel.model XML in memory
    var model_xml = std.ArrayList(u8){};
    defer model_xml.deinit(allocator);

    var writer = model_xml.writer(allocator);

    try writer.writeAll(
        \\<?xml version="1.0" encoding="UTF-8"?>
        \\<model unit="millimeter" xml:lang="en-US" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02" xmlns:m="http://schemas.microsoft.com/3dmanufacturing/material/2015/02">
        \\  <metadata name="Title">
    );
    try writer.writeAll(options.title);
    try writer.writeAll("</metadata>\n  <metadata name=\"Designer\">");
    try writer.writeAll(options.designer);
    try writer.writeAll("</metadata>\n  <metadata name=\"Application\">2MF Native Desktop</metadata>\n");

    // Resources: Color Group
    try writer.writeAll("  <resources>\n    <m:colorgroup id=\"1\">\n");
    for (0..stack.count) |i| {
        const fil = &stack.items[i];
        const hex = fil.color.toHex();
        try writer.print("      <m:color color=\"#{X:0>6}\" />\n", .{hex});
    }
    try writer.writeAll("    </m:colorgroup>\n");

    // Object mesh
    try writer.writeAll("    <object id=\"2\" type=\"model\">\n      <mesh>\n        <vertices>\n");
    for (mesh.vertices) |v| {
        try writer.print("          <vertex x=\"{d:.3}\" y=\"{d:.3}\" z=\"{d:.3}\" />\n", .{ v.pos.x, v.pos.y, v.pos.z });
    }
    try writer.writeAll("        </vertices>\n        <triangles>\n");

    var i: usize = 0;
    while (i < mesh.indices.len) : (i += 3) {
        const idx0 = mesh.indices[i + 0];
        const idx1 = mesh.indices[i + 1];
        const idx2 = mesh.indices[i + 2];

        // Determine triangle color index from top vertex or face height
        const fil_id = mesh.vertices[idx0].filament_id;
        const color_idx = @min(fil_id, @as(u8, @intCast(if (stack.count > 0) stack.count - 1 else 0)));

        try writer.print("          <triangle v1=\"{d}\" v2=\"{d}\" v3=\"{d}\" pid=\"1\" p1=\"{d}\" />\n", .{
            idx0,
            idx1,
            idx2,
            color_idx,
        });
    }

    try writer.writeAll(
        \\        </triangles>
        \\      </mesh>
        \\    </object>
        \\  </resources>
        \\  <build>
        \\    <item objectid="2" />
        \\  </build>
        \\</model>
        \\
    );

    try zip.addFile("3D/3dmodel.model", model_xml.items);

    // 4. Generate Slicer Filament Swap Schedule (Text + Metadata)
    var swap_text = std.ArrayList(u8){};
    defer swap_text.deinit(allocator);

    var swap_writer = swap_text.writer(allocator);
    try swap_writer.writeAll("=====================================================\n");
    try swap_writer.writeAll("         2MF FILAMENT SWAP PRINT INSTRUCTIONS        \n");
    try swap_writer.writeAll("=====================================================\n\n");
    try swap_writer.print("Base Layer Height : {d:.2} mm\n", .{options.first_layer_height});
    try swap_writer.print("Step Layer Height : {d:.2} mm\n", .{options.layer_height});
    try swap_writer.print("Total Filaments   : {d}\n\n", .{stack.count});

    var swaps_buf: [16]LayerSwapInfo = undefined;
    const swap_count = stack.generateLayerSwaps(options.first_layer_height, options.layer_height, &swaps_buf);

    for (0..swap_count) |s_idx| {
        const s = swaps_buf[s_idx];
        if (s_idx == 0) {
            try swap_writer.print("Start with Spool #{d} ({s}) [#{X:0>6}]\n", .{ s.slicer_slot, s.name, s.color_hex });
            try swap_writer.print("  -> Layers 1 - {d} (0.00 mm - {d:.2} mm)\n\n", .{ s.end_layer, s.end_z });
        } else {
            try swap_writer.print("Swap to Spool #{d} ({s}) [#{X:0>6}]\n", .{ s.slicer_slot, s.name, s.color_hex });
            try swap_writer.print("  -> At Layer {d} ({d:.2} mm) up to Layer {d} ({d:.2} mm)\n\n", .{ s.start_layer, s.start_z, s.end_layer, s.end_z });
        }
    }

    try swap_writer.writeAll("Bambu Studio / OrcaSlicer MMU / AMS Setup:\n");
    try swap_writer.writeAll("1. Import this .3mf file directly into your slicer.\n");
    try swap_writer.writeAll("2. Add color change pause points at the specified layers.\n");
    try swap_writer.writeAll("=====================================================\n");

    try zip.addFile("Metadata/filament_swap_guide.txt", swap_text.items);

    // Write complete ZIP container to target path
    try zip.writeToFile(file_path);
}

test "3mf export creation" {
    const allocator = std.testing.allocator;
    var mesh = HeightfieldMesh.initEmpty(allocator);
    defer mesh.deinit();

    const lum = [_]f32{ 0.1, 0.5, 0.3, 0.8 };
    const stack = FilamentStack.initDefault();
    try mesh.generate(&lum, 2, 2, 2, 2, 50, 50, &stack, .{});

    const tmp_path = "/tmp/test_2mf_model.3mf";
    try export3MF(allocator, &mesh, &stack, .{}, tmp_path);
    defer std.fs.cwd().deleteFile(tmp_path) catch {};

    const stat = try std.fs.cwd().statFile(tmp_path);
    try std.testing.expect(stat.size > 0);
}
