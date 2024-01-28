const std = @import("std");
const io = std.io;

pub fn main() !void {
    const stdin = io.getStdIn().reader();
    const stdout = io.getStdOut().writer();
    try xorot(stdin, stdout);
}

fn xorot(in: std.fs.File.Reader, out: std.fs.File.Writer) !void {
    var idx: u8 = 0b10101010;
    var buffer: [8192]u8 = undefined;

    while (true) {
        const cnt = try in.read(&buffer);
        if (cnt == 0) break;

        for (0..cnt) |i| {
            buffer[i] = rot(rot(buffer[i]) ^ idx);
            idx = if (idx == 0xFF) 0 else idx + 1;
        }

        try out.writeAll(buffer[0..cnt]);
    }
}

inline fn rot(ch: u8) u8 {
    return switch (ch) {
        'A'...'M', 'a'...'m' => ch + 13,
        'N'...'Z', 'n'...'z' => ch - 13,
        '0'...'4' => ch + 5,
        '5'...'9' => ch - 5,
        else => ch,
    };
}
