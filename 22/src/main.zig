const std = @import("std");

const puzzle_input = @embedFile("input.txt");

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    const seeds = parse(alloc, puzzle_input);
    defer alloc.free(seeds);

    const result_1 = solve1(seeds);
    std.debug.print("Sum of randoms is {}\n", .{result_1});

    const sequences = calculateSequences(alloc, seeds);
    defer alloc.free(sequences);

    const result_2 = findMostBananas(alloc, sequences);
    std.debug.print("Most bananas {}\n", .{result_2});
}

fn solve1(seeds: []const u32) usize {
    var result: usize = 0;
    for (seeds) |seed| {
        var r = Random.seed(seed);
        result += r.Nth(2000);
    }
    return result;
}

fn parse(alloc: std.mem.Allocator, input: []const u8) []const u32 {
    var result = std.ArrayList(u32).init(alloc);

    var iter = std.mem.splitScalar(u8, input, '\n');
    while (iter.next()) |line| {
        if (line.len == 0) continue;
        const n = std.fmt.parseInt(u32, line, 10) catch @panic("invalid input");
        result.append(n) catch @panic("OOM");
    }

    return result.toOwnedSlice() catch unreachable;
}

const Random = struct {
    state: u32,

    fn seed(s: u32) Random {
        return Random{ .state = s };
    }

    fn prune(x: u64) u64 {
        return x & 0xFFFFFF;
    }

    fn mix(a: u64, b: u64) u64 {
        return a ^ b;
    }

    fn next(self: *Random) u32 {
        // - Calculate the result of multiplying the secret number by 64. Then,
        // mix this result into the secret number. Finally, prune the secret
        // number.
        // - Calculate the result of dividing the secret number by 32. Round
        // the result down to the nearest integer. Then, mix this result into
        // the secret number. Finally, prune the secret number.
        // - Calculate the result of multiplying the secret number by 2048.
        // Then, mix this result into the secret number. Finally, prune the
        // secret number.

        // Each step of the above process involves mixing and pruning:

        // - To mix a value into the secret number, calculate the bitwise XOR
        // of the given value and the secret number. Then, the secret number
        // becomes the result of that operation. (If the secret number is 42
        // and you were to mix 15 into the secret number, the secret number
        // would become 37.)
        // - To prune the secret number, calculate the value of the secret
        // number modulo 16777216. Then, the secret number becomes the result
        // of that operation. (If the secret number is 100000000 and you were
        // to prune the secret number, the secret number would become
        // 16113920.)

        const m64 = prune(mix(self.state, self.state << 6));
        const d32 = prune(mix(m64, m64 >> 5));
        const m2048 = prune(mix(d32, d32 << 11));

        self.state = @truncate(m2048);
        return self.state;
    }

    fn Nth(self: *Random, n: u32) u32 {
        var i = n;
        while (i > 1) : (i -= 1) _ = self.next();
        return self.next();
    }
};

test "simple test" {
    var r = Random.seed(123);
    try std.testing.expectEqual(15887950, r.next());
    try std.testing.expectEqual(16495136, r.next());
    try std.testing.expectEqual(527345, r.next());
    try std.testing.expectEqual(704524, r.next());
    try std.testing.expectEqual(1553684, r.next());
    try std.testing.expectEqual(12683156, r.next());
    try std.testing.expectEqual(11100544, r.next());
    try std.testing.expectEqual(12249484, r.next());
    try std.testing.expectEqual(7753432, r.next());
    try std.testing.expectEqual(5908254, r.next());
}

test "p1 - example" {
    const input =
        \\1
        \\10
        \\100
        \\2024
    ;
    const seeds = parse(std.testing.allocator, input);
    defer std.testing.allocator.free(seeds);
    try std.testing.expectEqual(4, seeds.len);

    var results: [4]u32 = undefined;

    for (seeds, &results) |seed, *res| {
        var r = Random.seed(seed);
        res.* = r.Nth(2000);
    }

    try std.testing.expectEqualSlices(u32, &[_]u32{ 8685429, 4700978, 15273692, 8667524 }, &results);
}

const Seq = struct {
    bananas: [2000]u8,
    changes: [2000]i8,
    map: std.AutoHashMap(u32, u8),
};

fn freeSequences(sequences: []const Seq) void {
    const alloc = sequences[0].map.allocator;
    for (sequences) |seq| {
        @constCast(&seq.map).deinit();
    }
    alloc.free(sequences);
}

fn calculateSequences(alloc: std.mem.Allocator, seeds: []const u32) []const Seq {
    var sequences = alloc.alloc(Seq, seeds.len) catch @panic("OOM");
    errdefer alloc.free(sequences);

    for (seeds, 0..) |seed, seq_index| {
        var seq = &sequences[seq_index];
        var r = Random.seed(seed);
        var curr = seed;
        seq.bananas[0] = @truncate(curr % 10);
        seq.changes[0] = 0;
        for (1..2000) |index| {
            const n = r.next();
            const p: i8 = @intCast(curr % 10);
            const c: i8 = @intCast(n % 10);
            const diff = c - p;
            curr = n;

            seq.bananas[index] = @intCast(p);
            seq.changes[index] = diff;
        }

        seq.map = std.AutoHashMap(u32, u8).init(alloc);
        for (1..seq.changes.len - 4) |ch_index| {
            const changes = seq.changes[ch_index .. ch_index + 4];
            const key = changesKey(changes);
            const bananas = seq.bananas[ch_index + 4];
            _ = seq.map.getOrPutValue(key, bananas) catch @panic("OOM");
            //if (!seq.map.contains(key)) {
            //    seq.map.put(key, bananas) catch @panic("OOM");
            //}
        }
    }
    return sequences;
}

const Memo = std.AutoArrayHashMap(u32, usize);

fn changesKey(changes: []const i8) u32 {
    var result: u32 = 0;
    for (changes, 0..) |ch, index| {
        const c: u8 = @bitCast(ch);
        result |= @as(u32, c) << (@as(u5, @truncate(index)) * 8);
    }
    return result;
}

fn findMostBananas(alloc: std.mem.Allocator, sequences: []const Seq) usize {
    var memo = Memo.init(alloc);
    defer memo.deinit();

    std.debug.print("{} buyers\n", .{sequences.len});

    var result: usize = 0;
    for (sequences, 0..) |seq, seq_i| {
        for (1..seq.changes.len - 4) |ch_index| {
            const changes = seq.changes[ch_index .. ch_index + 4];
            const key = changesKey(changes);

            if (memo.contains(key)) continue;

            var total: usize = 0;
            for (sequences) |sq| {
                if (sq.map.get(key)) |bananas| {
                    total += bananas;
                }

                //if (std.mem.indexOf(i8, &sq.changes, changes)) |index| {
                //    if (index + 4 >= sq.bananas.len) continue;

                //    const bs = sq.bananas[index + 4];
                //    total += bs;
                //}
            }

            memo.put(key, total) catch @panic("OOM");

            //std.debug.print("changes {any}: {} bananas\n", .{ changes, total });
            result = @max(result, total);
        }
        std.debug.print("{} / {}\n", .{ seq_i + 1, sequences.len });
    }
    return result;
}

test "p2 - example" {
    const input =
        \\1
        \\2
        \\3
        \\2024
    ;

    const seeds = parse(std.testing.allocator, input);
    defer std.testing.allocator.free(seeds);

    //for (seeds[0..1]) |seed| {
    //    var r = Random.seed(seed);
    //    var curr = seed;
    //    std.debug.print("{}: {}\n", .{ curr, curr % 10 });
    //    for (0..10) |_| {
    //        const n = r.next();
    //        const p: i32 = @intCast(curr % 10);
    //        const c: i32 = @intCast(n % 10);
    //        const diff = c - p;
    //        curr = n;
    //        std.debug.print("{}: {} ({})\n", .{ curr, c, diff });
    //    }
    //}

    const sequences = calculateSequences(std.testing.allocator, seeds);
    defer freeSequences(sequences);

    const result = findMostBananas(std.testing.allocator, sequences);
    try std.testing.expectEqual(23, result);
}
