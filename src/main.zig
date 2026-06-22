const std = @import("std");

pub fn main(init: std.process.Init) !void {
    var stdin_reader = std.Io.File.stdin().reader(init.io, &.{});
    var stdout_writer = std.Io.File.stdout().writer(init.io, &.{});

    try xorot(&stdin_reader.interface, &stdout_writer.interface);
    try stdout_writer.flush();
}

fn xorot(in: *std.Io.Reader, out: *std.Io.Writer) !void {
    var idx: u8 = 0b10101010;
    var buffer: [8192]u8 = undefined;

    while (true) {
        const cnt = try in.readSliceShort(&buffer);
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
