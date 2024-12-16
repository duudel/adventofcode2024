const std = @import("std");

const puzzle_input = @embedFile("input.txt");

pub fn main() !void {
    const map = Map.parse(puzzle_input);
    const result = try findBestPathScore(std.heap.page_allocator, map);
    std.debug.print("Result is {?}\n", .{result});

    var tiles = try findBestPathTiles(std.heap.page_allocator, map, result.?);
    defer tiles.deinit();

    //printMapAndTiles(map, tiles.keys());

    std.debug.print("Tiles part of any best path: {}\n", .{tiles.count()});
}

const Pos = struct {
    x: u32,
    y: u32,

    fn move(self: Pos, dir: Dir) Pos {
        return switch (dir) {
            .north => Pos{ .x = self.x, .y = self.y - 1 },
            .east => Pos{ .x = self.x + 1, .y = self.y },
            .south => Pos{ .x = self.x, .y = self.y + 1 },
            .west => Pos{ .x = self.x - 1, .y = self.y },
        };
    }

    fn from(x: usize, y: usize) Pos {
        return Pos{ .x = @intCast(x), .y = @intCast(y) };
    }
};

const Dir = enum {
    north,
    east,
    south,
    west,

    fn turnClockwise(self: Dir) Dir {
        return switch (self) {
            .north => .east,
            .east => .south,
            .south => .west,
            .west => .north,
        };
    }

    fn turnCounterclockwise(self: Dir) Dir {
        return switch (self) {
            .north => .west,
            .east => .north,
            .south => .east,
            .west => .south,
        };
    }
};

const Map = struct {
    width: u32,
    height: u32,
    data: []const u8,
    start: Pos,
    end: Pos,

    fn parse(input: []const u8) Map {
        const width = blk: {
            var w: u32 = 0;
            while (w < input.len and input[w] != '\n') : (w += 1) {}
            break :blk w;
        };
        const height: u32 = @intCast((input.len + 1) / (width + 1));

        var start: Pos = undefined;
        var end: Pos = undefined;
        for (0..height) |y| {
            for (0..width) |x| {
                const index = y * (width + 1) + x;
                switch (input[index]) {
                    'S' => start = Pos.from(x, y),
                    'E' => end = Pos.from(x, y),
                    else => {},
                }
            }
        }
        return Map{
            .width = width,
            .height = height,
            .data = input,
            .start = start,
            .end = end,
        };
    }

    fn at(self: Map, pos: Pos) u8 {
        std.debug.assert(0 <= pos.x and pos.x < self.width);
        std.debug.assert(0 <= pos.y and pos.y < self.height);
        const index: u32 = pos.y * (self.width + 1) + pos.x;
        return self.data[index];
    }
};

const Visited = struct {
    width: u32,
    height: u32,
    data: []u32,

    fn init(alloc: std.mem.Allocator, w: u32, h: u32) !Visited {
        const data = try alloc.alloc(u32, w * h);
        @memset(data, std.math.maxInt(u32));
        return Visited{
            .width = w,
            .height = h,
            .data = data,
        };
    }

    fn deinit(self: *Visited, alloc: std.mem.Allocator) void {
        alloc.free(self.data);
    }

    // return true, if new score is lower than previous
    fn set(self: *Visited, pos: Pos, score: u32) bool {
        std.debug.assert(0 <= pos.x and pos.x < self.width);
        std.debug.assert(0 <= pos.y and pos.y < self.height);
        const index: u32 = pos.y * self.width + pos.x;
        const prev = self.data[index];
        if (score < prev) {
            self.data[index] = score;
            return true;
        }
        return false;
    }

    fn get(self: Visited, pos: Pos) u32 {
        std.debug.assert(0 <= pos.x and pos.x < self.width);
        std.debug.assert(0 <= pos.y and pos.y < self.height);
        const index: u32 = pos.y * self.width + pos.x;
        return self.data[index];
    }
};

fn select(old_value: ?u32, new_value: u32) u32 {
    if (old_value) |old| {
        return if (old < new_value) old else new_value;
    }
    return new_value;
}

fn findPath(map: Map, pos: Pos, dir: Dir, result: u32, visited: *Visited) void {
    switch (map.at(pos)) {
        '#' => return,
        'E' => {
            _ = visited.set(pos, result);
            return;
        },
        else => {},
    }

    if (map.at(pos.move(dir)) == '#') {
        if (!visited.set(pos, result + 1000)) return;
    } else {
        if (!visited.set(pos, result)) return;
    }

    findPath(map, pos.move(dir), dir, result + 1, visited);
    {
        const new_dir = dir.turnClockwise();
        findPath(map, pos.move(new_dir), new_dir, result + 1000 + 1, visited);
    }
    {
        const new_dir = dir.turnCounterclockwise();
        findPath(map, pos.move(new_dir), new_dir, result + 1000 + 1, visited);
    }
}

fn findBestPathScore(alloc: std.mem.Allocator, map: Map) !?u32 {
    var visited = try Visited.init(alloc, map.width, map.height);
    defer visited.deinit(alloc);
    findPath(map, map.start, .east, 0, &visited);
    const result = visited.get(map.end);
    if (result == std.math.maxInt(u32))
        return null;
    return result;
}

const example1_input =
    \\###############
    \\#.......#....E#
    \\#.#.###.#.###.#
    \\#.....#.#...#.#
    \\#.###.#####.#.#
    \\#.#.#.......#.#
    \\#.#.#####.###.#
    \\#...........#.#
    \\###.#.#####.#.#
    \\#...#.....#.#.#
    \\#.#.#.###.#.#.#
    \\#.....#...#.#.#
    \\#.###.#.#.#.#.#
    \\#S..#.....#...#
    \\###############
;

test "p1 - example-1" {
    const map = Map.parse(example1_input);
    const result = findBestPathScore(std.testing.allocator, map);
    try std.testing.expectEqual(7036, result);
}

const example2_input =
    \\#################
    \\#...#...#...#..E#
    \\#.#.#.#.#.#.#.#.#
    \\#.#.#.#...#...#.#
    \\#.#.#.#.###.#.#.#
    \\#...#.#.#.....#.#
    \\#.#.#.#.#.#####.#
    \\#.#...#.#.#.....#
    \\#.#.#####.#.###.#
    \\#.#.#.......#...#
    \\#.#.###.#####.###
    \\#.#.#...#.....#.#
    \\#.#.#.#####.###.#
    \\#.#.#.........#.#
    \\#.#.#.#########.#
    \\#S#.............#
    \\#################
;

test "p1 - example-2" {
    const map = Map.parse(example2_input);
    const result = findBestPathScore(std.testing.allocator, map);
    try std.testing.expectEqual(11048, result);
}

fn printMapAndTiles(map: Map, tiles: []const Pos) void {
    for (0..map.height) |y| {
        for (0..map.width) |x| {
            const pos = Pos.from(x, y);
            var found = false;
            for (tiles) |tile| {
                if (tile.x == pos.x and tile.y == pos.y) {
                    found = true;
                    break;
                }
            }
            if (found) {
                _ = std.io.getStdErr().write("O") catch unreachable;
            } else {
                _ = std.io.getStdErr().write(&.{map.at(pos)}) catch unreachable;
            }
        }
        _ = std.io.getStdErr().write("\n") catch unreachable;
    }
}

fn printVisited(visited: Visited) void {
    for (0..visited.height) |y| {
        for (0..visited.width) |x| {
            const pos = Pos.from(x, y);
            const v = visited.get(pos);
            if (v == std.math.maxInt(u32)) {
                _ = std.io.getStdErr().writeAll("\x1b[42m##\x1b[0m") catch unreachable;
            } else {
                const t = v / 1000;
                std.debug.print("{d:02}", .{t});
            }
        }
        _ = std.io.getStdErr().write("\n") catch unreachable;
        for (0..visited.width) |x| {
            const pos = Pos.from(x, y);
            const v = visited.get(pos);
            if (v == std.math.maxInt(u32)) {
                _ = std.io.getStdErr().writeAll("\x1b[42m##\x1b[0m") catch unreachable;
            } else {
                const t = v % 1000;
                std.debug.print("{d:02}", .{t});
            }
        }
        _ = std.io.getStdErr().write("\n") catch unreachable;
    }
}

const Visited2 = struct {
    width: u32,
    height: u32,
    data: []u32,

    fn init(alloc: std.mem.Allocator, w: u32, h: u32) !Visited2 {
        const data = try alloc.alloc(u32, 4 * w * h);
        @memset(data, std.math.maxInt(u32));
        return Visited2{
            .width = w,
            .height = h,
            .data = data,
        };
    }

    fn deinit(self: *Visited2, alloc: std.mem.Allocator) void {
        alloc.free(self.data);
    }

    fn indexAt(self: Visited2, pos: Pos, dir: Dir) usize {
        const dir_index: u4 = @intFromEnum(dir);
        return @as(usize, @intCast(dir_index * (self.width * self.height))) + pos.y * self.width + pos.x;
    }

    // return true, if new score is lower than previous
    fn set(self: *Visited2, pos: Pos, dir: Dir, score: u32) bool {
        std.debug.assert(0 <= pos.x and pos.x < self.width);
        std.debug.assert(0 <= pos.y and pos.y < self.height);
        const index = self.indexAt(pos, dir);
        const prev = self.data[index];
        if (score <= prev) {
            self.data[index] = score;
            return true;
        }
        return false;
    }

    fn get(self: Visited2, pos: Pos, dir: Dir) u32 {
        std.debug.assert(0 <= pos.x and pos.x < self.width);
        std.debug.assert(0 <= pos.y and pos.y < self.height);
        const index = self.indexAt(pos, dir);
        return self.data[index];
    }

    fn getBest(self: Visited2, pos: Pos) u32 {
        std.debug.assert(0 <= pos.x and pos.x < self.width);
        std.debug.assert(0 <= pos.y and pos.y < self.height);
        const index0 = self.indexAt(pos, .north);
        const index1 = self.indexAt(pos, .east);
        const index2 = self.indexAt(pos, .south);
        const index3 = self.indexAt(pos, .west);
        return @min(
            @min(self.data[index0], self.data[index1]),
            @min(self.data[index2], self.data[index3]),
        );
    }
};

const TileSet = std.AutoArrayHashMap(Pos, void);

const Ctx = struct {
    visited: *Visited2,
    tiles: *TileSet,
    best_score: u32,
};

fn findPathTiles(map: Map, pos: Pos, dir: Dir, result: u32, ctx: Ctx) !bool {
    if (result > ctx.best_score) return false;

    var visited = ctx.visited;
    var tiles = ctx.tiles;

    switch (map.at(pos)) {
        '#' => return false,
        'E' => {
            if (visited.set(pos, dir, result) and result == ctx.best_score) {
                return true;
            }
            return false;
        },
        else => {},
    }

    if (!visited.set(pos, dir, result)) {
        return false;
    }

    var is_on_best_path: bool = false;
    if (try findPathTiles(map, pos.move(dir), dir, result + 1, ctx)) {
        is_on_best_path = true;
    }
    {
        const new_dir = dir.turnClockwise();
        if (try findPathTiles(map, pos.move(new_dir), new_dir, result + 1000 + 1, ctx)) {
            is_on_best_path = true;
        }
    }
    {
        const new_dir = dir.turnCounterclockwise();
        if (try findPathTiles(map, pos.move(new_dir), new_dir, result + 1000 + 1, ctx)) {
            is_on_best_path = true;
        }
    }
    if (is_on_best_path) try tiles.put(pos, {});
    return is_on_best_path;
}

fn findBestPathTiles(alloc: std.mem.Allocator, map: Map, best_score: u32) !TileSet {
    var visited = try Visited2.init(alloc, map.width, map.height);
    defer visited.deinit(alloc);

    var tiles = TileSet.init(alloc);
    errdefer tiles.deinit();

    const ctx = Ctx{
        .visited = &visited,
        .tiles = &tiles,
        .best_score = best_score,
    };

    _ = try findPathTiles(map, map.start, .east, 0, ctx);

    try tiles.put(map.end, {});

    return tiles;
}

test "p2 - example-1" {
    const map = Map.parse(example1_input);

    var tiles = try findBestPathTiles(std.testing.allocator, map, 7036);
    defer tiles.deinit();

    printMapAndTiles(map, tiles.keys());

    try std.testing.expectEqual(45, tiles.count());
}

test "p2 - example-2" {
    const map = Map.parse(example2_input);

    var tiles = try findBestPathTiles(std.testing.allocator, map, 11048);
    defer tiles.deinit();

    printMapAndTiles(map, tiles.keys());

    try std.testing.expectEqual(64, tiles.count());
}
