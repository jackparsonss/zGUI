const std = @import("std");

pub fn id(label: []const u8) u64 {
    const src = @src();
    var hasher = std.hash.XxHash64.init(0);
    hasher.update(label);
    hasher.update(src.file);

    var buffer: [20]u8 = undefined;
    const uint_as_string_slice = std.fmt.bufPrint(&buffer, "{}", .{src.line}) catch unreachable;
    hasher.update(uint_as_string_slice);
    return hasher.final();
}

