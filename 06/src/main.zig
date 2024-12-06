const std = @import("std");

const puzzle_input = @embedFile("input.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const map, const guard_pos = try Map.parse(gpa.allocator(), puzzle_input);
    defer map.deinit();

    const visited = predictGuardMovements(map, guard_pos);
    std.debug.print("Visited positions: {}\n", .{visited});

    map.clearMarkings(); // hacky

    const loops = try countObstructionsThatResultInLoop(map, guard_pos);
    std.debug.print("Obstructed positions causing loop: {}\n", .{loops});
}

const Pos = struct { u32, u32 };
const Dir = enum {
    up,
    right,
    down,
    left,

    fn bit(self: Dir) u4 {
        return @as(u4, 1) << @intFromEnum(self);
    }
};

const Map = struct {
    width: u32,
    height: u32,
    data: std.ArrayList(u8),

    fn init(alloc: std.mem.Allocator, w: u32, h: u32) !Map {
        const slice: []u8 = try alloc.alloc(u8, w * h);
        @memset(slice, '.');
        const data = std.ArrayList(u8).fromOwnedSlice(alloc, slice);
        return Map{
            .width = w,
            .height = h,
            .data = data,
        };
    }

    fn clear(self: Map) void {
        @memset(self.data.items, '.');
    }

    fn clearMarkings(self: Map) void {
        var i: usize = 0;
        while (i < self.data.items.len) : (i += 1) {
            if (self.data.items[i] == 'X') self.data.items[i] = '.';
        }
    }

    fn deinit(self: Map) void {
        self.data.deinit();
    }

    fn plot(self: Map, pos: Pos) void {
        const index = pos[1] * self.width + pos[0];
        self.data.items[index] = 'X';
    }

    fn plotDirection(self: Map, pos: Pos, dir: Dir) void {
        const index = pos[1] * self.width + pos[0];

        if (self.data.items[index] == '.') {
            self.data.items[index] = dir.bit();
        } else {
            self.data.items[index] |= dir.bit();
        }
    }

    fn nextMoveInsideMap(self: Map, pos: Pos, dir: Dir) bool {
        switch (dir) {
            .up => return pos[1] > 0,
            .right => return pos[0] < self.width - 1,
            .down => return pos[1] < self.height - 1,
            .left => return pos[0] > 0,
        }
    }

    fn get(self: Map, pos: Pos) u8 {
        const index = pos[1] * self.width + pos[0];
        return self.data.items[index];
    }

    fn put(self: Map, pos: Pos, tile: u8) void {
        const index = pos[1] * self.width + pos[0];
        self.data.items[index] = tile;
    }

    fn getTileAtDirection(self: Map, pos: Pos, dir: Dir) u8 {
        return self.get(move(pos, dir));
    }

    fn countVisitedPositions(self: Map) u32 {
        var result: u32 = 0;
        for (self.data.items) |ch| {
            if (ch == 'X') {
                result += 1;
            }
        }
        return result;
    }

    // return parsed map and initial guard position
    fn parse(alloc: std.mem.Allocator, input: []const u8) !struct { Map, Pos } {
        var width: u32 = 0;
        while (width < input.len and input[width] != '\n') : (width += 1) {}

        // len + 1 for potentially missing line-feed on last line.
        const height: u32 = @intCast((input.len + 1) / (width + 1));

        const size = width * height;
        var data: std.ArrayList(u8) = try std.ArrayList(u8).initCapacity(alloc, size);

        var guard_pos: ?Pos = null;
        var x: u32 = 0;
        var y: u32 = 0;
        for (input) |ch| {
            if (ch == '^') guard_pos = Pos{ x, y };
            if (ch != '\n') {
                data.appendAssumeCapacity(ch);
                x += 1;
            } else {
                x = 0;
                y += 1;
            }
        }

        return .{
            Map{
                .width = width,
                .height = height,
                .data = data,
            },
            guard_pos.?,
        };
    }

    fn print(self: Map) void {
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const tile = self.get(.{ @intCast(x), @intCast(y) });
                var ch = tile;
                if (tile < 16) {
                    ch = switch (tile) {
                        Dir.up.bit() => '^',
                        Dir.right.bit() => '>',
                        Dir.down.bit() => 'v',
                        Dir.left.bit() => '<',
                        else => '+',
                    };
                }
                std.debug.print("{c}", .{ch});
            }
            std.debug.print("\n", .{});
        }
    }

    fn printWithCursor(self: Map, cursor: Pos, visited: Map, print_buffer: []u8) void {
        var bs = std.io.fixedBufferStream(print_buffer);
        var writer = bs.writer();
        for (0..self.height) |y| {
            if (y + 20 < cursor[1]) continue;
            if (y == 0) {
                _ = writer.write("\x1b[100m") catch unreachable;
                writer.writeByteNTimes('_', self.width) catch unreachable;
                _ = writer.write("\x1b[0m\n") catch unreachable;
            }
            if (y > cursor[1] + 20) break;
            for (0..self.width) |x| {
                const xy_pos = Pos{ @intCast(x), @intCast(y) };
                const tile = self.get(xy_pos);
                var ch = tile;
                const vis = visited.get(xy_pos);
                if (vis < 16) ch = vis;
                if (ch < 16) {
                    ch = switch (ch) {
                        Dir.up.bit() => '^',
                        Dir.right.bit() => '>',
                        Dir.down.bit() => 'v',
                        Dir.left.bit() => '<',
                        else => '+',
                    };
                }
                if (cursor[0] == x and cursor[1] == y) {
                    writer.print("\x1b[41m{c}\x1b[0m", .{ch}) catch unreachable;
                } else {
                    _ = writer.write(&[1]u8{ch}) catch unreachable;
                }
            }
            _ = writer.write("\n") catch unreachable;
            if (y + 1 == self.height) {
                _ = writer.write("\x1b[100m") catch unreachable;
                writer.writeByteNTimes('_', self.width) catch unreachable;
                _ = writer.write("\x1b[0m\n") catch unreachable;
            }
        }
        _ = std.io.getStdErr().write(bs.getWritten()) catch unreachable;
    }
};

fn move(pos: Pos, dir: Dir) Pos {
    return switch (dir) {
        .up => .{ pos[0], pos[1] - 1 },
        .right => .{ pos[0] + 1, pos[1] },
        .down => .{ pos[0], pos[1] + 1 },
        .left => .{ pos[0] - 1, pos[1] },
    };
}

fn turnRight(dir: Dir) Dir {
    return switch (dir) {
        .up => .right,
        .right => .down,
        .down => .left,
        .left => .up,
    };
}

fn predictGuardMovements(map: Map, initial_guard_pos: Pos) u32 {
    var guard_dir = Dir.up;
    var guard_pos = initial_guard_pos;

    map.plot(guard_pos);
    while (map.nextMoveInsideMap(guard_pos, guard_dir)) {
        if (map.getTileAtDirection(guard_pos, guard_dir) == '#') {
            guard_dir = turnRight(guard_dir);
            continue;
        }
        guard_pos = move(guard_pos, guard_dir);
        map.plot(guard_pos);
    }

    return map.countVisitedPositions();
}

test "example-1" {
    const input =
        \\....#.....
        \\.........#
        \\..........
        \\..#.......
        \\.......#..
        \\..........
        \\.#..^.....
        \\........#.
        \\#.........
        \\......#...
    ;
    const map, const guard_pos = try Map.parse(std.testing.allocator, input);
    defer map.deinit();
    const result = predictGuardMovements(map, guard_pos);
    std.debug.print("--\n", .{});
    map.print();
    try std.testing.expectEqual(41, result);
}

fn tileHasDirection(tile: u8, dir: Dir) bool {
    return (tile < 16) and (tile & dir.bit()) != 0;
}

fn waitKey() void {
    var buffer: [1]u8 = undefined;
    _ = std.io.getStdIn().read(&buffer) catch unreachable;
}

fn isLoop(map: Map, initial_guard_pos: Pos, initial_guard_dir: Dir, visited: Map, print_buffer: []u8) bool {
    _ = print_buffer;

    const next_pos = move(initial_guard_pos, initial_guard_dir);
    const saved_tile = map.get(next_pos);

    if (saved_tile < 16) return false; // tile is already visited, cannot but obstacle here.
    if (saved_tile == '#') return false; // tile is already obstacle, cannot but obstacle here.

    defer map.put(next_pos, saved_tile);

    // put obstacle to the guard's next position
    map.put(next_pos, 'O');

    visited.clear();

    var guard_pos = initial_guard_pos;
    var guard_dir = initial_guard_dir;
    while (map.nextMoveInsideMap(guard_pos, guard_dir)) {
        const tile = map.getTileAtDirection(guard_pos, guard_dir);
        if (tile == '#' or tile == 'O') {
            guard_dir = turnRight(guard_dir);
            //visited.plotDirection(guard_pos, guard_dir);

            //map.printWithCursor(guard_pos, visited, print_buffer);
            //waitKey();
            continue;
        }

        guard_pos = move(guard_pos, guard_dir);

        if (tileHasDirection(map.get(guard_pos), guard_dir)) {
            return true;
        } else if (tileHasDirection(visited.get(guard_pos), guard_dir)) {
            //map.printWithCursor(guard_pos, visited, print_buffer);
            //waitKey();
            return true;
        }

        visited.plotDirection(guard_pos, guard_dir);
    }
    return false;
}

fn countObstructionsThatResultInLoop(map: Map, initial_guard_pos: Pos) !u32 {
    const visited = try Map.init(map.data.allocator, map.width, map.height);
    defer visited.deinit();
    const print_buffer = try map.data.allocator.alloc(u8, map.width * map.height * 2);
    defer map.data.allocator.free(print_buffer);

    var result: u32 = 0;
    var guard_pos = initial_guard_pos;
    var guard_dir = Dir.up;
    while (map.nextMoveInsideMap(guard_pos, guard_dir)) {
        map.plotDirection(guard_pos, guard_dir);

        if (map.getTileAtDirection(guard_pos, guard_dir) == '#') {
            guard_dir = turnRight(guard_dir);
            continue;
        } else if (isLoop(map, guard_pos, guard_dir, visited, print_buffer)) {
            result += 1;
        }

        guard_pos = move(guard_pos, guard_dir);
    }
    return result;
}

test "example-2" {
    const input =
        \\....#.....
        \\.........#
        \\..........
        \\..#.......
        \\.......#..
        \\..........
        \\.#..^.....
        \\........#.
        \\#.........
        \\......#...
    ;
    const map, const guard_pos = try Map.parse(std.testing.allocator, input);
    defer map.deinit();
    const result = try countObstructionsThatResultInLoop(map, guard_pos);
    std.debug.print("--\n", .{});
    map.print();
    try std.testing.expectEqual(6, result);
}
