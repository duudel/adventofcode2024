const std = @import("std");

const puzzle_input = @embedFile("input.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const map = try Map.parse(gpa.allocator(), puzzle_input);
    defer map.deinit(gpa.allocator());

    const result1 = try calculateAntinodes(gpa.allocator(), map);
    std.debug.print("Distinct antinodes: {}\n", .{result1});
    const result2 = try calculateAntinodesWithResonantHarmonics(gpa.allocator(), map);
    std.debug.print("Distinct antinodes w/ resonant harmonics: {}\n", .{result2});
}

const Pos = struct { i32, i32 };

const Antennas = struct {
    frequency: u8,
    positions: []const Pos,
};

const Map = struct {
    width: u32,
    height: u32,
    antenna_positions: []Pos,
    antennas: std.ArrayList(Antennas),

    fn deinit(self: Map, alloc: std.mem.Allocator) void {
        alloc.free(self.antenna_positions);
        self.antennas.deinit();
    }

    fn isInside(self: Map, pos: Pos) bool {
        return (0 <= pos[0] and pos[0] < self.width) and
            (0 <= pos[1] and pos[1] < self.height);
    }

    fn parse(alloc: std.mem.Allocator, input: []const u8) !Map {
        var width: u32 = 0;
        while (width < input.len and input[width] != '\n') : (width += 1) {}

        const height: u32 = @intCast((input.len + 1) / (width + 1));

        const PosFreq = struct { Pos, u8 };
        var as = std.ArrayList(PosFreq).init(alloc);
        defer as.deinit();

        var i: usize = 0;
        var x: i32 = 0;
        var y: i32 = 0;
        while (i < input.len) : (i += 1) {
            if (input[i] == '\n') {
                x = 0;
                y += 1;
                continue;
            }

            if (input[i] != '.') {
                const freq = input[i];
                try as.append(.{ Pos{ x, y }, freq });
            }

            x += 1;
        }

        const less_than = struct {
            pub fn less(_: void, a: PosFreq, b: PosFreq) bool {
                return a[1] < b[1];
            }
        }.less;

        // sort by frequency
        std.sort.insertion(PosFreq, as.items, {}, less_than);

        var antennas = std.ArrayList(Antennas).init(alloc);
        const antenna_positions: []Pos = try alloc.alloc(Pos, as.items.len);

        var prev_freq: ?u8 = null;
        var start_index: usize = 0;
        for (as.items, 0..) |antenna, index| {
            const pos, const freq = antenna;
            antenna_positions[index] = pos;

            if (prev_freq != null and prev_freq != freq) {
                try antennas.append(Antennas{
                    .frequency = prev_freq.?,
                    .positions = antenna_positions[start_index..index],
                });
                start_index = index;
            }

            prev_freq = freq;
        }
        if (prev_freq != null) {
            try antennas.append(Antennas{
                .frequency = prev_freq.?,
                .positions = antenna_positions[start_index..],
            });
        }

        //std.debug.print("Antennae:\n", .{});
        //for (antennas.items) |a| {
        //    std.debug.print(" - [{c}]: {any}\n", .{ a.frequency, a.positions });
        //}

        return Map{
            .width = width,
            .height = height,
            .antenna_positions = antenna_positions,
            .antennas = antennas,
        };
    }
};

fn antinodesFromPostions(a: Pos, b: Pos) struct { Pos, Pos } {
    const a_to_b_x: i32 = b[0] - a[0];
    const a_to_b_y: i32 = b[1] - a[1];

    const an1 = Pos{
        b[0] + a_to_b_x,
        b[1] + a_to_b_y,
    };
    const an2 = Pos{
        a[0] - a_to_b_x,
        a[1] - a_to_b_y,
    };

    return .{ an1, an2 };
}

fn calculateAntinodes(alloc: std.mem.Allocator, map: Map) !u32 {
    var antinode_set = std.AutoArrayHashMap(Pos, void).init(alloc);
    defer antinode_set.deinit();

    for (map.antennas.items) |antennas| {
        const positions = antennas.positions;
        for (positions[0 .. positions.len - 1], 0..) |pos_a, index_a| {
            for (positions[index_a + 1 ..]) |pos_b| {
                const antinode1, const antinode2 = antinodesFromPostions(pos_a, pos_b);
                try antinode_set.put(antinode1, {});
                try antinode_set.put(antinode2, {});
            }
        }
    }

    var result: u32 = 0;
    for (antinode_set.keys()) |antinode| {
        if (map.isInside(antinode)) result += 1;
    }

    return result;
}

test "example-1" {
    const input =
        \\............
        \\........0...
        \\.....0......
        \\.......0....
        \\....0.......
        \\......A.....
        \\............
        \\............
        \\........A...
        \\.........A..
        \\............
        \\............
    ;
    const map = try Map.parse(std.testing.allocator, input);
    defer map.deinit(std.testing.allocator);

    const result = try calculateAntinodes(std.testing.allocator, map);

    try std.testing.expectEqual(14, result);
}

const AntinodeSet = std.AutoArrayHashMap(Pos, void);

fn antinodesFromPostions2(map: Map, antinodes: *AntinodeSet, a: Pos, b: Pos) !void {
    const a_to_b_x: i32 = b[0] - a[0];
    const a_to_b_y: i32 = b[1] - a[1];

    var pos = a;
    while (map.isInside(pos)) {
        try antinodes.put(pos, {});

        pos = Pos{
            pos[0] - a_to_b_x,
            pos[1] - a_to_b_y,
        };
    }

    pos = b;
    while (map.isInside(pos)) {
        try antinodes.put(pos, {});

        pos = Pos{
            pos[0] + a_to_b_x,
            pos[1] + a_to_b_y,
        };
    }
}

fn calculateAntinodesWithResonantHarmonics(alloc: std.mem.Allocator, map: Map) !u32 {
    var antinode_set = std.AutoArrayHashMap(Pos, void).init(alloc);
    defer antinode_set.deinit();

    for (map.antennas.items) |antennas| {
        const positions = antennas.positions;
        for (positions[0 .. positions.len - 1], 0..) |pos_a, index_a| {
            for (positions[index_a + 1 ..]) |pos_b| {
                try antinodesFromPostions2(map, &antinode_set, pos_a, pos_b);
            }
        }
    }

    return @intCast(antinode_set.count());
}

test "example-2" {
    const input =
        \\............
        \\........0...
        \\.....0......
        \\.......0....
        \\....0.......
        \\......A.....
        \\............
        \\............
        \\........A...
        \\.........A..
        \\............
        \\............
    ;
    const map = try Map.parse(std.testing.allocator, input);
    defer map.deinit(std.testing.allocator);

    const result = try calculateAntinodesWithResonantHarmonics(std.testing.allocator, map);

    try std.testing.expectEqual(34, result);
}
