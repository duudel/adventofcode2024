const std = @import("std");

const puzzle_input = @embedFile("input.txt");

fn small_ex(alloc: std.mem.Allocator) !void {
    var map, var moves = try parseMapAndMoves(alloc, small_ex_input);
    defer map.deinit(alloc);

    simulate(&map, &moves);
}

fn p2_small_ex(alloc: std.mem.Allocator) !void {
    var map, var moves = try parseWideMapAndMoves(alloc, p2_small_ex_input);
    defer map.deinit(alloc);

    simulateWithWideBoxes(&map, &moves);
}

fn countBoxes(map: Map) usize {
    var n: usize = 0;
    var m: usize = 0;
    for (0..map.height) |y| {
        for (0..map.width) |x| {
            if (map.at(Pos.from(x, y)) == '[') {
                n += 1;
            }
            if (map.at(Pos.from(x, y)) == ']') {
                m += 1;
            }
        }
    }
    std.debug.assert(n == m);
    return n;
}

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    //if (true) return small_ex(alloc);
    //if (true) return p2_small_ex(alloc);

    {
        var map, var moves = try parseMapAndMoves(alloc, puzzle_input);
        defer map.deinit(alloc);

        simulate(&map, &moves);

        const result = calculateSumOfGps(map);
        std.debug.print("Part 1 - Sum of GPS coordinates is {}\n", .{result});
    }

    {
        var map, var moves = try parseWideMapAndMoves(alloc, puzzle_input);
        defer map.deinit(alloc);

        const a = countBoxes(map);

        simulateWithWideBoxes(&map, &moves);

        const b = countBoxes(map);

        std.debug.print("a = {}, b = {}\n", .{ a, b });
        std.debug.assert(a == b);

        // 1517281 - too low
        const result = calculateSumOfGpsWide(map);
        std.debug.print("Part 2 - Sum of GPS coordinates is {}\n", .{result});
    }
}

const Move = enum { up, down, right, left };

const Pos = struct {
    x: u32,
    y: u32,

    fn move(self: Pos, m: Move) Pos {
        return switch (m) {
            .up => Pos{ .x = self.x, .y = self.y - 1 },
            .down => Pos{ .x = self.x, .y = self.y + 1 },
            .right => Pos{ .x = self.x + 1, .y = self.y },
            .left => Pos{ .x = self.x - 1, .y = self.y },
        };
    }

    fn from(x: usize, y: usize) Pos {
        return Pos{ .x = @intCast(x), .y = @intCast(y) };
    }
};

const Map = struct {
    width: u32,
    height: u32,
    data: []u8,

    fn deinit(self: Map, alloc: std.mem.Allocator) void {
        alloc.free(self.data);
    }

    fn at(self: Map, pos: Pos) u8 {
        const index = pos.y * self.width + pos.x;
        return self.data[index];
    }

    fn put(self: *Map, pos: Pos, c: u8) void {
        const index = pos.y * self.width + pos.x;
        self.data[index] = c;
    }

    fn print(self: Map, writer: anytype) void {
        for (0..self.height) |y| {
            const row_beg = y * self.width;
            const row_end = row_beg + self.width;
            const row = self.data[row_beg..row_end];
            _ = writer.write(row) catch unreachable;
            _ = writer.write("\n") catch unreachable;
        }
    }
};

const Moves = struct {
    input: []const u8,
    index: usize,

    fn next(self: *Moves) ?Move {
        if (self.index >= self.input.len) return null;
        const result = switch (self.input[self.index]) {
            '^' => Move.up,
            'v' => Move.down,
            '>' => Move.right,
            '<' => Move.left,
            '\n' => {
                self.index += 1;
                return self.next();
            },
            else => |c| {
                std.debug.print("unrecognized move: '{}'\n", .{c});
                unreachable;
            },
        };
        self.index += 1;
        return result;
    }
};

fn parseMapAndMoves(alloc: std.mem.Allocator, input: []const u8) !struct { Map, Moves } {
    const width = blk: {
        var w: u32 = 0;
        while (w < input.len and input[w] != '\n') : (w += 1) {}
        break :blk w;
    };

    var line_iter = std.mem.splitSequence(u8, input, "\n\n");
    const map_data = line_iter.next().?;

    const height: u32 = @intCast((map_data.len + 1) / (width + 1));
    var data: []u8 = try alloc.alloc(u8, width * height);

    var map_iter = std.mem.splitScalar(u8, map_data, '\n');
    var row_n: usize = 0;
    while (map_iter.next()) |line| {
        if (line.len == 0) break;
        const row_beg = row_n * width;
        const row_end = row_beg + width;
        @memcpy(data[row_beg..row_end], line);

        row_n += 1;
    }

    var moves_data = line_iter.next().?;
    moves_data = std.mem.trim(u8, moves_data, "\n");

    return .{
        Map{
            .width = width,
            .height = height,
            .data = data,
        },
        Moves{
            .input = moves_data,
            .index = 0,
        },
    };
}

fn waitKey() void {
    if (@import("builtin").is_test) return;
    var buff: [1]u8 = undefined;
    _ = std.io.getStdIn().read(&buff) catch unreachable;
}

fn pushBox(map: *Map, robot_pos: Pos, box_pos: Pos, move: Move) Pos {
    var next_pos = box_pos.move(move);
    while (map.at(next_pos) != '#') {
        switch (map.at(next_pos)) {
            '.' => {
                map.put(next_pos, 'O');
                map.put(robot_pos, '.');
                map.put(box_pos, '.');
                return box_pos;
            },
            'O' => next_pos = next_pos.move(move),
            else => unreachable,
        }
    }
    return robot_pos;
}

fn simulate(map: *Map, moves: *Moves) void {
    var robot_pos = findRobotPos: {
        for (0..map.height) |y| {
            for (0..map.width) |x| {
                const p = Pos.from(x, y);
                if (map.at(p) == '@') {
                    map.put(p, '.');
                    break :findRobotPos p;
                }
            }
        }
        unreachable;
    };

    {
        std.debug.print("Initial state:\n", .{});
        map.put(robot_pos, '@');
        defer map.put(robot_pos, '.');
        map.print(std.io.getStdErr().writer());
        waitKey();
    }

    while (moves.next()) |move| {
        const next_pos: Pos = robot_pos.move(move);
        switch (map.at(next_pos)) {
            '.' => robot_pos = next_pos,
            '#' => {},
            'O' => robot_pos = pushBox(map, robot_pos, next_pos, move),
            else => {},
        }

        //{
        //    map.put(robot_pos, '@');
        //    defer map.put(robot_pos, '.');
        //    map.print(std.io.getStdErr().writer());
        //    waitKey();
        //}
    }

    {
        std.debug.print("Final state:\n", .{});
        map.put(robot_pos, '@');
        defer map.put(robot_pos, '.');
        map.print(std.io.getStdErr().writer());
        waitKey();
    }
}

fn calculateSumOfGps(map: Map) usize {
    var result: usize = 0;
    for (0..map.height) |y| {
        for (0..map.width) |x| {
            if (map.at(Pos.from(x, y)) == 'O') {
                result += y * 100 + x;
            }
        }
    }
    return result;
}

const small_ex_input =
    \\########
    \\#..O.O.#
    \\##@.O..#
    \\#...O..#
    \\#.#.O..#
    \\#...O..#
    \\#......#
    \\########
    \\
    \\<^^>>>vv<v>>v<<
;

test "p1 - small example" {
    var map, var moves = try parseMapAndMoves(std.testing.allocator, small_ex_input);
    defer map.deinit(std.testing.allocator);

    simulate(&map, &moves);

    const result = calculateSumOfGps(map);
    try std.testing.expectEqual(2028, result);
}

const large_ex_input =
    \\##########
    \\#..O..O.O#
    \\#......O.#
    \\#.OO..O.O#
    \\#..O@..O.#
    \\#O#..O...#
    \\#O..O..O.#
    \\#.OO.O.OO#
    \\#....O...#
    \\##########
    \\
    \\<vv>^<v^>v>^vv^v>v<>v^v<v<^vv<<<^><<><>>v<vvv<>^v^>^<<<><<v<<<v^vv^v>^
    \\vvv<<^>^v^^><<>>><>^<<><^vv^^<>vvv<>><^^v>^>vv<>v<<<<v<^v>^<^^>>>^<v<v
    \\><>vv>v^v^<>><>>>><^^>vv>v<^^^>>v^v^<^^>v^^>v^<^v>v<>>v^v^<v>v^^<^^vv<
    \\<<v<^>>^^^^>>>v^<>vvv^><v<<<>^^^vv^<vvv>^>v<^^^^v<>^>vvvv><>>v^<<^^^^^
    \\^><^><>>><>^^<<^^v>>><^<v>^<vv>>v>>>^v><>^v><<<<v>>v<v<v>vvv>^<><<>^><
    \\^>><>^v<><^vvv<^^<><v<<<<<><^v<<<><<<^^<v<^^^><^>>^<v^><<<^>>^v<v^v<v^
    \\>^>>^v>vv>^<<^v<>><<><<v<<v><>v<^vv<<<>^^v^>^^>>><<^v>>v^v><^^>>^<>vv^
    \\<><^^>^^^<><vvvvv^v<v<<>^v<v>v<<^><<><<><<<^^<<<^<<>><<><^^^>^^<>^>v<>
    \\^^>vv<^v^v<vv>^<><v<^v>^^^>>>^^vvv^>vvv<>>>^<^>>>>>^<<^v>^vvv<>^<><<v>
    \\v^^>>><<^^<>>^v^<v^vv<>v^<<>^<^v^v><^<<<><<^<v><v<>vv>>v><v^<vv<>v^<<^
;

test "p1 - large example" {
    var map, var moves = try parseMapAndMoves(std.testing.allocator, large_ex_input);
    defer map.deinit(std.testing.allocator);

    simulate(&map, &moves);

    const result = calculateSumOfGps(map);
    try std.testing.expectEqual(10092, result);
}

fn parseWideMapAndMoves(alloc: std.mem.Allocator, input: []const u8) !struct { Map, Moves } {
    const width = blk: {
        var w: u32 = 0;
        while (w < input.len and input[w] != '\n') : (w += 1) {}
        break :blk w;
    };

    var line_iter = std.mem.splitSequence(u8, input, "\n\n");
    const map_data = line_iter.next().?;

    const height: u32 = @intCast((map_data.len + 1) / (width + 1));
    var data: []u8 = try alloc.alloc(u8, 2 * width * height);

    var map_iter = std.mem.splitScalar(u8, map_data, '\n');
    var row_n: usize = 0;
    while (map_iter.next()) |line| {
        if (line.len == 0) break;

        for (line, 0..) |c, x| {
            const index = (row_n * width + x) * 2;
            switch (c) {
                '#', '.' => {
                    data[index + 0] = c;
                    data[index + 1] = c;
                },
                'O' => {
                    data[index + 0] = '[';
                    data[index + 1] = ']';
                },
                '@' => {
                    data[index + 0] = '@';
                    data[index + 1] = '.';
                },
                else => unreachable,
            }
        }

        row_n += 1;
    }

    var moves_data = line_iter.next().?;
    moves_data = std.mem.trim(u8, moves_data, "\n");

    return .{
        Map{
            .width = width * 2,
            .height = height,
            .data = data,
        },
        Moves{
            .input = moves_data,
            .index = 0,
        },
    };
}

fn moveAllBoxes(map: *Map, pos: Pos, move: Move, tiles_to_move: *[]struct { Pos, u8 }) bool {
    const this_tile = map.at(pos);
    switch (this_tile) {
        '.' => return true,
        '#' => return false,
        '[', ']' => {
            switch (move) {
                .right, .left => {
                    const next = pos.move(move);
                    if (moveAllBoxes(map, next, move, tiles_to_move)) {
                        tiles_to_move.len += 1;
                        tiles_to_move.*[tiles_to_move.len - 1] = .{ pos, this_tile };
                        return true;
                    }
                },
                .up, .down => {
                    const next = pos.move(move);
                    const side: Move, const side_tile: u8 = switch (this_tile) {
                        '[' => .{ .right, ']' },
                        ']' => .{ .left, '[' },
                        else => unreachable,
                    };
                    const side_pos = pos.move(side);
                    const side_next = side_pos.move(move);
                    if (moveAllBoxes(map, next, move, tiles_to_move) and
                        moveAllBoxes(map, side_next, move, tiles_to_move))
                    {
                        tiles_to_move.len += 1;
                        tiles_to_move.*[tiles_to_move.len - 1] = .{ pos, this_tile };
                        tiles_to_move.len += 1;
                        tiles_to_move.*[tiles_to_move.len - 1] = .{ side_pos, side_tile };
                        return true;
                    }
                },
            }
        },
        else => unreachable,
    }
    return false;
}

fn pushWideBox(map: *Map, robot_pos: Pos, box_pos: Pos, move: Move) Pos {
    // reserve stack space to keep a list of all tiles that need to be moved.
    var tiles_to_move_mem: [1000]struct { Pos, u8 } = undefined;
    var tiles_to_move: []struct { Pos, u8 } = &tiles_to_move_mem;
    tiles_to_move.len = 0;

    if (moveAllBoxes(map, box_pos, move, &tiles_to_move)) {
        // clear all tiles to be moved first
        for (0..tiles_to_move.len) |i| {
            const pos, _ = tiles_to_move[i];
            map.put(pos, '.');
        }
        // put the tiles to their new position
        for (0..tiles_to_move.len) |i| {
            const pos, const tile = tiles_to_move[i];
            map.put(pos.move(move), tile);
        }
        return box_pos;
    }
    return robot_pos;
}

fn simulateWithWideBoxes(map: *Map, moves: *Moves) void {
    var robot_pos = findRobotPos: {
        for (0..map.height) |y| {
            for (0..map.width) |x| {
                const p = Pos.from(x, y);
                if (map.at(p) == '@') {
                    map.put(p, '.');
                    break :findRobotPos p;
                }
            }
        }
        unreachable;
    };

    {
        std.debug.print("Initial state:\n", .{});
        map.put(robot_pos, '@');
        defer map.put(robot_pos, '.');
        map.print(std.io.getStdErr().writer());
        waitKey();
    }

    while (moves.next()) |move| {
        const next_pos: Pos = robot_pos.move(move);
        switch (map.at(next_pos)) {
            '.' => robot_pos = next_pos,
            '#' => {},
            '[', ']' => robot_pos = pushWideBox(map, robot_pos, next_pos, move),
            else => {},
        }

        if (false) {
            map.put(robot_pos, '@');
            defer map.put(robot_pos, '.');
            map.print(std.io.getStdErr().writer());
            //waitKey();
        }
    }

    {
        std.debug.print("Final state:\n", .{});
        map.put(robot_pos, '@');
        defer map.put(robot_pos, '.');
        map.print(std.io.getStdErr().writer());
        waitKey();
    }
}

fn calculateSumOfGpsWide(map: Map) usize {
    var result: usize = 0;
    for (0..map.height) |y| {
        for (0..map.width) |x| {
            if (map.at(Pos.from(x, y)) == '[') {
                result += y * 100 + x;
            }
        }
    }
    return result;
}

const p2_small_ex_input =
    \\#######
    \\#...#.#
    \\#.....#
    \\#..OO@#
    \\#..O..#
    \\#.....#
    \\#######
    \\
    \\<vv<<^^<<^^
;

test "p2 - small example" {
    var map, var moves = try parseWideMapAndMoves(std.testing.allocator, p2_small_ex_input);
    defer map.deinit(std.testing.allocator);

    simulateWithWideBoxes(&map, &moves);

    const result = calculateSumOfGpsWide(map);
    try std.testing.expectEqual(105 + 207 + 306, result);
}

test "p2 - large example" {
    var map, var moves = try parseWideMapAndMoves(std.testing.allocator, large_ex_input);
    defer map.deinit(std.testing.allocator);

    simulateWithWideBoxes(&map, &moves);

    const result = calculateSumOfGpsWide(map);
    try std.testing.expectEqual(9021, result);
}

const some_input =
    \\########
    \\#......#
    \\#....O.#
    \\#..O...#
    \\#.OOO..#
    \\#.@O.O.#
    \\#......#
    \\########
    \\
    \\>>v>^^^^^>>>^^^^<vv
;

test "p2 - testing" {
    var map, var moves = try parseWideMapAndMoves(std.testing.allocator, some_input);
    defer map.deinit(std.testing.allocator);
    try std.testing.expectEqual(
        210 + 306 + 404 + 406 + 408 + 506 + 510,
        calculateSumOfGpsWide(map),
    );

    simulateWithWideBoxes(&map, &moves);

    try std.testing.expectEqual(
        106 + 110 + 205 + 207 + 307 + 404 + 510,
        calculateSumOfGpsWide(map),
    );
}

const some_input_2 =
    \\########
    \\#...##.#
    \\#..OO..#
    \\#.@O...#
    \\#......#
    \\########
    \\
    \\>>v>^^^
;

test "p2 - testing 2" {
    var map, var moves = try parseWideMapAndMoves(std.testing.allocator, some_input_2);
    defer map.deinit(std.testing.allocator);
    try std.testing.expectEqual(
        206 + 208 + 306,
        calculateSumOfGpsWide(map),
    );

    simulateWithWideBoxes(&map, &moves);

    try std.testing.expectEqual(
        206 + 208 + 307,
        calculateSumOfGpsWide(map),
    );
}
