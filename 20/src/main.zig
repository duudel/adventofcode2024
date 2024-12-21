const std = @import("std");

const puzzle_input = @embedFile("input.txt");

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    const map = Map.parse(puzzle_input);
    const total_cheats = try findWaysToCheat(alloc, map, 100);
    std.debug.print("Total ways to cheat with at least 100 ps = {}\n", .{total_cheats});

    const total_cheats2 = try findWaysToCheat2(alloc, map, 100);
    std.debug.print("Total ways to cheat with at least 100 ps with 20 steps = {}\n", .{total_cheats2});
}

const Pos = struct {
    x: u32,
    y: u32,

    fn move(self: Pos, dx: i32, dy: i32) Pos {
        const ix: i32 = @intCast(self.x);
        const iy: i32 = @intCast(self.y);
        const new_x: u32 = @intCast(ix + dx);
        const new_y: u32 = @intCast(iy + dy);
        return Pos{ .x = new_x, .y = new_y };
    }

    fn from(x: usize, y: usize) Pos {
        return Pos{ .x = @intCast(x), .y = @intCast(y) };
    }

    fn diff(a: Pos, b: Pos) u32 {
        const dx = @abs(@as(i32, @intCast(a.x)) - @as(i32, @intCast(b.x)));
        const dy = @abs(@as(i32, @intCast(a.y)) - @as(i32, @intCast(b.y)));
        return @intCast(dx + dy);
    }
};

const Map = struct {
    width: u32,
    height: u32,
    data: []const u8,

    fn parse(input: []const u8) Map {
        const width = blk: {
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

    fn indexAt(self: Map, pos: Pos) usize {
        return pos.y * (self.width + 1) + pos.x;
    }

    fn at(self: Map, pos: Pos) u8 {
        const index = self.indexAt(pos);
        return self.data[index];
    }

    fn findStartAndEnd(self: Map) struct { Pos, Pos } {
        var start: Pos = undefined;
        var end: Pos = undefined;
        var found: usize = 0;
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const pos = Pos.from(x, y);
                switch (self.at(pos)) {
                    'S' => {
                        start = pos;
                        found += 1;
                    },
                    'E' => {
                        end = pos;
                        found += 1;
                    },
                    else => {},
                }
                if (found == 2) break;
            }
            if (found == 2) break;
        }
        return .{ start, end };
    }

    fn move(self: Map, pos: Pos, dx: i32, dy: i32) ?Pos {
        const ix: i32 = @intCast(pos.x);
        const iy: i32 = @intCast(pos.y);
        const new_x: i32 = ix + dx;
        const new_y: i32 = iy + dy;
        if (0 <= new_x and new_x < @as(i32, @intCast(self.width))) {
            if (0 <= new_y and new_y < @as(i32, @intCast(self.height))) {
                return Pos{ .x = @intCast(new_x), .y = @intCast(new_y) };
            }
        }

        //if ((dx < 0 and pos.x > -dx) or (dx > 0 and @as(i32, @intCast(pos.x)) + dx < self.width)) {
        //    if ((dy < 0 and pos.y > -dy) or (dy > 0 and @as(i32, @intCast(pos.y)) + dy < self.height)) {
        //        return pos.move(dx, dy);
        //    }
        //}
        return null;
    }
};

const Visited = struct {
    width: u32,
    height: u32,
    data: []u32,

    fn init(alloc: std.mem.Allocator, w: u32, h: u32) !Visited {
        const data = try alloc.alloc(u32, w * h);
        @memset(data, std.math.maxInt(u32));
        return Visited{ .width = w, .height = h, .data = data };
    }

    fn deinit(self: *Visited, alloc: std.mem.Allocator) void {
        alloc.free(self.data);
    }

    fn clear(self: *Visited) void {
        @memset(self.data, std.math.maxInt(u32));
    }

    fn indexAt(self: Visited, pos: Pos) usize {
        return pos.y * self.width + pos.x;
    }

    fn at(self: Visited, pos: Pos) u32 {
        const index = self.indexAt(pos);
        return self.data[index];
    }

    fn set(self: Visited, pos: Pos, score: u32) bool {
        const index = self.indexAt(pos);
        if (score < self.data[index]) {
            self.data[index] = score;
            return true;
        }
        return false;
    }
};

fn findBestPath(map: Map, pos: Pos, end: Pos, score: u32, visited: *Visited) void {
    if (map.at(pos) == '#') return;
    if (!visited.set(pos, score)) return;

    if (std.meta.eql(pos, end)) return;

    findBestPath(map, pos.move(-1, 0), end, score + 1, visited);
    findBestPath(map, pos.move(1, 0), end, score + 1, visited);
    findBestPath(map, pos.move(0, -1), end, score + 1, visited);
    findBestPath(map, pos.move(0, 1), end, score + 1, visited);
}

const Cheat = struct { start: Pos, end: Pos };
const Cheats = std.AutoArrayHashMap(Cheat, u32);

fn testCheats(map: Map, pos: Pos, score: u32, cheat_steps: u32, cheat_start: Pos, visited: Visited, cheats: *Cheats) void {
    if (cheat_steps == 2) {
        if (map.at(pos) == '#') return;

        const best_score_at = visited.at(pos);
        if (score < best_score_at) {
            const cheat = Cheat{ .start = cheat_start, .end = pos };
            if (cheats.contains(cheat)) return;

            const cheat_save = best_score_at - score;
            cheats.put(cheat, cheat_save) catch unreachable;
            if (false) std.debug.print(
                "Cheat found at {},{}-{},{}; saves {} picoseconds\n",
                .{ cheat_start.x, cheat_start.y, pos.x, pos.y, best_score_at - score },
            );
        }
        return;
    }

    if (pos.x > 0)
        testCheats(map, pos.move(-1, 0), score + 1, cheat_steps + 1, cheat_start, visited, cheats);
    if (pos.x < map.width - 1)
        testCheats(map, pos.move(1, 0), score + 1, cheat_steps + 1, cheat_start, visited, cheats);
    if (pos.y > 0)
        testCheats(map, pos.move(0, -1), score + 1, cheat_steps + 1, cheat_start, visited, cheats);
    if (pos.y < map.height - 1)
        testCheats(map, pos.move(0, 1), score + 1, cheat_steps + 1, cheat_start, visited, cheats);
}

fn findCheats(map: Map, pos: Pos, end: Pos, score: u32, visited: Visited, cheats: *Cheats) void {
    if (map.at(pos) == '#') { // cheating !
        testCheats(map, pos, score, 1, pos, visited, cheats);
        return;
    }

    if (visited.at(pos) < score) { // going backwards
        return;
    }

    if (std.meta.eql(pos, end)) return;

    findCheats(map, pos.move(-1, 0), end, score + 1, visited, cheats);
    findCheats(map, pos.move(1, 0), end, score + 1, visited, cheats);
    findCheats(map, pos.move(0, -1), end, score + 1, visited, cheats);
    findCheats(map, pos.move(0, 1), end, score + 1, visited, cheats);
}

fn findWaysToCheat(alloc: std.mem.Allocator, map: Map, min_save: u32) !usize {
    const start, const end = map.findStartAndEnd();

    var visited = try Visited.init(alloc, map.width, map.height);
    defer visited.deinit(alloc);
    findBestPath(map, start, end, 0, &visited);

    var cheats = Cheats.init(alloc);
    defer cheats.deinit();
    findCheats(map, start, end, 0, visited, &cheats);

    var result: usize = 0;
    for (cheats.values()) |saved| {
        if (saved >= min_save) result += 1;
    }
    return result;
}

const example_input =
    \\###############
    \\#234#0..#.....#
    \\#1#.#.#.#.###.#
    \\#S#...#.#.#...#
    \\#######.#.#.###
    \\#######.#.#...#
    \\#######.#.###.#
    \\###..E#...#...#
    \\###.#######.###
    \\#...###...#...#
    \\#.#####.#.###.#
    \\#.#...#.#.#...#
    \\#.#.#.#.#.#.###
    \\#...#...#...###
    \\###############
;

test "p1 - example" {
    const map = Map.parse(example_input);
    try std.testing.expectEqual(15, map.width);

    const start, const end = map.findStartAndEnd();
    try std.testing.expectEqualDeep(Pos.from(1, 3), start);
    try std.testing.expectEqualDeep(Pos.from(5, 7), end);

    var visited = try Visited.init(std.testing.allocator, map.width, map.height);
    defer visited.deinit(std.testing.allocator);
    findBestPath(map, start, end, 0, &visited);

    try std.testing.expectEqual(84, visited.at(end));

    const total_cheats = try findWaysToCheat(std.testing.allocator, map, 1);
    try std.testing.expectEqual(44, total_cheats);
}

const CheatWithSteps = struct { start: Pos, end: Pos, steps: u32 };
const CheatsWithSteps = std.AutoArrayHashMap(CheatWithSteps, u32);
const CheatingContext = struct {
    visited: Visited,
    cheat_visited: Visited,
    cheats: Cheats,
    alloc: std.mem.Allocator,

    fn init(alloc: std.mem.Allocator, visited: Visited) !CheatingContext {
        const cheat_visited = try Visited.init(alloc, visited.width, visited.height);
        return CheatingContext{
            .visited = visited,
            .cheat_visited = cheat_visited,
            .cheats = Cheats.init(alloc),
            .alloc = alloc,
        };
    }

    fn deinit(self: *CheatingContext) void {
        self.cheats.deinit();
        self.cheat_visited.deinit(self.alloc);
    }

    fn startCheating(self: *CheatingContext) void {
        self.cheat_visited.clear();
    }

    fn add(self: *CheatingContext, cheat: Cheat, saved: u32) void {
        self.cheats.put(cheat, saved) catch unreachable;
    }
};

const max_cheat_steps: u32 = 20;

fn addCheat(ctx: *CheatingContext, map: Map, pos: Pos, score_: u32, cheat_start: Pos) void {
    if (map.at(pos) == '#') return;

    const steps = Pos.diff(cheat_start, pos);
    if (steps > max_cheat_steps) {
        return;
    }
    const score = score_ + steps;

    const best_score_at = ctx.visited.at(pos);

    //std.debug.print("score {} after {} cheat steps - original {}\n", .{ score, steps, best_score_at });

    if (score >= best_score_at) return;

    const cheat = Cheat{ .start = cheat_start, .end = pos };
    //if (ctx.cheats.contains(cheat)) return;

    const cheat_save = best_score_at - score;
    ctx.add(cheat, cheat_save);
    if (false) {
        std.debug.print(
            "Cheat found at ({},{})-({},{}); saves {} picoseconds\n",
            .{ cheat.start.x, cheat.start.y, cheat.end.x, cheat.end.y, cheat_save },
        );
        std.debug.print(
            "  original_score={}, new_score={} - cheat-len={}\n",
            .{ best_score_at, score, steps },
        );
    }
}

fn testCheats2(ctx: *CheatingContext, map: Map, prev_pos: Pos, pos: Pos, score: u32, cheat_start: Pos) void {
    _ = prev_pos;
    _ = pos;
    for (0..max_cheat_steps + 1) |uy| {
        for (0..max_cheat_steps + 1) |ux| {
            const len = uy + ux;
            if (len == 0) continue;
            //if (len > 2) break;

            const dx: i32 = @intCast(ux);
            const dy: i32 = @intCast(uy);
            //const steps: u32 = @intCast(len);

            const pos0 = map.move(cheat_start, -dx, dy);
            const pos1 = map.move(cheat_start, -dx, -dy);
            const pos2 = map.move(cheat_start, dx, -dy);
            const pos3 = map.move(cheat_start, dx, dy);

            //if (pos0) |p0| {
            //    const diff = Pos.diff(cheat_start, p0);
            //    std.debug.assert(steps == diff);
            //}

            if (pos0) |p0| addCheat(ctx, map, p0, score, cheat_start);
            if (pos1) |p1| addCheat(ctx, map, p1, score, cheat_start);
            if (pos2) |p2| addCheat(ctx, map, p2, score, cheat_start);
            if (pos3) |p3| addCheat(ctx, map, p3, score, cheat_start);
        }
    }
}

fn findCheats2(ctx: *CheatingContext, map: Map, prev_pos: Pos, pos: Pos, end: Pos, score: u32) void {
    if (map.at(pos) == '#') { // cheating !
        testCheats2(ctx, map, prev_pos, pos, score - 1, prev_pos);
        return;
    }

    if (ctx.visited.at(pos) < score) { // going backwards
        return;
    }

    if (std.meta.eql(pos, end)) return;

    findCheats2(ctx, map, pos, pos.move(-1, 0), end, score + 1);
    findCheats2(ctx, map, pos, pos.move(1, 0), end, score + 1);
    findCheats2(ctx, map, pos, pos.move(0, -1), end, score + 1);
    findCheats2(ctx, map, pos, pos.move(0, 1), end, score + 1);
}

fn findWaysToCheat2(alloc: std.mem.Allocator, map: Map, min_save: u32) !usize {
    const start, const end = map.findStartAndEnd();

    var visited = try Visited.init(alloc, map.width, map.height);
    defer visited.deinit(alloc);
    findBestPath(map, start, end, 0, &visited);

    var ctx = try CheatingContext.init(alloc, visited);
    defer ctx.deinit();
    findCheats2(&ctx, map, start, start, end, 0);

    var result: usize = 0;
    for (ctx.cheats.keys(), ctx.cheats.values()) |cheat, saved| {
        if (saved >= min_save) {
            result += 1;

            if (false) std.debug.print(
                "Cheat found at ({},{})-({},{}); saves {} picoseconds\n",
                .{ cheat.start.x, cheat.start.y, cheat.end.x, cheat.end.y, saved },
            );
        }
    }
    return result;
}

test "p2 - example" {
    const map = Map.parse(example_input);
    const result = try findWaysToCheat2(std.testing.allocator, map, 50);
    const expected = 32 + 31 + 29 + 39 + 25 + 23 + 20 + 19 + 12 + 14 + 12 + 22 + 4 + 3;
    try std.testing.expectEqual(expected, result);
}
