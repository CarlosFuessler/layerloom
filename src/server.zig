const std = @import("std");

fn getMimeType(path: []const u8) []const u8 {
    if (std.mem.endsWith(u8, path, ".html")) return "text/html; charset=utf-8";
    if (std.mem.endsWith(u8, path, ".css")) return "text/css; charset=utf-8";
    if (std.mem.endsWith(u8, path, ".js") or std.mem.endsWith(u8, path, ".mjs")) return "text/javascript; charset=utf-8";
    if (std.mem.endsWith(u8, path, ".json")) return "application/json";
    if (std.mem.endsWith(u8, path, ".png")) return "image/png";
    if (std.mem.endsWith(u8, path, ".jpg") or std.mem.endsWith(u8, path, ".jpeg")) return "image/jpeg";
    if (std.mem.endsWith(u8, path, ".svg")) return "image/svg+xml";
    if (std.mem.endsWith(u8, path, ".ico")) return "image/x-icon";
    if (std.mem.endsWith(u8, path, ".wasm")) return "application/wasm";
    if (std.mem.endsWith(u8, path, ".3mf")) return "model/3mf";
    if (std.mem.endsWith(u8, path, ".stl")) return "model/stl";
    return "application/octet-stream";
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const address = try std.net.Address.parseIp4("127.0.0.1", 8080);
    var listener = try address.listen(.{ .reuse_address = true });
    defer listener.deinit();

    std.debug.print("\n======================================================\n", .{});
    std.debug.print("  2MF STUDIO - Modular Web & Native Studio Server\n", .{});
    std.debug.print("  Running at: http://127.0.0.1:8080\n", .{});
    std.debug.print("======================================================\n\n", .{});

    // Auto-open browser on macOS
    _ = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "open", "http://127.0.0.1:8080" },
    }) catch {};

    while (true) {
        const conn = listener.accept() catch continue;
        defer conn.stream.close();

        var buf: [4096]u8 = undefined;
        const bytes_read = conn.stream.read(&buf) catch continue;
        if (bytes_read == 0) continue;

        const request = buf[0..bytes_read];
        var lines = std.mem.splitScalar(u8, request, '\n');
        const first_line = lines.next() orelse continue;

        var tokens = std.mem.tokenizeScalar(u8, first_line, ' ');
        const method = tokens.next() orelse continue;
        const raw_path = tokens.next() orelse "/";

        const is_get = std.mem.eql(u8, method, "GET");
        const is_head = std.mem.eql(u8, method, "HEAD");

        if (!is_get and !is_head) {
            const not_allowed = "HTTP/1.1 405 Method Not Allowed\r\nConnection: close\r\n\r\n";
            _ = conn.stream.write(not_allowed) catch {};
            continue;
        }

        // Clean path and reject directory traversal
        var path = raw_path;
        if (std.mem.indexOf(u8, path, "?")) |query_idx| {
            path = path[0..query_idx];
        }

        if (std.mem.indexOf(u8, path, "..") != null) {
            const forbidden = "HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n";
            _ = conn.stream.write(forbidden) catch {};
            continue;
        }

        var file_path_buf: [512]u8 = undefined;
        const rel_path = if (std.mem.eql(u8, path, "/") or path.len == 0) "index.html" else if (path[0] == '/') path[1..] else path;
        const file_path = std.fmt.bufPrint(&file_path_buf, "web/{s}", .{rel_path}) catch continue;

        const file_content = std.fs.cwd().readFileAlloc(allocator, file_path, 20 * 1024 * 1024) catch {
            const not_found = "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n404 Not Found";
            _ = conn.stream.write(not_found) catch {};
            continue;
        };
        defer allocator.free(file_content);

        const mime_type = getMimeType(file_path);

        var header_buf: [512]u8 = undefined;
        const headers = std.fmt.bufPrint(&header_buf,
            "HTTP/1.1 200 OK\r\n" ++
            "Content-Type: {s}\r\n" ++
            "Content-Length: {d}\r\n" ++
            "Access-Control-Allow-Origin: *\r\n" ++
            "Connection: close\r\n" ++
            "\r\n",
            .{ mime_type, file_content.len },
        ) catch continue;

        _ = conn.stream.write(headers) catch continue;
        if (is_get) {
            _ = conn.stream.write(file_content) catch continue;
        }
    }
}
