const std = @import("std");

const puzzle_input: []const []const u8 = &[_][]const u8{ "826A", "341A", "582A", "983A", "670A" };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const result = solve(gpa.allocator(), puzzle_input, 25);

    std.debug.print("Result: {}\n", .{result});
}

const DirKey = enum { left, right, up, down, A };

const Pos = struct {
    x: u8,
    y: u8,

    fn at(x: u32, y: u32) Pos {
        return Pos{ .x = x, .y = y };
    }
};

const Numpad = struct {
    const Key = enum(u8) { K0 = 0, K1 = 1, K2 = 2, K3 = 3, K4 = 4, K5 = 5, K6 = 6, K7 = 7, K8 = 8, K9 = 9, A = 10 };
    const keys: [11]Pos = keys_init: {
        var ks: [11]Pos = .{Pos.at(0, 0)} ** 11;
        ks[@intFromEnum(Key.K0)] = Pos.at(1, 3);
        ks[@intFromEnum(Key.K1)] = Pos.at(0, 2);
        ks[@intFromEnum(Key.K2)] = Pos.at(1, 2);
        ks[@intFromEnum(Key.K3)] = Pos.at(2, 2);
        ks[@intFromEnum(Key.K4)] = Pos.at(0, 1);
        ks[@intFromEnum(Key.K5)] = Pos.at(1, 1);
        ks[@intFromEnum(Key.K6)] = Pos.at(2, 1);
        ks[@intFromEnum(Key.K7)] = Pos.at(0, 0);
        ks[@intFromEnum(Key.K8)] = Pos.at(1, 0);
        ks[@intFromEnum(Key.K9)] = Pos.at(2, 0);
        ks[@intFromEnum(Key.A)] = Pos.at(2, 3);
        break :keys_init ks;
    };

    fn keyPos(k: Key) Pos {
        return keys[@intFromEnum(k)];
    }

    fn keyFrom(c: u8) Key {
        return switch (c) {
            '0' => .K0,
            '1' => .K1,
            '2' => .K2,
            '3' => .K3,
            '4' => .K4,
            '5' => .K5,
            '6' => .K6,
            '7' => .K7,
            '8' => .K8,
            '9' => .K9,
            'A' => .A,
            else => unreachable,
        };
    }
};

const DirPad = struct {
    const keys: [5]Pos = keys_init: {
        var ks: [5]Pos = .{Pos.at(0, 0)} ** 5;
        ks[@intFromEnum(DirKey.left)] = Pos.at(0, 1);
        ks[@intFromEnum(DirKey.right)] = Pos.at(2, 1);
        ks[@intFromEnum(DirKey.up)] = Pos.at(1, 0);
        ks[@intFromEnum(DirKey.down)] = Pos.at(1, 1);
        ks[@intFromEnum(DirKey.A)] = Pos.at(2, 0);
        break :keys_init ks;
    };

    fn keyPos(k: DirKey) Pos {
        return keys[@intFromEnum(k)];
    }
};

fn printSeq(seq: []const DirKey) void {
    for (seq) |key| {
        const c = switch (key) {
            .left => "<",
            .right => ">",
            .up => "^",
            .down => "v",
            .A => "A",
        };
        std.debug.print("{s}", .{c});
    }
    std.debug.print("\n", .{});
}

const Result = std.ArrayList(DirKey);

const Context = struct {
    dir_pads: u8,
    memo: Memo,
};

inline fn numpadSolveStep(ctx: *Context, pos: Pos, target: Pos, input: []const u8, seq: *Result) usize {
    if (pos.x == target.x) {
        const key, const steps =
            if (pos.y > target.y) .{ DirKey.up, pos.y - target.y } else .{ DirKey.down, target.y - pos.y };
        seq.appendNTimes(key, steps) catch unreachable;
        seq.append(.A) catch unreachable;
        return numpadSolve(ctx, target, input, seq);
    } else if (pos.y == target.y) {
        const key, const steps =
            if (pos.x > target.x) .{ DirKey.left, pos.x - target.x } else .{ DirKey.right, target.x - pos.x };
        seq.appendNTimes(key, steps) catch unreachable;
        seq.append(.A) catch unreachable;
        return numpadSolve(ctx, target, input, seq);
    } else {
        const key_x, const steps_x =
            if (pos.x > target.x) .{ DirKey.left, pos.x - target.x } else .{ DirKey.right, target.x - pos.x };
        const key_y, const steps_y =
            if (pos.y > target.y) .{ DirKey.up, pos.y - target.y } else .{ DirKey.down, target.y - pos.y };

        var seq2 = seq.clone() catch unreachable;
        defer seq2.deinit();

        var len1: ?usize = null;
        var len2: ?usize = null;

        if (!(pos.y == 3 and target.x == 0)) {
            seq.ensureUnusedCapacity(steps_x + steps_y + 1) catch unreachable;
            seq.appendNTimesAssumeCapacity(key_x, steps_x);
            seq.appendNTimesAssumeCapacity(key_y, steps_y);
            seq.appendAssumeCapacity(.A);
            len1 = numpadSolve(ctx, target, input, seq);
        }

        if (!(pos.x == 0 and target.y == 3)) {
            seq2.ensureUnusedCapacity(steps_x + steps_y + 1) catch unreachable;
            seq2.appendNTimesAssumeCapacity(key_y, steps_y);
            seq2.appendNTimesAssumeCapacity(key_x, steps_x);
            seq2.appendAssumeCapacity(.A);
            len2 = numpadSolve(ctx, target, input, &seq2);
        }

        if (len1) |l1| {
            if (len2) |l2| {
                return @min(l1, l2);
            } else {
                return l1;
            }
        }
        return len2.?;
    }
}

fn numpadSolve(ctx: *Context, pos: Pos, input: []const u8, seq: *Result) usize {
    if (input.len == 0) {
        var dir_seq = Result.init(seq.allocator);
        defer dir_seq.deinit();

        //return dirpadSolve(ctx, ctx.dir_pads, DirPad.keyPos(.A), seq.items, seq.items, &dir_seq);
        return dirpadSolve2(ctx, ctx.dir_pads, seq.items);
    }
    const c = input[0];
    const target = Numpad.keyPos(Numpad.keyFrom(c));
    return numpadSolveStep(ctx, pos, target, input[1..], seq);
}

const Memo = struct {
    const Key = struct { u8, []const DirKey };
    const HashContext = struct {
        pub fn hash(self: HashContext, key: Key) u64 {
            _ = self;
            var hasher = std.hash.Wyhash.init(0);
            std.hash.autoHashStrat(&hasher, key, std.hash.Strategy.Deep);
            return hasher.final();
        }
        pub fn eql(self: HashContext, a: Key, b: Key) bool {
            _ = self;
            return a[0] == b[0] and std.mem.eql(DirKey, a[1], b[1]);
        }
    };

    const Internal = std.HashMap(Key, usize, HashContext, 80);

    data: Internal,

    fn init(alloc: std.mem.Allocator) Memo {
        return Memo{ .data = Internal.init(alloc) };
    }

    fn deinit(self: *Memo) void {
        var iter = self.data.keyIterator();
        while (iter.next()) |key| {
            self.data.allocator.free(key[1]);
        }
        self.data.deinit();
    }

    fn add(self: *Memo, d: u8, input: []const DirKey, value: usize) void {
        const key: Key = .{ d, input };
        const res = self.data.getOrPut(key) catch unreachable;
        if (res.found_existing) {
            if (value < res.value_ptr.*) res.value_ptr.* = value;
        } else {
            const duped_input = self.data.allocator.dupe(DirKey, input) catch unreachable;
            const duped_key: Key = .{ d, duped_input };
            res.key_ptr.* = duped_key;
            res.value_ptr.* = value;
        }
    }

    fn get(self: Memo, d: u8, input: []const DirKey) ?usize {
        const key: Key = .{ d, input };
        return self.data.get(key);
    }
};

inline fn dirpadSolveStep(ctx: *Context, dpad: u8, pos: Pos, target: Pos, input: []const DirKey, full_input: []const DirKey, seq: *Result, result: *Result) usize {
    if (pos.x == target.x) {
        const key, const steps =
            if (pos.y > target.y) .{ DirKey.up, pos.y - target.y } else .{ DirKey.down, target.y - pos.y };
        seq.appendNTimes(key, steps) catch unreachable;
        seq.append(.A) catch unreachable;
        return @call(.always_tail, dirpadSolve, .{ ctx, dpad, target, input, full_input, seq, result });
    } else if (pos.y == target.y) {
        const key, const steps =
            if (pos.x > target.x) .{ DirKey.left, pos.x - target.x } else .{ DirKey.right, target.x - pos.x };
        seq.appendNTimes(key, steps) catch unreachable;
        seq.append(.A) catch unreachable;
        return @call(.always_tail, dirpadSolve, .{ ctx, dpad, target, input, full_input, seq, result });
    } else {
        const key_x, const steps_x =
            if (pos.x > target.x) .{ DirKey.left, pos.x - target.x } else .{ DirKey.right, target.x - pos.x };
        const key_y, const steps_y =
            if (pos.y > target.y) .{ DirKey.up, pos.y - target.y } else .{ DirKey.down, target.y - pos.y };

        const seq_len = seq.items.len;

        var len1: ?usize = null;
        var len2: ?usize = null;

        if (!(pos.y == 0 and target.x == 0)) {
            seq.ensureUnusedCapacity(steps_x + steps_y + 1) catch unreachable;
            seq.appendNTimesAssumeCapacity(key_x, steps_x);
            seq.appendNTimesAssumeCapacity(key_y, steps_y);
            seq.appendAssumeCapacity(.A);
            len1 = dirpadSolve(ctx, dpad, target, input, full_input, seq, result);
        }

        seq.items.len = seq_len;
        var seq2 = seq;

        if (!(pos.x == 0 and target.y == 0)) {
            seq2.ensureUnusedCapacity(steps_x + steps_y + 1) catch unreachable;
            seq2.appendNTimesAssumeCapacity(key_y, steps_y);
            seq2.appendNTimesAssumeCapacity(key_x, steps_x);
            seq2.appendAssumeCapacity(.A);
            len2 = dirpadSolve(ctx, dpad, target, input, full_input, seq2, result);
        }

        if (len1) |l1| {
            if (len2) |l2| {
                return @min(l1, l2);
            } else {
                return l1;
            }
        }
        return len2.?;
    }
}

fn dirpadSolve(ctx: *Context, dpad: u8, pos: Pos, input: []const DirKey, full_input: []const DirKey, seq: *Result) usize {
    if (input.len == 0) {
        if (dpad <= 1) {
            ctx.memo.add(dpad, full_input, seq.items.len);

            std.debug.print("dpad {} - result len {}\n", .{ dpad, seq.items.len });
            const res = seq.items.len;
            seq.deinit();
            return res;
        } else {
            std.debug.print("dpad {}: ", .{dpad});
            //printSeq(seq.items);

            if (ctx.memo.get(dpad - 1, seq.items)) |len| {
                std.debug.print("Got len from memo: {}\n", .{len});
                seq.deinit();
                return len;
            }

            var dir_seq = Result.init(seq.allocator);
            //defer dir_seq.deinit();
            return @call(.always_tail, dirpadSolve, .{ ctx, dpad - 1, DirPad.keyPos(.A), seq.items, seq.items, &dir_seq });
            //const res = dirpadSolve(ctx, dpad - 1, DirPad.keyPos(.A), seq.items, seq.items, &dir_seq, result);
            //ctx.memo.add(dpad, full_input, res);
            //return res;
        }
    }

    if (input.len == full_input.len) {
        if (ctx.memo.get(dpad, full_input)) |len| {
            //if (ctx.memo.get(dpad, input)) |len| {
            std.debug.print("Got len from memo: {}\n", .{len});
            seq.deinit();
            return len;
        }
    }

    const key = input[0];
    const target = DirPad.keyPos(key);
    return dirpadSolveStep(ctx, dpad, pos, target, input[1..], full_input, seq);
}

fn generatePaths(alloc: std.mem.Allocator, pos: Pos, target: Pos, results: [][]const DirKey) [][]const DirKey {
    if (pos.x == target.x) {
        const key, const steps =
            if (pos.y > target.y) .{ DirKey.up, pos.y - target.y } else .{ DirKey.down, target.y - pos.y };
        var path = alloc.alloc(DirKey, steps + 1) catch @panic("OOM");
        @memset(path[0..steps], key);
        path[steps] = .A;
        results[0] = path;
        return results[0..1];
    } else if (pos.y == target.y) {
        const key, const steps =
            if (pos.x > target.x) .{ DirKey.left, pos.x - target.x } else .{ DirKey.right, target.x - pos.x };
        var path = alloc.alloc(DirKey, steps + 1) catch @panic("OOM");
        @memset(path[0..steps], key);
        path[steps] = .A;
        results[0] = path;
        return results[0..1];
    } else {
        const key_x, const steps_x =
            if (pos.x > target.x) .{ DirKey.left, pos.x - target.x } else .{ DirKey.right, target.x - pos.x };
        const key_y, const steps_y =
            if (pos.y > target.y) .{ DirKey.up, pos.y - target.y } else .{ DirKey.down, target.y - pos.y };

        var index: usize = 0;
        if (!(pos.y == 0 and target.x == 0)) {
            const steps = steps_x + steps_y;
            var path = alloc.alloc(DirKey, steps + 1) catch @panic("OOM");
            @memset(path[0..steps_x], key_x);
            @memset(path[steps_x .. steps_x + steps_y], key_y);
            path[steps] = .A;
            results[index] = path;
            index += 1;
        }

        if (!(pos.x == 0 and target.y == 0)) {
            const steps = steps_x + steps_y;
            var path = alloc.alloc(DirKey, steps + 1) catch @panic("OOM");
            @memset(path[0..steps_y], key_y);
            @memset(path[steps_y .. steps_y + steps_x], key_x);
            path[steps] = .A;
            results[index] = path;
            index += 1;
        }

        return results[0..index];
    }
}

fn dirpadSolve2(ctx: *Context, dpad: u8, input: []const DirKey) usize {
    if (dpad == 0) {
        ctx.memo.add(dpad, input, input.len);
        return input.len;
    }

    if (ctx.memo.get(dpad, input)) |len| {
        //std.debug.print("{} got from memo {}\n", .{ dpad, len });
        return len;
    }

    const alloc = ctx.memo.data.allocator;

    var result_len: usize = 0;

    var pos = DirPad.keyPos(.A);
    for (input) |key| {
        const target = DirPad.keyPos(key);

        var min_len: usize = std.math.maxInt(usize);

        var results_buffer: [2][]const DirKey = undefined;
        const paths = generatePaths(alloc, pos, target, &results_buffer);

        for (paths) |path| {
            const res = dirpadSolve2(ctx, dpad - 1, path);
            min_len = @min(min_len, res);

            alloc.free(path);
        }
        result_len += min_len;
        pos = target;
    }

    ctx.memo.add(dpad, input, result_len);
    return result_len;
}

fn solveOne(ctx: *Context, alloc: std.mem.Allocator, input: []const u8) usize {
    var seq = std.ArrayList(DirKey).init(alloc);
    defer seq.deinit();

    const start_pos = Numpad.keyPos(.A);
    return numpadSolve(ctx, start_pos, input, &seq);
}

fn solve(alloc: std.mem.Allocator, input: []const []const u8, dir_pads: u8) usize {
    var result: usize = 0;
    for (input) |door_code| {
        std.debug.print("Code {s} working...\n", .{door_code});
        var ctx = Context{
            .dir_pads = dir_pads,
            .memo = Memo.init(alloc),
        };
        defer ctx.memo.deinit();

        const code_n = std.fmt.parseInt(u32, door_code[0 .. door_code.len - 1], 10) catch unreachable;
        const shortest_len = solveOne(&ctx, alloc, door_code);
        std.debug.print("{s}: {} * {} = {}\n", .{ door_code, shortest_len, code_n, shortest_len * code_n });
        result += shortest_len * code_n;
    }
    return result;
}

test "p1 - example" {
    const input: []const []const u8 = &[_][]const u8{ "029A", "980A", "179A", "456A", "379A" };

    const result = solve(std.testing.allocator, input, 2);
    try std.testing.expectEqual(126384, result);
}

test "p2 - example" {
    const input: []const []const u8 = puzzle_input;

    const result = solve(std.testing.allocator, input, 2);
    try std.testing.expectEqual(237342, result);
}
