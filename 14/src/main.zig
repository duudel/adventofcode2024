const std = @import("std");

const puzzle_input: []const u8 = @embedFile("input.txt");

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    const robots = try parse(alloc, puzzle_input);
    defer robots.deinit();

    const map_size = Size{ .x = 101, .y = 103 };
    const result = calculateSafetyFactor(map_size, robots.items, 100);
    std.debug.print("Result = {}\n", .{result});

    _ = try findChristmasTree(alloc, map_size, robots.items);
}

const Time = u64;
const Coord = u32;
const ICoord = i64;
const Pos = struct { x: Coord, y: Coord };
const VelCoord = i16;
const Vel = struct { x: i16, y: i16 };

const Size = struct { x: u16, y: u16 };

fn applyTimeStep(map_size: Size, pos: Pos, vel: Vel, time: Time) Pos {
    const vx: ICoord = @intCast(vel.x);
    const vy: ICoord = @intCast(vel.y);
    const x: ICoord = pos.x + vx * @as(i64, @intCast(time));
    const y: ICoord = pos.y + vy * @as(i64, @intCast(time));
    return Pos{
        .x = @intCast(@mod(x, map_size.x)),
        .y = @intCast(@mod(y, map_size.y)),
    };
}

const Robot = struct { pos: Pos, vel: Vel };

fn parseTwoInts(comptime T: type, input: []const u8) !struct { T, T } {
    var it = std.mem.splitScalar(u8, input, ',');
    const as = it.next().?;
    const bs = it.next().?;
    //std.debug.print("{s}, {s}\n", .{ as, bs });
    const a = try std.fmt.parseInt(T, as, 10);
    const b = try std.fmt.parseInt(T, bs, 10);
    return .{ a, b };
}

fn parse(alloc: std.mem.Allocator, input: []const u8) !std.ArrayList(Robot) {
    var result = std.ArrayList(Robot).init(alloc);
    var iter = std.mem.splitScalar(u8, input, '\n');
    while (iter.next()) |line| {
        if (line.len < 2) break;

        var it = std.mem.splitScalar(u8, line, ' ');
        //std.debug.print("line: {s}\n", .{line});
        const pos0 = it.next() orelse break;
        const vel0 = it.next() orelse break;

        //std.debug.print("pos = {s}, vel = {s}\n", .{ pos0, vel0 });

        const pos = try parseTwoInts(Coord, pos0[2..]);
        const vel = try parseTwoInts(VelCoord, vel0[2..]);

        try result.append(Robot{
            .pos = Pos{ .x = pos[0], .y = pos[1] },
            .vel = Vel{ .x = vel[0], .y = vel[1] },
        });
    }
    return result;
}

fn calculateSafetyFactor(map_size: Size, robots: []const Robot, time: Time) usize {
    var quadrants: [4]usize = .{0} ** 4;
    for (robots) |robot| {
        const pos = applyTimeStep(map_size, robot.pos, robot.vel, time);
        if (pos.x == map_size.x / 2) continue;
        if (pos.y == map_size.y / 2) continue;
        const bx = pos.x > map_size.x / 2;
        const by = pos.y > map_size.y / 2;
        const i = @as(u4, @intFromBool(bx)) | (@as(u4, @intFromBool(by)) << 1);
        quadrants[i] += 1;
    }
    return quadrants[0] * quadrants[1] * quadrants[2] * quadrants[3];
}

test "example-1" {
    const input =
        \\p=0,4 v=3,-3
        \\p=6,3 v=-1,-3
        \\p=10,3 v=-1,2
        \\p=2,0 v=2,-1
        \\p=0,0 v=1,3
        \\p=3,0 v=-2,-2
        \\p=7,6 v=-1,-3
        \\p=3,0 v=-1,-2
        \\p=9,3 v=2,3
        \\p=7,3 v=-1,2
        \\p=2,4 v=2,-3
        \\p=9,5 v=-3,-3
    ;
    const robots = try parse(std.testing.allocator, input);
    defer robots.deinit();

    const result = calculateSafetyFactor(.{ .x = 11, .y = 7 }, robots.items, 100);

    try std.testing.expectEqual(12, result);
}

fn printMap(map_size: Size, robots: []const Robot) void {
    for (0..map_size.y) |y| {
        for (0..map_size.x) |x| {
            const pos = Pos{ .x = @intCast(x), .y = @intCast(y) };
            var was_robot = false;
            for (robots) |ro| {
                if (ro.pos.x == pos.x and ro.pos.y == pos.y) {
                    was_robot = true;
                    break;
                }
            }
            if (was_robot) {
                _ = std.io.getStdErr().write("\x1b[42mX\x1b[0m") catch unreachable;
            } else {
                _ = std.io.getStdErr().write(".") catch unreachable;
            }
        }
        _ = std.io.getStdErr().write("\n") catch unreachable;
    }
}

fn waitKey() void {
    var buff: [1]u8 = undefined;
    _ = std.io.getStdIn().read(&buff) catch unreachable;
}

fn diff(a: Coord, b: Coord) u32 {
    if (a > b) return a - b;
    return b - a;
}

fn getSymX(x: Coord, sym_ax: usize) Coord {
    const ix = @as(ICoord, @intCast(x));
    const sx = @as(ICoord, @intCast(sym_ax));
    const delta: ICoord = sx - ix;
    return @intCast(@mod(ix + delta + delta, 101));
}

const Map = struct {
    size: Size,
    data: std.bit_set.DynamicBitSet,

    fn init(alloc: std.mem.Allocator, size: Size) !Map {
        return Map{
            .size = size,
            .data = try std.bit_set.DynamicBitSet.initEmpty(alloc, size.x * size.y),
        };
    }
    fn deinit(self: *Map) void {
        self.data.deinit();
    }

    fn clear(self: *Map) void {
        const range = std.bit_set.Range{ .start = 0, .end = self.size.x * self.size.y };
        self.data.setRangeValue(range, false);
    }

    fn set(self: *Map, pos: Pos) void {
        const index: usize = self.size.x * pos.y + pos.x;
        self.data.set(index);
    }

    fn isSet(self: Map, pos: Pos) bool {
        const index: usize = self.size.x * pos.y + pos.x;
        return self.data.isSet(index);
    }
};

fn isSymmetric(map: *Map, robots: []const Robot) bool {
    map.clear();
    for (robots) |robot| {
        map.set(robot.pos);
    }

    // guess: picture is at least 17 tiles wide, thus the symmetry axis cannot
    // be at position < 8 tiles or > (size - 8) tiles
    for (8..map.size.x - 8) |sym_ax| {
        var non_symmetric: usize = 0;
        for (robots) |robot| {
            const sym_x = getSymX(robot.pos.x, sym_ax);
            if (!map.isSet(Pos{ .x = sym_x, .y = robot.pos.y })) {
                non_symmetric += 1;
            }
        }
        if (non_symmetric < 350) {
            return true;
        }
    }

    return false;
}

fn findChristmasTree(alloc: std.mem.Allocator, map_size: Size, robots: []Robot) !Time {
    var map = try Map.init(alloc, map_size);
    defer map.deinit();

    var time: Time = 0;
    while (time < map_size.x * map_size.y) {
        for (robots) |*robot| {
            robot.pos = applyTimeStep(map_size, robot.pos, robot.vel, 1);
        }
        time += 1;

        if (isSymmetric(&map, robots)) {
            printMap(map_size, robots);
            std.debug.print("Time: {}\n", .{time});
            waitKey();
        }
    }
    return 0;
}
