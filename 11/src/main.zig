const std = @import("std");

const puzzle_input = "0 89741 316108 7641 756 9 7832357 91";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    {
        var stones = try parse(gpa.allocator(), puzzle_input);
        defer stones.deinit();

        for (0..25) |_| {
            try blink(&stones);
        }
        std.debug.print("After 25 blinks there are {} stones\n", .{stones.items.len});

        // takes too long to complete - separate solution needed for part 2

        //for (25..75) |_| {
        //    try blink(&stones);
        //}
        //std.debug.print("After 75 blinks there are {} stones\n", .{stones.items.len});
    }

    {
        const stones = try parse(gpa.allocator(), puzzle_input);
        defer stones.deinit();
        const result = try numberOfStonesAfterBlinks(gpa.allocator(), stones.items, 75);
        std.debug.print("After 75 blinks there are {} stones\n", .{result});
    }
}

const Stone = u64;

fn parse(alloc: std.mem.Allocator, input: []const u8) !std.ArrayList(Stone) {
    var result = std.ArrayList(Stone).init(alloc);

    var iter = std.mem.splitScalar(u8, input, ' ');
    while (iter.next()) |s| {
        const n = try std.fmt.parseInt(Stone, s, 10);
        try result.append(n);
    }

    return result;
}

fn even(stone: Stone) bool {
    const lg10 = std.math.log10(stone);
    return lg10 & 1 == 1;
}

fn split(stone: Stone) struct { Stone, Stone } {
    const lg10 = std.math.log10(stone);
    const ten = std.math.powi(Stone, 10, (lg10 + 1) / 2) catch unreachable;
    const a = stone / ten;
    const b = stone % ten;
    return .{ a, b };
}

fn blink(input: *std.ArrayList(Stone)) !void {
    var result = try std.ArrayList(Stone).initCapacity(input.allocator, input.items.len * 2);
    errdefer result.deinit();
    for (input.items) |stone| {
        if (stone == 0) {
            result.appendAssumeCapacity(1);
        } else if (even(stone)) {
            const a, const b = split(stone);
            result.appendAssumeCapacity(a);
            result.appendAssumeCapacity(b);
        } else {
            result.appendAssumeCapacity(stone * 2024);
        }
    }
    input.deinit();
    input.* = result;
}

fn afterNBlinks(input: *std.ArrayList(Stone), n: u8) !usize {
    for (0..n) |_| {
        try blink(input);
    }
    return input.items.len;
}

test "p1 - [0 1 10 99 999], 1 blink" {
    const input = "0 1 10 99 999";
    var stones = try parse(std.testing.allocator, input);
    defer stones.deinit();
    try blink(&stones);
    try std.testing.expectEqualSlices(Stone, &.{ 1, 2024, 1, 0, 9, 9, 2021976 }, stones.items);
}

test "p1 - [125 17], 6 blinks" {
    const input = "125 17";

    var stones = try parse(std.testing.allocator, input);
    defer stones.deinit();

    try blink(&stones);
    try std.testing.expectEqualSlices(Stone, &.{ 253000, 1, 7 }, stones.items);

    try blink(&stones);
    try std.testing.expectEqualSlices(Stone, &.{ 253, 0, 2024, 14168 }, stones.items);

    try blink(&stones);
    try std.testing.expectEqualSlices(Stone, &.{ 512072, 1, 20, 24, 28676032 }, stones.items);

    try blink(&stones);
    try std.testing.expectEqualSlices(Stone, &.{ 512, 72, 2024, 2, 0, 2, 4, 2867, 6032 }, stones.items);

    try blink(&stones);
    try std.testing.expectEqualSlices(Stone, &.{ 1036288, 7, 2, 20, 24, 4048, 1, 4048, 8096, 28, 67, 60, 32 }, stones.items);

    try blink(&stones);
    try std.testing.expectEqualSlices(Stone, &.{ 2097446912, 14168, 4048, 2, 0, 2, 4, 40, 48, 2024, 40, 48, 80, 96, 2, 8, 6, 7, 6, 0, 3, 2 }, stones.items);
}

const Memo = struct {
    const Key = Stone;
    const Value = struct {
        num: [75]usize,
    };

    store: std.AutoHashMap(Key, Value),

    fn init(alloc: std.mem.Allocator) Memo {
        const store = std.AutoHashMap(Key, Value).init(alloc);
        return .{ .store = store };
    }

    fn deinit(self: *Memo) void {
        self.store.deinit();
    }

    fn put(self: *Memo, stone: Stone, blinks: u8, num_stones: usize) !void {
        if (self.store.getPtr(stone)) |value| {
            value.num[blinks] = num_stones;
        } else {
            var value = Value{ .num = .{0} ** 75 };
            value.num[blinks] = num_stones;
            try self.store.put(stone, value);
        }
    }

    fn get(self: Memo, stone: Stone, blinks: u8) ?usize {
        if (self.store.getPtr(stone)) |value| {
            const res = value.num[blinks];
            return if (res == 0) null else res;
        }
        return null;
    }
};

fn numAfterBlinksForOneStone(memo: *Memo, stone: Stone, n: u8, blinks: u8) !usize {
    if (n == blinks) return 1;

    if (memo.get(stone, n)) |res| {
        return res;
    }

    if (stone == 0) {
        const res = try numAfterBlinksForOneStone(memo, 1, n + 1, blinks);
        try memo.put(stone, n, res);
        return res;
    } else if (even(stone)) {
        const a, const b = split(stone);
        const resa = try numAfterBlinksForOneStone(memo, a, n + 1, blinks);
        const resb = try numAfterBlinksForOneStone(memo, b, n + 1, blinks);
        try memo.put(stone, n, resa + resb);
        return resa + resb;
    } else {
        const res = try numAfterBlinksForOneStone(memo, stone * 2024, n + 1, blinks);
        try memo.put(stone, n, res);
        return res;
    }
}

fn numberOfStonesAfterBlinks(alloc: std.mem.Allocator, stones: []const Stone, blinks: u8) !usize {
    var memo = Memo.init(alloc);
    defer memo.deinit();

    var result: usize = 0;
    for (stones) |stone| {
        result += try numAfterBlinksForOneStone(&memo, stone, 0, blinks);
    }
    return result;
}

test "p2 - [0 1 10 99 999], 1 blink" {
    const input = "0 1 10 99 999";
    var stones = try parse(std.testing.allocator, input);
    defer stones.deinit();
    const result = try numberOfStonesAfterBlinks(std.testing.allocator, stones.items, 1);
    try std.testing.expectEqual(7, result);
}

test "p2 - [125 7], 6 blinks" {
    const slice: []const Stone = &.{ 125, 17 };

    var stones = std.ArrayList(Stone).init(std.testing.allocator);
    defer stones.deinit();
    try stones.appendSlice(slice);
    const expected_result = afterNBlinks(&stones, 6);

    const result = try numberOfStonesAfterBlinks(std.testing.allocator, slice, 6);
    try std.testing.expectEqual(expected_result, result);
}

test "p2 - [1], 25 blinks" {
    var stones = std.ArrayList(Stone).init(std.testing.allocator);
    defer stones.deinit();
    try stones.append(1);
    const expected_result = afterNBlinks(&stones, 25);

    var memo = Memo.init(std.testing.allocator);
    defer memo.deinit();

    const result = try numAfterBlinksForOneStone(&memo, 1, 0, 25);
    try std.testing.expectEqual(expected_result, result);
}

test "p2 - [13], 35 blinks" {
    var stones = std.ArrayList(Stone).init(std.testing.allocator);
    defer stones.deinit();
    try stones.append(13);
    const expected_result = afterNBlinks(&stones, 25);

    var memo = Memo.init(std.testing.allocator);
    defer memo.deinit();

    const result = try numAfterBlinksForOneStone(&memo, 13, 0, 25);
    try std.testing.expectEqual(expected_result, result);
}
