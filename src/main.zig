const std = @import("std");
const build_options = @import("build_options");

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

fn referenceXorot(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const output = try allocator.alloc(u8, input.len);
    var idx: u8 = 0b10101010;

    for (input, 0..) |ch, i| {
        output[i] = rot(rot(ch) ^ idx);
        idx = if (idx == 0xFF) 0 else idx + 1;
    }

    return output;
}

fn runXorot(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var reader: std.Io.Reader = .fixed(input);
    const output = try allocator.alloc(u8, input.len);
    errdefer allocator.free(output);
    var writer: std.Io.Writer = .fixed(output);

    try xorot(&reader, &writer);
    try std.testing.expectEqual(input.len, writer.buffered().len);
    return output;
}

fn expectXorotMatchesReference(allocator: std.mem.Allocator, input: []const u8) !void {
    const expected = try referenceXorot(allocator, input);
    defer allocator.free(expected);

    const actual = try runXorot(allocator, input);
    defer allocator.free(actual);

    try std.testing.expectEqual(input.len, actual.len);
    try std.testing.expectEqualSlices(u8, expected, actual);
}

test "rot maps alphabetic and numeric boundaries and preserves passthrough bytes" {
    try std.testing.expectEqual('N', rot('A'));
    try std.testing.expectEqual('Z', rot('M'));
    try std.testing.expectEqual('A', rot('N'));
    try std.testing.expectEqual('M', rot('Z'));
    try std.testing.expectEqual('n', rot('a'));
    try std.testing.expectEqual('z', rot('m'));
    try std.testing.expectEqual('a', rot('n'));
    try std.testing.expectEqual('m', rot('z'));

    try std.testing.expectEqual('5', rot('0'));
    try std.testing.expectEqual('9', rot('4'));
    try std.testing.expectEqual('0', rot('5'));
    try std.testing.expectEqual('4', rot('9'));

    try std.testing.expectEqual('/', rot('/'));
    try std.testing.expectEqual(':', rot(':'));
    try std.testing.expectEqual('@', rot('@'));
    try std.testing.expectEqual('[', rot('['));
    try std.testing.expectEqual('`', rot('`'));
    try std.testing.expectEqual('{', rot('{'));
}

test "xorot handles empty input and stable known vector" {
    try expectXorotMatchesReference(std.testing.allocator, "");

    const input = "xorot-123-ABC-xyz";
    const expected = &[_]u8{ 0xc1, 0xc9, 0xc9, 0xcf, 0xc9, 0x82, 0x86, 0x86, 0x8a, 0x9e, 0xfa, 0xfa, 0xe6, 0x9a, 0xd3, 0xd5, 0xd7 };
    const actual = try runXorot(std.testing.allocator, input);
    defer std.testing.allocator.free(actual);

    try std.testing.expectEqualSlices(u8, expected, actual);
}

test "xorot matches reference across read buffer boundary and xor index wraparound" {
    var boundary_input: [8192 + 37]u8 = undefined;
    for (&boundary_input, 0..) |*ch, i| ch.* = @truncate(i * 31 + 7);
    try expectXorotMatchesReference(std.testing.allocator, &boundary_input);

    var wrap_input: [300]u8 = undefined;
    for (&wrap_input, 0..) |*ch, i| ch.* = @truncate(i);
    try expectXorotMatchesReference(std.testing.allocator, &wrap_input);
}

test "xorot randomized inputs preserve length and match reference" {
    var prng = std.Random.DefaultPrng.init(0x786f726f745f7465);
    const random = prng.random();

    var input: [1024]u8 = undefined;
    for (0..128) |_| {
        const len = random.uintLessThan(usize, input.len + 1);
        random.bytes(input[0..len]);
        try expectXorotMatchesReference(std.testing.allocator, input[0..len]);
    }
}

test "xorot fuzz-style generated input stress" {
    var prng = std.Random.DefaultPrng.init(0x66757a7a5f786f72);
    const random = prng.random();

    var input: [4096]u8 = undefined;
    for (0..build_options.xorot_fuzz_iterations) |_| {
        const len = random.uintLessThan(usize, input.len + 1);
        random.bytes(input[0..len]);
        try expectXorotMatchesReference(std.testing.allocator, input[0..len]);
    }
}

test "xorot fuzz-style generated high-range input stress" {
    var prng = std.Random.DefaultPrng.init(0x37306b69625f786f);
    const random = prng.random();

    for (0..build_options.xorot_fuzz_iterations) |_| {
        const len = random.uintLessThan(usize, 70 * 1024);
        const input = try std.testing.allocator.alloc(u8, len);
        defer std.testing.allocator.free(input);

        random.bytes(input);
        try expectXorotMatchesReference(std.testing.allocator, input);
    }
}
