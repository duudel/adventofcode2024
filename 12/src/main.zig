const std = @import("std");

const puzzle_input = @embedFile("input.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const map = Map.init(puzzle_input);

    const total_price = try calculateTotalPrice(gpa.allocator(), map);
    std.debug.print("Total price is {}\n", .{total_price});

    const total_discounted_price = try calculateTotalDiscountedPrice(gpa.allocator(), map);
    std.debug.print("Total price with discount is {}\n", .{total_discounted_price});
}

const Pos = struct {
    x: i32,
    y: i32,
    fn move(self: Pos, dx: i32, dy: i32) Pos {
        return Pos{
            .x = self.x + dx,
            .y = self.y + dy,
        };
    }
    fn moveDir(self: Pos, dir: Dir) Pos {
        return switch (dir) {
            .up => self.move(0, -1),
            .right => self.move(1, 0),
            .down => self.move(0, 1),
            .left => self.move(-1, 0),
        };
    }
};

const Map = struct {
    width: u32,
    height: u32,
    data: []const u8,

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

    fn indexFromPos(self: Map, pos: Pos) usize {
        const pitch = self.width + 1;
        return @as(usize, @intCast(pos.y)) * pitch + @as(usize, @intCast(pos.x));
    }

    fn get(self: Map, pos: Pos) ?u8 {
        if (0 <= pos.x and pos.x < self.width and
            0 <= pos.y and pos.y < self.height)
        {
            return self.data[self.indexFromPos(pos)];
        }
        return null;
    }
};

const Visited = struct {
    width: u32,
    height: u32,
    data: std.bit_set.DynamicBitSet,

    fn init(alloc: std.mem.Allocator, w: u32, h: u32) !Visited {
        return Visited{
            .width = w,
            .height = h,
            .data = try std.bit_set.DynamicBitSet.initEmpty(alloc, w * h),
        };
    }

    fn deinit(self: *Visited) void {
        self.data.deinit();
    }

    fn indexFromPos(self: Visited, pos: Pos) usize {
        const pitch = self.width;
        return @as(usize, @intCast(pos.y)) * pitch + @as(usize, @intCast(pos.x));
    }

    fn set(self: *Visited, pos: Pos) void {
        self.data.set(self.indexFromPos(pos));
    }

    fn isSet(self: Visited, pos: Pos) bool {
        return self.data.isSet(self.indexFromPos(pos));
    }
};

const Price = u32;

const Measures = struct {
    area: u32,
    perimeter: u32,

    fn add(self: Measures, other: Measures) Measures {
        return .{
            .area = self.area + other.area,
            .perimeter = self.perimeter + other.perimeter,
        };
    }

    fn price(self: Measures) Price {
        return self.area * self.perimeter;
    }

    const zero: Measures = Measures{ .area = 0, .perimeter = 0 };
    const areaOne: Measures = Measures{ .area = 1, .perimeter = 0 };
    const perimeterOne: Measures = Measures{ .area = 0, .perimeter = 1 };
};

fn calculateRegionMeasures(map: Map, pos: Pos, expected_type: u8, visited: *Visited) Measures {
    const region_type = map.get(pos);
    if (region_type != expected_type) {
        return Measures.perimeterOne;
    }

    if (visited.isSet(pos)) return Measures.zero;
    visited.set(pos);

    const north = calculateRegionMeasures(map, pos.move(0, -1), expected_type, visited);
    const east = calculateRegionMeasures(map, pos.move(1, 0), expected_type, visited);
    const south = calculateRegionMeasures(map, pos.move(0, 1), expected_type, visited);
    const west = calculateRegionMeasures(map, pos.move(-1, 0), expected_type, visited);

    return north.add(east).add(south).add(west).add(Measures.areaOne);
}

fn calculateTotalPrice(alloc: std.mem.Allocator, map: Map) !Price {
    var visited = try Visited.init(alloc, map.width, map.height);
    defer visited.deinit();

    var result: Price = 0;

    var y: u32 = 0;
    while (y < map.height) : (y += 1) {
        var x: u32 = 0;
        while (x < map.width) : (x += 1) {
            const pos = Pos{ .x = @intCast(x), .y = @intCast(y) };
            const expected = map.get(pos).?;
            const measures = calculateRegionMeasures(map, pos, expected, &visited);
            result += measures.price();
        }
    }
    return result;
}

test "p1 - simple" {
    const input =
        \\AAAA
        \\BBCD
        \\BBCC
        \\EEEC
    ;
    const map = Map.init(input);
    const result = calculateTotalPrice(std.testing.allocator, map);
    try std.testing.expectEqual(4 * 10 + 4 * 8 + 4 * 10 + 1 * 4 + 3 * 8, result);
}

test "p1 - large" {
    const input =
        \\RRRRIICCFF
        \\RRRRIICCCF
        \\VVRRRCCFFF
        \\VVRCCCJFFF
        \\VVVVCJJCFE
        \\VVIVCCJJEE
        \\VVIIICJJEE
        \\MIIIIIJJEE
        \\MIIISIJEEE
        \\MMMISSJEEE
    ;
    const map = Map.init(input);
    const result = calculateTotalPrice(std.testing.allocator, map);
    try std.testing.expectEqual(1930, result);
}

// part 2

const Dir = enum {
    up,
    right,
    down,
    left,

    fn bit(self: Dir) u4 {
        return @as(u4, 1) << @intFromEnum(self);
    }

    const directions: [4]Dir = .{ .up, .right, .down, .left };
};

const Sides = struct {
    width: u32,
    height: u32,
    data: []u4,

    fn init(alloc: std.mem.Allocator, w: u32, h: u32) !Sides {
        const data = try alloc.alloc(u4, w * h);
        @memset(data, 0);
        return Sides{
            .width = w,
            .height = h,
            .data = data,
        };
    }

    fn deinit(self: Sides, alloc: std.mem.Allocator) void {
        alloc.free(self.data);
    }

    fn reset(self: *Sides) void {
        @memset(self.data, 0);
    }

    fn indexFromPos(self: Sides, pos: Pos) usize {
        const pitch = self.width;
        return @as(usize, @intCast(pos.y)) * pitch + @as(usize, @intCast(pos.x));
    }

    fn mark(self: *Sides, pos: Pos, dir: Dir) void {
        const index: usize = self.indexFromPos(pos);
        self.data[index] |= dir.bit();
    }

    fn at(self: Sides, x: i32, y: i32) u4 {
        const index = self.indexFromPos(Pos{ .x = x, .y = y });
        return @intCast(self.data[index]);
    }

    fn sideAt(self: Sides, pos: Pos, dir: Dir) bool {
        const index: usize = self.indexFromPos(pos);
        return self.data[index] & dir.bit() != 0;
    }
};

const Bounds = struct {
    min: Pos,
    max: Pos,

    fn add(self: *Bounds, pos: Pos) void {
        self.min.x = @min(pos.x, self.min.x);
        self.min.y = @min(pos.y, self.min.y);
        self.max.x = @max(pos.x, self.max.x);
        self.max.y = @max(pos.y, self.max.y);
    }

    fn init(pos: Pos) Bounds {
        return .{ .min = pos, .max = pos };
    }
};

fn markRegionSides(
    map: Map,
    pos: Pos,
    region_type: u8,
    sides: *Sides,
    visited: *Visited,
    bounds: *Bounds,
) u32 {
    if (visited.isSet(pos)) return 0;

    visited.set(pos);
    bounds.add(pos);

    var area: u32 = 1;
    for (Dir.directions) |dir| {
        const pos_at_dir = pos.moveDir(dir);
        const region_at_dir = map.get(pos_at_dir);
        if (region_at_dir != region_type) {
            sides.mark(pos, dir);
        } else {
            area += markRegionSides(map, pos_at_dir, region_type, sides, visited, bounds);
        }
    }
    return area;
}

fn numberOfSides(sides: Sides, bounds: Bounds) u32 {
    var result: u32 = 0;

    { // horizontal sides
        var sides_n: u32 = 0;
        var y: i32 = bounds.min.y;
        while (y <= bounds.max.y) : (y += 1) {
            var start_0 = false;
            var start_1 = false;
            var x: i32 = bounds.min.x;
            while (x <= bounds.max.x) : (x += 1) {
                const pos = Pos{ .x = x, .y = y };

                const up = sides.sideAt(pos, .up);
                if (up) start_0 = true;
                if (start_0 and !up) {
                    start_0 = false;
                    sides_n += 1;
                }

                const down = sides.sideAt(pos, .down);
                if (down) start_1 = true;
                if (start_1 and !down) {
                    start_1 = false;
                    sides_n += 1;
                }
            }

            if (start_0) sides_n += 1;
            if (start_1) sides_n += 1;
        }
        result += sides_n;
    }

    { // vertical sides
        var sides_n: u32 = 0;
        var x: i32 = bounds.min.x;
        while (x <= bounds.max.x) : (x += 1) {
            var start_0 = false;
            var start_1 = false;
            var y: i32 = bounds.min.y;
            while (y <= bounds.max.y) : (y += 1) {
                const pos = Pos{ .x = x, .y = y };

                const left = sides.sideAt(pos, .left);
                if (left) start_0 = true;
                if (start_0 and !left) {
                    start_0 = false;
                    sides_n += 1;
                }

                const right = sides.sideAt(pos, .right);
                if (right) start_1 = true;
                if (start_1 and !right) {
                    start_1 = false;
                    sides_n += 1;
                }
            }

            if (start_0) sides_n += 1;
            if (start_1) sides_n += 1;
        }
        result += sides_n;
    }

    return result;
}

fn calculateTotalDiscountedPrice(alloc: std.mem.Allocator, map: Map) !Price {
    var visited = try Visited.init(alloc, map.width, map.height);
    defer visited.deinit();
    var sides = try Sides.init(alloc, map.width, map.height);
    defer sides.deinit(alloc);

    var result: Price = 0;

    var y: u32 = 0;
    while (y < map.height) : (y += 1) {
        var x: u32 = 0;
        while (x < map.width) : (x += 1) {
            const pos = Pos{ .x = @intCast(x), .y = @intCast(y) };
            if (visited.isSet(pos)) continue;

            var bounds = Bounds.init(pos);
            const expected = map.get(pos).?;
            const area = markRegionSides(map, pos, expected, &sides, &visited, &bounds);
            result += area * numberOfSides(sides, bounds);
            sides.reset();
        }
    }
    return result;
}

test "p2 - simple" {
    const input =
        \\AAAA
        \\BBCD
        \\BBCC
        \\EEEC
    ;

    const map = Map.init(input);
    const result = calculateTotalDiscountedPrice(std.testing.allocator, map);
    try std.testing.expectEqual(80, result);
}

test "p2 - E" {
    const input =
        \\EEEEE
        \\EXXXX
        \\EEEEE
        \\EXXXX
        \\EEEEE
    ;
    const map = Map.init(input);
    const result = calculateTotalDiscountedPrice(std.testing.allocator, map);
    try std.testing.expectEqual(236, result);
}

test "p2 - AB" {
    const input =
        \\AAAAAA
        \\AAABBA
        \\AAABBA
        \\ABBAAA
        \\ABBAAA
        \\AAAAAA
    ;
    const map = Map.init(input);
    const result = calculateTotalDiscountedPrice(std.testing.allocator, map);
    try std.testing.expectEqual(368, result);
}

test "p2 - large" {
    const input =
        \\RRRRIICCFF
        \\RRRRIICCCF
        \\VVRRRCCFFF
        \\VVRCCCJFFF
        \\VVVVCJJCFE
        \\VVIVCCJJEE
        \\VVIIICJJEE
        \\MIIIIIJJEE
        \\MIIISIJEEE
        \\MMMISSJEEE
    ;
    const map = Map.init(input);
    const result = calculateTotalDiscountedPrice(std.testing.allocator, map);
    try std.testing.expectEqual(1206, result);
}
