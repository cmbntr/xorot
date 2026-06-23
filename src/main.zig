const std = @import("std");
const build_options = @import("build_options");

const buffer_size = 64 * 1024;
const suffix = ".xorot";

const ExitCode = enum(u8) {
    source = 1,
    destination_exists = 2,
    allocation = 3,
    other = 9,
};

const Mode = enum { output, in_place };

const Cli = struct {
    mode: Mode = .output,
    force: bool = false,
    silent: bool = false,
    paths: []const []const u8 = &.{},
};

const ProcessResult = struct {
    cnt: usize,
    code: ?ExitCode = null,
};

pub fn main(init: std.process.Init) !void {
    const args = try collectArgs(init.gpa, init.minimal.args);
    defer freeArgs(init.gpa, args);

    const cli = parseArgs(args[1..]) catch |err| switch (err) {
        error.UnknownFlag => exitWithFailureReason(init.io, .other),
    };

    if (cli.paths.len == 0) {
        var stdin_reader = std.Io.File.stdin().reader(init.io, &.{});
        var stdout_writer = std.Io.File.stdout().writer(init.io, &.{});
        _ = try processCore(&stdin_reader.interface, &stdout_writer.interface);
        try stdout_writer.flush();
        return;
    }

    for (cli.paths) |path| {
        switch (cli.mode) {
            .output => {
                const dst_path = try destinationName(init.gpa, path);
                defer init.gpa.free(dst_path);

                const result = processOutputNoReport(init.io, path, dst_path, cli.force);
                try reportProcessResult(init.io, shouldReportProgress(true, cli.silent), path, dst_path, result);
            },
            .in_place => {
                const result = processInPlaceNoReport(init.io, path);
                try reportProcessResult(init.io, shouldReportProgress(true, cli.silent), path, path, result);
            },
        }
    }
}

fn shouldReportProgress(is_file_mode: bool, silent: bool) bool {
    return is_file_mode and !silent;
}

fn parseArgs(args: []const []const u8) !Cli {
    var cli: Cli = .{};
    var filenames_start: ?usize = null;

    for (args, 0..) |arg, i| {
        if (filenames_start != null) continue;
        if (std.mem.eql(u8, arg, "--")) {
            filenames_start = i + 1;
        } else if (std.mem.eql(u8, arg, "-i")) {
            cli.mode = .in_place;
        } else if (std.mem.eql(u8, arg, "-f") or std.mem.eql(u8, arg, "---force")) {
            cli.force = true;
        } else if (std.mem.eql(u8, arg, "-s")) {
            cli.silent = true;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            return error.UnknownFlag;
        } else {
            filenames_start = i;
        }
    }

    cli.paths = if (filenames_start) |start| args[start..] else &.{};
    return cli;
}

fn collectArgs(allocator: std.mem.Allocator, args: std.process.Args) ![]const []const u8 {
    var it = try std.process.Args.Iterator.initAllocator(args, allocator);
    defer it.deinit();

    var list: std.ArrayListUnmanaged([]const u8) = .empty;
    errdefer list.deinit(allocator);
    while (it.next()) |arg| {
        const owned = try allocator.dupe(u8, arg);
        errdefer allocator.free(owned);
        try list.append(allocator, owned);
    }
    return list.toOwnedSlice(allocator);
}

fn freeArgs(allocator: std.mem.Allocator, args: []const []const u8) void {
    for (args) |arg| allocator.free(arg);
    allocator.free(args);
}

fn processOutputNoReport(io: std.Io, src_path: []const u8, dst_path: []const u8, force: bool) ProcessResult {
    var src = std.Io.Dir.cwd().openFile(io, src_path, .{ .mode = .read_only, .allow_directory = false }) catch return .{ .cnt = 0, .code = .source };
    defer src.close(io);
    const stat = src.stat(io) catch return .{ .cnt = 0, .code = .source };

    var dst = if (force)
        std.Io.Dir.cwd().createFile(io, dst_path, .{ .truncate = true }) catch return .{ .cnt = 0, .code = .other }
    else
        std.Io.Dir.cwd().createFile(io, dst_path, .{ .exclusive = true }) catch |err| switch (err) {
            error.PathAlreadyExists => return .{ .cnt = 0, .code = .destination_exists },
            else => return .{ .cnt = 0, .code = .other },
        };
    defer dst.close(io);

    dst.setLength(io, stat.size) catch return .{ .cnt = 0, .code = .allocation };

    var read_buffer: [buffer_size]u8 = undefined;
    var write_buffer: [buffer_size]u8 = undefined;
    var src_reader = src.reader(io, &read_buffer);
    var dst_writer = dst.writer(io, &write_buffer);
    const cnt = processCore(&src_reader.interface, &dst_writer.interface) catch |err| switch (err) {
        error.ReadFailed => return .{ .cnt = 0, .code = .source },
        else => return .{ .cnt = 0, .code = .other },
    };
    dst_writer.flush() catch return .{ .cnt = cnt, .code = .other };
    return .{ .cnt = cnt };
}

fn processInPlaceNoReport(io: std.Io, path: []const u8) ProcessResult {
    var read_file = std.Io.Dir.cwd().openFile(io, path, .{ .mode = .read_only, .allow_directory = false }) catch return .{ .cnt = 0, .code = .source };
    defer read_file.close(io);
    var write_file = std.Io.Dir.cwd().openFile(io, path, .{ .mode = .write_only, .allow_directory = false }) catch return .{ .cnt = 0, .code = .source };
    defer write_file.close(io);

    var idx: u8 = 0b10101010;
    var cnt: usize = 0;
    var buffer: [buffer_size]u8 = undefined;

    while (true) {
        const read_cnt = read_file.readPositionalAll(io, &buffer, cnt) catch return .{ .cnt = cnt, .code = .source };
        if (read_cnt == 0) break;
        transformSlice(buffer[0..read_cnt], &idx);
        write_file.writePositionalAll(io, buffer[0..read_cnt], cnt) catch return .{ .cnt = cnt, .code = .other };
        cnt += read_cnt;
    }

    return .{ .cnt = cnt };
}

fn destinationName(allocator: std.mem.Allocator, src_path: []const u8) ![]u8 {
    if (std.mem.endsWith(u8, src_path, suffix)) {
        return allocator.dupe(u8, src_path[0 .. src_path.len - suffix.len]);
    }
    return std.mem.concat(allocator, u8, &.{ src_path, suffix });
}

fn report(out: *std.Io.Writer, src: []const u8, dst: []const u8, cnt: usize) !void {
    try out.print("src={s},dst={s},cnt={}\n", .{ src, dst, cnt });
}

fn failureReason(code: ExitCode) []const u8 {
    return switch (code) {
        .source => "source-read-failure",
        .destination_exists => "destination-exists",
        .allocation => "destination-allocation-failure",
        .other => "other-io-or-usage-failure",
    };
}

fn reportFailure(out: *std.Io.Writer, code: ExitCode) !void {
    try out.print("code={},reason={s}\n", .{ @intFromEnum(code), failureReason(code) });
}

fn writeProcessResult(out: *std.Io.Writer, emit_progress: bool, src: []const u8, dst: []const u8, result: ProcessResult) !void {
    if (emit_progress) try report(out, src, dst, result.cnt);
    if (result.code) |code| try reportFailure(out, code);
}

fn reportProcessResult(io: std.Io, emit_progress: bool, src: []const u8, dst: []const u8, result: ProcessResult) !void {
    var stderr_writer = std.Io.File.stderr().writer(io, &.{});
    try writeProcessResult(&stderr_writer.interface, emit_progress, src, dst, result);
    try stderr_writer.flush();

    if (result.code) |code| std.process.exit(@intFromEnum(code));
}

fn exitWithFailureReason(io: std.Io, code: ExitCode) noreturn {
    var stderr_writer = std.Io.File.stderr().writer(io, &.{});
    reportFailure(&stderr_writer.interface, code) catch {};
    stderr_writer.flush() catch {};
    std.process.exit(@intFromEnum(code));
}

fn processCore(in: *std.Io.Reader, out: *std.Io.Writer) !usize {
    var idx: u8 = 0b10101010;
    var buffer: [buffer_size]u8 = undefined;
    var cnt: usize = 0;

    while (true) {
        const read_cnt = in.readSliceShort(&buffer) catch return error.ReadFailed;
        if (read_cnt == 0) break;
        transformSlice(buffer[0..read_cnt], &idx);
        try out.writeAll(buffer[0..read_cnt]);
        cnt += read_cnt;
    }

    return cnt;
}

fn xorot(in: *std.Io.Reader, out: *std.Io.Writer) !void {
    _ = try processCore(in, out);
}

fn transformSlice(bytes: []u8, idx: *u8) void {
    for (bytes) |*byte| {
        byte.* = rot(rot(byte.*) ^ idx.*);
        idx.* = if (idx.* == 0xFF) 0 else idx.* + 1;
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

fn expectParse(args: []const []const u8, mode: Mode, force: bool, silent: bool, paths: []const []const u8) !void {
    const cli = try parseArgs(args);
    try std.testing.expectEqual(mode, cli.mode);
    try std.testing.expectEqual(force, cli.force);
    try std.testing.expectEqual(silent, cli.silent);
    try std.testing.expectEqual(paths.len, cli.paths.len);
    for (paths, cli.paths) |expected, actual| try std.testing.expectEqualStrings(expected, actual);
}

fn testPath(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    return std.fs.path.join(allocator, &.{ "zig-cache", "tmp", name });
}

fn writeTestFile(path: []const u8, bytes: []const u8) !void {
    try std.Io.Dir.cwd().createDirPath(std.testing.io, std.fs.path.dirname(path) orelse ".");
    var file = try std.Io.Dir.cwd().createFile(std.testing.io, path, .{ .truncate = true });
    defer file.close(std.testing.io);
    try file.writeStreamingAll(std.testing.io, bytes);
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
    var boundary_input: [buffer_size + 37]u8 = undefined;
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

test "file modes fuzz-style generated input stress" {
    var prng = std.Random.DefaultPrng.init(0x66696c655f786f72);
    const random = prng.random();

    var input: [1024]u8 = undefined;
    for (0..build_options.xorot_fuzz_iterations) |i| {
        const len = random.uintLessThan(usize, input.len + 1);
        random.bytes(input[0..len]);
        const expected = try referenceXorot(std.testing.allocator, input[0..len]);
        defer std.testing.allocator.free(expected);

        const src = try std.fmt.allocPrint(std.testing.allocator, "zig-cache/tmp/xorot-fuzz-{}", .{i});
        defer std.testing.allocator.free(src);
        const dst = try destinationName(std.testing.allocator, src);
        defer std.testing.allocator.free(dst);
        std.Io.Dir.cwd().deleteFile(std.testing.io, src) catch {};
        std.Io.Dir.cwd().deleteFile(std.testing.io, dst) catch {};

        try writeTestFile(src, input[0..len]);
        const output_result = processOutputNoReport(std.testing.io, src, dst, false);
        try std.testing.expectEqual(@as(?ExitCode, null), output_result.code);
        try std.testing.expectEqual(len, output_result.cnt);
        const output_actual = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, dst, std.testing.allocator, .limited(len + 1));
        defer std.testing.allocator.free(output_actual);
        try std.testing.expectEqualSlices(u8, expected, output_actual);

        try writeTestFile(src, input[0..len]);
        const in_place_result = processInPlaceNoReport(std.testing.io, src);
        try std.testing.expectEqual(@as(?ExitCode, null), in_place_result.code);
        try std.testing.expectEqual(len, in_place_result.cnt);
        const in_place_actual = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, src, std.testing.allocator, .limited(len + 1));
        defer std.testing.allocator.free(in_place_actual);
        try std.testing.expectEqualSlices(u8, expected, in_place_actual);
    }
}

test "parse cli modes flags marker silent and unknown flags" {
    try expectParse(&.{}, .output, false, false, &.{});
    try expectParse(&.{"input"}, .output, false, false, &.{"input"});
    try expectParse(&.{ "-i", "-f", "-s", "a", "b" }, .in_place, true, true, &.{ "a", "b" });
    try expectParse(&.{ "---force", "--", "-named" }, .output, true, false, &.{"-named"});
    try std.testing.expectError(error.UnknownFlag, parseArgs(&.{ "--bad", "file" }));
}

test "progress reporting defaults by mode" {
    try std.testing.expect(!shouldReportProgress(false, false));
    try std.testing.expect(!shouldReportProgress(false, true));
    try std.testing.expect(shouldReportProgress(true, false));
    try std.testing.expect(!shouldReportProgress(true, true));
}

test "destination naming appends and strips suffix" {
    const a = try destinationName(std.testing.allocator, "plain");
    defer std.testing.allocator.free(a);
    try std.testing.expectEqualStrings("plain.xorot", a);

    const b = try destinationName(std.testing.allocator, "plain.xorot");
    defer std.testing.allocator.free(b);
    try std.testing.expectEqualStrings("plain", b);
}

test "output file mode creates strips refuses and forces" {
    const src = try testPath(std.testing.allocator, "xorot-output-src");
    defer std.testing.allocator.free(src);
    const dst = try destinationName(std.testing.allocator, src);
    defer std.testing.allocator.free(dst);
    std.Io.Dir.cwd().deleteFile(std.testing.io, src) catch {};
    std.Io.Dir.cwd().deleteFile(std.testing.io, dst) catch {};

    const input = "file-output-data";
    try writeTestFile(src, input);
    const first = processOutputNoReport(std.testing.io, src, dst, false);
    try std.testing.expectEqual(@as(?ExitCode, null), first.code);
    try std.testing.expectEqual(input.len, first.cnt);
    const actual = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, dst, std.testing.allocator, .limited(1024));
    defer std.testing.allocator.free(actual);
    const expected = try referenceXorot(std.testing.allocator, input);
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqualSlices(u8, expected, actual);

    const exists = processOutputNoReport(std.testing.io, src, dst, false);
    try std.testing.expectEqual(@as(?ExitCode, .destination_exists), exists.code);

    try writeTestFile(dst, "old");
    const forced = processOutputNoReport(std.testing.io, src, dst, true);
    try std.testing.expectEqual(@as(?ExitCode, null), forced.code);
}

test "output file mode strips xorot suffix" {
    const src = try testPath(std.testing.allocator, "xorot-strip-src.xorot");
    defer std.testing.allocator.free(src);
    const dst = try destinationName(std.testing.allocator, src);
    defer std.testing.allocator.free(dst);
    std.Io.Dir.cwd().deleteFile(std.testing.io, src) catch {};
    std.Io.Dir.cwd().deleteFile(std.testing.io, dst) catch {};
    try writeTestFile(src, "abc");
    const result = processOutputNoReport(std.testing.io, src, dst, false);
    try std.testing.expectEqual(@as(?ExitCode, null), result.code);
    try std.testing.expectEqual(@as(usize, 3), result.cnt);
}

test "output file mode maps missing source and bounded large input" {
    const missing = processOutputNoReport(std.testing.io, "zig-cache/tmp/does-not-exist", "zig-cache/tmp/nope.xorot", false);
    try std.testing.expectEqual(@as(?ExitCode, .source), missing.code);

    const src = try testPath(std.testing.allocator, "xorot-large-src");
    defer std.testing.allocator.free(src);
    const dst = try destinationName(std.testing.allocator, src);
    defer std.testing.allocator.free(dst);
    std.Io.Dir.cwd().deleteFile(std.testing.io, src) catch {};
    std.Io.Dir.cwd().deleteFile(std.testing.io, dst) catch {};
    const input = try std.testing.allocator.alloc(u8, buffer_size * 2 + 17);
    defer std.testing.allocator.free(input);
    for (input, 0..) |*byte, i| byte.* = @truncate(i);
    try writeTestFile(src, input);
    const result = processOutputNoReport(std.testing.io, src, dst, false);
    try std.testing.expectEqual(@as(?ExitCode, null), result.code);
    try std.testing.expectEqual(input.len, result.cnt);
}

test "file modes reject directory paths as source inputs" {
    const dir_path = try testPath(std.testing.allocator, "xorot-dir-source");
    defer std.testing.allocator.free(dir_path);
    std.Io.Dir.cwd().deleteTree(std.testing.io, dir_path) catch {};
    try std.Io.Dir.cwd().createDirPath(std.testing.io, dir_path);

    const dst_path = try destinationName(std.testing.allocator, dir_path);
    defer std.testing.allocator.free(dst_path);
    std.Io.Dir.cwd().deleteFile(std.testing.io, dst_path) catch {};

    const output_result = processOutputNoReport(std.testing.io, dir_path, dst_path, false);
    try std.testing.expectEqual(@as(?ExitCode, .source), output_result.code);
    try std.testing.expectEqual(@as(usize, 0), output_result.cnt);

    const in_place_result = processInPlaceNoReport(std.testing.io, dir_path);
    try std.testing.expectEqual(@as(?ExitCode, .source), in_place_result.code);
    try std.testing.expectEqual(@as(usize, 0), in_place_result.cnt);
}

test "in-place mode succeeds for empty and multi-chunk files" {
    const empty = try testPath(std.testing.allocator, "xorot-inplace-empty");
    defer std.testing.allocator.free(empty);
    try writeTestFile(empty, "");
    const empty_result = processInPlaceNoReport(std.testing.io, empty);
    try std.testing.expectEqual(@as(?ExitCode, null), empty_result.code);
    try std.testing.expectEqual(@as(usize, 0), empty_result.cnt);

    const path = try testPath(std.testing.allocator, "xorot-inplace-large");
    defer std.testing.allocator.free(path);
    const input = try std.testing.allocator.alloc(u8, buffer_size + 19);
    defer std.testing.allocator.free(input);
    for (input, 0..) |*byte, i| byte.* = @truncate(i * 7);
    try writeTestFile(path, input);
    const result = processInPlaceNoReport(std.testing.io, path);
    try std.testing.expectEqual(@as(?ExitCode, null), result.code);
    try std.testing.expectEqual(input.len, result.cnt);
    const actual = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, std.testing.allocator, .limited(input.len + 1));
    defer std.testing.allocator.free(actual);
    const expected = try referenceXorot(std.testing.allocator, input);
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqualSlices(u8, expected, actual);
}

test "in-place missing source maps source error" {
    const result = processInPlaceNoReport(std.testing.io, "zig-cache/tmp/xorot-missing-inplace");
    try std.testing.expectEqual(@as(?ExitCode, .source), result.code);
    try std.testing.expectEqual(@as(usize, 0), result.cnt);
}

test "process core returns count and report format" {
    var reader: std.Io.Reader = .fixed("abc");
    var output: [3]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&output);
    const cnt = try processCore(&reader, &writer);
    try std.testing.expectEqual(@as(usize, 3), cnt);

    var report_buf: [64]u8 = undefined;
    var report_writer: std.Io.Writer = .fixed(&report_buf);
    try report(&report_writer, "-", "-", cnt);
    try std.testing.expectEqualStrings("src=-,dst=-,cnt=3\n", report_writer.buffered());
}

test "failure reasons and report ordering are stable" {
    try std.testing.expectEqualStrings("source-read-failure", failureReason(.source));
    try std.testing.expectEqualStrings("destination-exists", failureReason(.destination_exists));
    try std.testing.expectEqualStrings("destination-allocation-failure", failureReason(.allocation));
    try std.testing.expectEqualStrings("other-io-or-usage-failure", failureReason(.other));

    var failure_buf: [160]u8 = undefined;
    var failure_writer: std.Io.Writer = .fixed(&failure_buf);
    try writeProcessResult(&failure_writer, true, "src", "dst", .{ .cnt = 7, .code = .other });
    try std.testing.expectEqualStrings(
        "src=src,dst=dst,cnt=7\ncode=9,reason=other-io-or-usage-failure\n",
        failure_writer.buffered(),
    );

    var silent_failure_buf: [96]u8 = undefined;
    var silent_failure_writer: std.Io.Writer = .fixed(&silent_failure_buf);
    try writeProcessResult(&silent_failure_writer, false, "src", "dst", .{ .cnt = 0, .code = .source });
    try std.testing.expectEqualStrings(
        "code=1,reason=source-read-failure\n",
        silent_failure_writer.buffered(),
    );

    var success_buf: [64]u8 = undefined;
    var success_writer: std.Io.Writer = .fixed(&success_buf);
    try writeProcessResult(&success_writer, true, "src", "dst", .{ .cnt = 5 });
    try std.testing.expectEqualStrings("src=src,dst=dst,cnt=5\n", success_writer.buffered());
}
