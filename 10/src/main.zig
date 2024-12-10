const std = @import("std");

const puzzle_input = @embedFile("input.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const scores = try calculateSumOfScores(gpa.allocator(), puzzle_input);
    std.debug.print("Sum of trailhead scores: {}\n", .{scores});

    const ratings = calculateSumOfRatings(puzzle_input);
    std.debug.print("Sum of trailhead ratings: {}\n", .{ratings});
}

const Pos = struct {
    x: i32,
    y: i32,

    fn at(comptime int_type: type, x: int_type, y: int_type) Pos {
        return Pos{
            .x = @intCast(x),
            .y = @intCast(y),
        };
    }

    fn move(self: Pos, dx: i32, dy: i32) Pos {
        return Pos{
            .x = self.x + dx,
            .y = self.y + dy,
        };
    }
};

const Map = struct {
    width: u32,
    height: u32,
    data: []const u8,

    fn at(self: Map, pos: Pos) u8 {
        std.debug.assert(0 <= pos.x and pos.x < self.width);
        std.debug.assert(0 <= pos.y and pos.y < self.height);
        const pitch = self.width + 1;
        const index: usize = @as(usize, @intCast(pos.y)) * pitch + @as(usize, @intCast(pos.x));
        return self.data[index];
    }

    fn get(self: Map, pos: Pos) ?u8 {
        if (!(0 <= pos.x and pos.x < self.width) or !(0 <= pos.y and pos.y < self.height)) {
            return null;
        }
        const pitch = self.width + 1;
        const index: usize = @as(usize, @intCast(pos.y)) * pitch + @as(usize, @intCast(pos.x));
        return self.data[index];
    }

    fn init(input: []const u8) Map {
        const width: u32 = blk: {
            var w: u32 = 0;
            while (w < input.len and input[w] != '\n') : (w += 1) {}
            break :blk w;
        };
        const height: u32 = @intCast((input.len + 1) / (width + 1));
        return Map{
            .width = width,
            .height = height,
            .data = input,
        };
    }
};

const Traversed = struct {
    width: u32,
    height: u32,
    data: std.bit_set.DynamicBitSet,

    fn deinit(self: *Traversed) void {
        self.data.deinit();
    }

    fn set(self: *Traversed, pos: Pos) void {
        std.debug.assert(0 <= pos.x and pos.x < self.width);
        std.debug.assert(0 <= pos.y and pos.y < self.height);
        const index: usize = @as(usize, @intCast(pos.y)) * self.width + @as(usize, @intCast(pos.x));
        self.data.set(index);
    }

    fn unset(self: Traversed, pos: Pos) void {
        std.debug.assert(0 <= pos.x and pos.x < self.width);
        std.debug.assert(0 <= pos.y and pos.y < self.height);
        const index: usize = @as(usize, @intCast(pos.y)) * self.width + @as(usize, @intCast(pos.x));
        self.data.unset(index);
    }

    fn isSet(self: Traversed, pos: Pos) bool {
        std.debug.assert(0 <= pos.x and pos.x < self.width);
        std.debug.assert(0 <= pos.y and pos.y < self.height);
        const index: usize = @as(usize, @intCast(pos.y)) * self.width + @as(usize, @intCast(pos.x));
        return self.data.isSet(index);
    }

    fn clear(self: *Traversed) void {
        const range = std.bit_set.Range{ .start = 0, .end = self.width * self.height };
        self.data.setRangeValue(range, false);
    }

    fn init(alloc: std.mem.Allocator, w: u32, h: u32) !Traversed {
        const data = try std.bit_set.DynamicBitSet.initEmpty(alloc, w * h);
        return Traversed{
            .width = w,
            .height = h,
            .data = data,
        };
    }
};

fn trailheadScore(map: Map, traversed: *Traversed, start_pos: Pos, expected: u8) usize {
    const current = map.get(start_pos);
    if (current != expected) return 0;

    if (traversed.isSet(start_pos)) return 0;

    traversed.set(start_pos);

    //std.debug.print("at {},{}: {c}\n", .{ start_pos.x, start_pos.y, current.? });

    if (current == '9') return 1;

    const next = expected + 1;
    return (trailheadScore(map, traversed, start_pos.move(-1, 0), next) +
        trailheadScore(map, traversed, start_pos.move(0, -1), next) +
        trailheadScore(map, traversed, start_pos.move(1, 0), next) +
        trailheadScore(map, traversed, start_pos.move(0, 1), next));
}

fn calculateSumOfScores(alloc: std.mem.Allocator, input: []const u8) !usize {
    const map = Map.init(input);
    var traversed = try Traversed.init(alloc, map.width, map.height);
    defer traversed.deinit();

    var result: usize = 0;

    for (0..map.height) |y| {
        for (0..map.width) |x| {
            const pos = Pos.at(usize, x, y);
            if (map.at(pos) == '0') {
                result += trailheadScore(map, &traversed, pos, '0');
                traversed.clear();
            }
        }
    }

    return result;
}

test "example-1" {
    const input =
        \\0123
        \\1234
        \\8765
        \\9876
    ;
    const result = try calculateSumOfScores(std.testing.allocator, input);
    try std.testing.expectEqual(1, result);
}

test "example-2" {
    const input =
        \\...0...
        \\...1...
        \\...2...
        \\6543456
        \\7.....7
        \\8.....8
        \\9.....9
    ;
    const result = try calculateSumOfScores(std.testing.allocator, input);
    try std.testing.expectEqual(2, result);
}

test "example-3" {
    const input =
        \\..90..9
        \\...1.98
        \\...2..7
        \\6543456
        \\765.987
        \\876....
        \\987....
    ;
    const result = try calculateSumOfScores(std.testing.allocator, input);
    try std.testing.expectEqual(4, result);
}

test "example-4" {
    const input =
        \\10..9..
        \\2...8..
        \\3...7..
        \\4567654
        \\...8..3
        \\...9..2
        \\.....01
    ;
    const result = try calculateSumOfScores(std.testing.allocator, input);
    try std.testing.expectEqual(3, result);
}

test "example-5" {
    const input =
        \\89010123
        \\78121874
        \\87430965
        \\96549874
        \\45678903
        \\32019012
        \\01329801
        \\10456732
    ;
    const result = try calculateSumOfScores(std.testing.allocator, input);
    try std.testing.expectEqual(36, result);
}

// part two

fn trailheadRating(map: Map, start_pos: Pos, expected: u8) usize {
    const current = map.get(start_pos);
    if (current != expected) return 0;

    if (current == '9') return 1;

    const next = expected + 1;
    return (trailheadRating(map, start_pos.move(-1, 0), next) +
        trailheadRating(map, start_pos.move(0, -1), next) +
        trailheadRating(map, start_pos.move(1, 0), next) +
        trailheadRating(map, start_pos.move(0, 1), next));
}

fn calculateSumOfRatings(input: []const u8) usize {
    const map = Map.init(input);

    var result: usize = 0;

    for (0..map.height) |y| {
        for (0..map.width) |x| {
            const pos = Pos.at(usize, x, y);
            if (map.at(pos) == '0') {
                result += trailheadRating(map, pos, '0');
            }
        }
    }

    return result;
}

test "example-6" {
    const input =
        \\.....0.
        \\..4321.
        \\..5..2.
        \\..6543.
        \\..7..4.
        \\..8765.
        \\..9....
    ;
    const result = calculateSumOfRatings(input);
    try std.testing.expectEqual(3, result);
}

test "example-7" {
    const input =
        \\..90..9
        \\...1.98
        \\...2..7
        \\6543456
        \\765.987
        \\876....
        \\987....
    ;
    const result = calculateSumOfRatings(input);
    try std.testing.expectEqual(13, result);
}

test "example-8" {
    const input =
        \\012345
        \\123456
        \\234567
        \\345678
        \\4.6789
        \\56789.
    ;
    const result = calculateSumOfRatings(input);
    try std.testing.expectEqual(227, result);
}

test "example-9" {
    const input =
        \\89010123
        \\78121874
        \\87430965
        \\96549874
        \\45678903
        \\32019012
        \\01329801
        \\10456732
    ;
    const result = calculateSumOfRatings(input);
    try std.testing.expectEqual(81, result);
}
