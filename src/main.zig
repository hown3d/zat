const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const io = std.io;

const ZatError = error{
    InvalidArgument,
    FileNotFound,
};

const BufSize = 512;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const file_path = try processArgs();
    const file = openFile(allocator, file_path) catch |err| switch (err) {
        ZatError.FileNotFound => {
            std.debug.print("file at {s} does not exist", .{file_path});
            std.process.exit(1);
        },
        else => |leftover_err| return leftover_err,
    };
    defer file.close();

    try readFileToStdout(allocator, file);
}

fn processArgs() ZatError![]const u8 {
    var args = std.process.args();
    // skip programm name
    _ = args.skip();
    return args.next() orelse {
        return ZatError.InvalidArgument;
    };
}

fn openFile(allocator: mem.Allocator, file_path: []const u8) !fs.File {
    const path = try fs.cwd().realpathAlloc(allocator, file_path);
    return fs.openFileAbsolute(path, fs.File.OpenFlags{}) catch |err| {
        return switch (err) {
            fs.File.OpenError.FileNotFound => ZatError.FileNotFound,
            else => |leftover_err| return leftover_err,
        };
    };
}

fn readFileToStdout(allocator: mem.Allocator, file: fs.File) !void {
    const buf = try allocator.alloc(u8, BufSize);
    var bytes_read: usize = buf.len;

    while (bytes_read >= buf.len) {
        bytes_read = try file.readAll(buf);
        _ = try io.getStdOut().write(buf[0..bytes_read]);
    }
}
