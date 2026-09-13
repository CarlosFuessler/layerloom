const std = @import("std");

pub const ZipEntry = struct {
    path: []const u8,
    data: []const u8,
    crc32: u32,
    offset: u32,
};

fn writeU16(file: std.fs.File, val: u16) !void {
    const bytes = std.mem.toBytes(std.mem.nativeToLittle(u16, val));
    try file.writeAll(&bytes);
}

fn writeU32(file: std.fs.File, val: u32) !void {
    const bytes = std.mem.toBytes(std.mem.nativeToLittle(u32, val));
    try file.writeAll(&bytes);
}

pub const ZipWriter = struct {
    entries: std.ArrayList(ZipEntry),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ZipWriter {
        return .{
            .entries = std.ArrayList(ZipEntry){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ZipWriter) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry.path);
            self.allocator.free(entry.data);
        }
        self.entries.deinit(self.allocator);
    }

    pub fn addFile(self: *ZipWriter, path: []const u8, data: []const u8) !void {
        const owned_path = try self.allocator.dupe(u8, path);
        const owned_data = try self.allocator.dupe(u8, data);
        const crc = std.hash.Crc32.hash(data);

        try self.entries.append(self.allocator, .{
            .path = owned_path,
            .data = owned_data,
            .crc32 = crc,
            .offset = 0,
        });
    }

    pub fn writeToFile(self: *ZipWriter, file_path: []const u8) !void {
        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();

        var current_offset: u32 = 0;

        // 1. Write Local File Headers + Data
        for (self.entries.items) |*entry| {
            entry.offset = current_offset;

            // Local File Header Signature 0x04034b50
            try writeU32(file, 0x04034b50);
            try writeU16(file, 20); // Version needed (2.0)
            try writeU16(file, 0);  // Flags
            try writeU16(file, 0);  // Compression (Store)
            try writeU16(file, 0);  // Mod time
            try writeU16(file, 0);  // Mod date
            try writeU32(file, entry.crc32);
            try writeU32(file, @as(u32, @intCast(entry.data.len)));
            try writeU32(file, @as(u32, @intCast(entry.data.len)));
            try writeU16(file, @as(u16, @intCast(entry.path.len)));
            try writeU16(file, 0); // Extra field len

            try file.writeAll(entry.path);
            try file.writeAll(entry.data);

            current_offset += 30 + @as(u32, @intCast(entry.path.len)) + @as(u32, @intCast(entry.data.len));
        }

        const cd_start_offset = current_offset;

        // 2. Write Central Directory File Headers
        for (self.entries.items) |entry| {
            // Central Directory Header Signature 0x02014b50
            try writeU32(file, 0x02014b50);
            try writeU16(file, 20); // Version made by
            try writeU16(file, 20); // Version needed
            try writeU16(file, 0);  // Flags
            try writeU16(file, 0);  // Method (Store)
            try writeU16(file, 0);  // Mod time
            try writeU16(file, 0);  // Mod date
            try writeU32(file, entry.crc32);
            try writeU32(file, @as(u32, @intCast(entry.data.len)));
            try writeU32(file, @as(u32, @intCast(entry.data.len)));
            try writeU16(file, @as(u16, @intCast(entry.path.len)));
            try writeU16(file, 0); // Extra len
            try writeU16(file, 0); // Comment len
            try writeU16(file, 0); // Disk start
            try writeU16(file, 0); // Internal attrs
            try writeU32(file, 0); // External attrs
            try writeU32(file, entry.offset); // Local header offset

            try file.writeAll(entry.path);

            current_offset += 46 + @as(u32, @intCast(entry.path.len));
        }

        const cd_size = current_offset - cd_start_offset;

        // 3. Write End of Central Directory (EOCD) Record 0x06054b50
        try writeU32(file, 0x06054b50);
        try writeU16(file, 0); // Disk num
        try writeU16(file, 0); // CD disk
        try writeU16(file, @as(u16, @intCast(self.entries.items.len))); // Entries this disk
        try writeU16(file, @as(u16, @intCast(self.entries.items.len))); // Total entries
        try writeU32(file, cd_size);
        try writeU32(file, cd_start_offset);
        try writeU16(file, 0); // Comment len
    }
};

test "zip writer archive creation" {
    const allocator = std.testing.allocator;
    var zip = ZipWriter.init(allocator);
    defer zip.deinit();

    try zip.addFile("test.txt", "Hello 3MF!");
    try zip.addFile("sub/data.xml", "<root>ok</root>");

    const tmp_path = "/tmp/test_2mf_archive.zip";
    try zip.writeToFile(tmp_path);
    defer std.fs.cwd().deleteFile(tmp_path) catch {};

    const stat = try std.fs.cwd().statFile(tmp_path);
    try std.testing.expect(stat.size > 0);
}
