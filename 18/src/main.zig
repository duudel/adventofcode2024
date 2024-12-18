const std = @import("std");

const puzzle_input = @embedFile("input.txt");

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    const byte_positions = try parseBytePositions(alloc, puzzle_input);
    defer byte_positions.deinit();

    var grid = try Grid.init(alloc, 71);
    defer grid.deinit();

    dropBytes(&grid, byte_positions.items[0..1024]);

    const result = try findShortestPath(alloc, grid, Pos.from(0, 0), Pos.from(70, 70));
    std.debug.print("Result is {} steps\n", .{result});

    const blocking_byte = (try byteThatBlocksPath(alloc, &grid, byte_positions.items[1024..])).?;
    std.debug.print("Blocking byte position is {},{}\n", .{ blocking_byte.x, blocking_byte.y });
}

const Pos = struct {
    x: u32,
    y: u32,

    fn from(x: usize, y: usize) Pos {
        return Pos{ .x = @intCast(x), .y = @intCast(y) };
    }
};

const Grid = struct {
    const BitSet = std.bit_set.DynamicBitSet;

    size: u32,
    data: BitSet,

    fn init(alloc: std.mem.Allocator, size: u32) !Grid {
        return Grid{
            .size = size,
            .data = try BitSet.initEmpty(alloc, size * size),
        };
    }

    fn deinit(grid: *Grid) void {
        grid.data.deinit();
    }

    fn set(self: *Grid, pos: Pos) void {
        const index = pos.y * self.size + pos.x;
        self.data.set(index);
    }

    fn unset(self: *Grid, pos: Pos) void {
        const index = pos.y * self.size + pos.x;
        self.data.unset(index);
    }

    fn isSet(self: Grid, pos: Pos) bool {
        const index = pos.y * self.size + pos.x;
        return self.data.isSet(index);
    }

    fn movePos(self: Grid, pos: Pos, delta_x: i32, delta_y: i32) ?Pos {
        const x: i32 = @as(i32, @intCast(pos.x)) + delta_x;
        const y: i32 = @as(i32, @intCast(pos.y)) + delta_y;
        if ((0 <= x and x < self.size) and
            (0 <= y and y < self.size))
        {
            const new_pos = Pos{ .x = @intCast(x), .y = @intCast(y) };
            if (!self.isSet(new_pos)) return new_pos;
        }
        return null;
    }
};

fn parseBytePositions(alloc: std.mem.Allocator, input: []const u8) !std.ArrayList(Pos) {
    var result = std.ArrayList(Pos).init(alloc);
    var iter = std.mem.splitScalar(u8, input, '\n');
    while (iter.next()) |line| {
        if (line.len == 0) continue;

        const comma_index = std.mem.indexOfScalar(u8, line, ',').?;
        const x = try std.fmt.parseInt(u32, line[0..comma_index], 10);
        const y = try std.fmt.parseInt(u32, line[comma_index + 1 ..], 10);
        try result.append(Pos{ .x = x, .y = y });
    }
    return result;
}

fn dropBytes(grid: *Grid, byte_positions: []const Pos) void {
    for (byte_positions) |pos| {
        grid.set(pos);
    }
}

fn printGrid(grid: Grid) void {
    for (0..grid.size) |y| {
        for (0..grid.size) |x| {
            const pos = Pos.from(x, y);
            const c: u8 = if (grid.isSet(pos)) '#' else '.';
            const bytes: [1]u8 = .{c};
            std.io.getStdErr().writeAll(&bytes) catch unreachable;
        }
        std.io.getStdErr().writeAll("\n") catch unreachable;
    }
}

const Visited = struct {
    size: u32,
    data: []u32,

    fn init(alloc: std.mem.Allocator, size: u32) !Visited {
        const data = try alloc.alloc(u32, size * size);
        @memset(data, std.math.maxInt(u32));
        return Visited{
            .size = size,
            .data = data,
        };
    }

    fn deinit(self: *Visited, alloc: std.mem.Allocator) void {
        alloc.free(self.data);
    }

    fn clear(self: *Visited) void {
        @memset(self.data, std.math.maxInt(u32));
    }

    fn at(self: *Visited, pos: Pos) u32 {
        const index = pos.y * self.size + pos.x;
        return self.data[index];
    }

    fn set(self: *Visited, pos: Pos, steps: u32) bool {
        const index = pos.y * self.size + pos.x;
        if (self.data[index] > steps) {
            self.data[index] = steps;
            return true;
        }
        return false;
    }
};

fn findPath(grid: Grid, visited: *Visited, pos: Pos, end: Pos, steps: u32) void {
    if (!visited.set(pos, steps)) return;
    if (std.meta.eql(pos, end)) return;

    if (grid.movePos(pos, -1, 0)) |new_pos| {
        findPath(grid, visited, new_pos, end, steps + 1);
    }
    if (grid.movePos(pos, 1, 0)) |new_pos| {
        findPath(grid, visited, new_pos, end, steps + 1);
    }
    if (grid.movePos(pos, 0, -1)) |new_pos| {
        findPath(grid, visited, new_pos, end, steps + 1);
    }
    if (grid.movePos(pos, 0, 1)) |new_pos| {
        findPath(grid, visited, new_pos, end, steps + 1);
    }
}

fn findShortestPath(alloc: std.mem.Allocator, grid: Grid, start: Pos, end: Pos) !usize {
    var visited = try Visited.init(alloc, grid.size);
    defer visited.deinit(alloc);

    findPath(grid, &visited, start, end, 0);

    return visited.at(end);
}

const example_input =
    \\5,4
    \\4,2
    \\4,5
    \\3,0
    \\2,1
    \\6,3
    \\2,4
    \\1,5
    \\0,6
    \\3,3
    \\2,6
    \\5,1
    \\1,2
    \\5,5
    \\2,5
    \\6,5
    \\1,4
    \\0,4
    \\6,4
    \\1,1
    \\6,1
    \\1,0
    \\0,5
    \\1,6
    \\2,0
;

test "p1 - example" {
    const byte_positions = try parseBytePositions(std.testing.allocator, example_input);
    defer byte_positions.deinit();
    var grid = try Grid.init(std.testing.allocator, 7);
    defer grid.deinit();

    dropBytes(&grid, byte_positions.items[0..12]);

    printGrid(grid);

    const result = findShortestPath(std.testing.allocator, grid, Pos.from(0, 0), Pos.from(6, 6));
    try std.testing.expectEqual(22, result);
}

fn findAnyPath(grid: Grid, visited: *Visited, pos: Pos, end: Pos, steps: u32) void {
    if (visited.at(end) < std.math.maxInt(u32)) return;
    if (!visited.set(pos, steps)) return;
    if (std.meta.eql(pos, end)) return;

    if (grid.movePos(pos, -1, 0)) |new_pos| {
        findPath(grid, visited, new_pos, end, steps + 1);
    }
    if (grid.movePos(pos, 1, 0)) |new_pos| {
        findPath(grid, visited, new_pos, end, steps + 1);
    }
    if (grid.movePos(pos, 0, -1)) |new_pos| {
        findPath(grid, visited, new_pos, end, steps + 1);
    }
    if (grid.movePos(pos, 0, 1)) |new_pos| {
        findPath(grid, visited, new_pos, end, steps + 1);
    }
}

fn byteThatBlocksPath_naive(alloc: std.mem.Allocator, grid: *Grid, byte_positions: []const Pos) !?Pos {
    var visited = try Visited.init(alloc, grid.size);
    defer visited.deinit(alloc);

    const start = Pos.from(0, 0);
    const end = Pos.from(grid.size - 1, grid.size - 1);

    for (byte_positions, 0..) |byte_pos, index| {
        std.debug.print("Byte {} dropping...", .{index});
        grid.set(byte_pos);

        findAnyPath(grid.*, &visited, start, end, 0);
        if (visited.at(end) == std.math.maxInt(u32)) {
            return byte_pos;
        }

        visited.clear();
    }
    return null;
}

fn undropBytes(grid: *Grid, byte_positions: []const Pos) void {
    for (byte_positions) |pos| {
        grid.unset(pos);
    }
}

fn byteThatBlocksPath(alloc: std.mem.Allocator, grid: *Grid, byte_positions: []const Pos) !?Pos {
    var visited = try Visited.init(alloc, grid.size);
    defer visited.deinit(alloc);

    const start = Pos.from(0, 0);
    const end = Pos.from(grid.size - 1, grid.size - 1);

    var start_index: usize = 0;
    var end_index: usize = byte_positions.len;

    while (start_index + 1 < end_index) {
        const mid_index = start_index + (end_index - start_index) / 2;

        dropBytes(grid, byte_positions[start_index..mid_index]);

        findAnyPath(grid.*, &visited, start, end, 0);
        if (visited.at(end) == std.math.maxInt(u32)) {
            // path blocked
            end_index = mid_index;
            undropBytes(grid, byte_positions[start_index..mid_index]);
        } else {
            // path not blocked
            start_index = mid_index;
        }

        visited.clear();
    }
    return byte_positions[start_index];
}

test "p2 - example" {
    const byte_positions = try parseBytePositions(std.testing.allocator, example_input);
    defer byte_positions.deinit();
    var grid = try Grid.init(std.testing.allocator, 7);
    defer grid.deinit();

    dropBytes(&grid, byte_positions.items[0..12]);

    printGrid(grid);

    const pos = try byteThatBlocksPath(std.testing.allocator, &grid, byte_positions.items[12..]);

    try std.testing.expectEqual(Pos{ .x = 6, .y = 1 }, pos.?);
}
