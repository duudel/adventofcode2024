const std = @import("std");

const puzzle_input = @embedFile("input.txt");

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    const patternsAndDesigns = try parse(alloc, puzzle_input);
    defer patternsAndDesigns.deinit();

    const possible = patternsThatArePossible(alloc, patternsAndDesigns);
    std.debug.print("Designs possible: {}\n", .{possible});

    const ways_possible = totalWaysPatternsPossible(alloc, patternsAndDesigns);
    std.debug.print("Total ways designs are possible: {}\n", .{ways_possible});
}

const Pattern = []const u8;
const Design = []const u8;

fn parsePatterns(alloc: std.mem.Allocator, input: []const u8) !std.ArrayList(Pattern) {
    var result = std.ArrayList(Pattern).init(alloc);
    errdefer result.deinit();

    var iter = std.mem.splitSequence(u8, input, ", ");
    while (iter.next()) |p| {
        try result.append(p);
    }

    return result;
}

fn parseDesigns(alloc: std.mem.Allocator, input: []const u8) !std.ArrayList(Design) {
    var result = std.ArrayList(Design).init(alloc);
    errdefer result.deinit();

    var iter = std.mem.splitScalar(u8, input, '\n');
    while (iter.next()) |d| {
        if (d.len == 0) continue;
        try result.append(d);
    }

    return result;
}

const PatternsAndDesigns = struct {
    patterns: std.ArrayList(Pattern),
    designs: std.ArrayList(Design),

    fn deinit(self: PatternsAndDesigns) void {
        self.patterns.deinit();
        self.designs.deinit();
    }
};

fn parse(alloc: std.mem.Allocator, input: []const u8) !PatternsAndDesigns {
    var iter = std.mem.splitSequence(u8, input, "\n\n");
    const pattern_input = iter.next().?;
    const design_input = iter.next().?;
    const patterns = try parsePatterns(alloc, pattern_input);
    const design = try parseDesigns(alloc, design_input);
    return PatternsAndDesigns{
        .patterns = patterns,
        .designs = design,
    };
}

const Memo = struct {
    hash: std.StringArrayHashMap(void),

    fn init(alloc: std.mem.Allocator) Memo {
        return Memo{ .hash = std.StringArrayHashMap(void).init(alloc) };
    }

    fn deinit(self: *Memo) void {
        self.hash.deinit();
    }

    fn put(self: *Memo, design: Design) void {
        self.hash.put(design, {}) catch unreachable;
    }

    fn has(self: Memo, design: Design) bool {
        return self.hash.contains(design);
    }
};

const Memos = struct {
    possible: Memo,
    impossible: Memo,

    fn init(alloc: std.mem.Allocator) Memos {
        return Memos{
            .possible = Memo.init(alloc),
            .impossible = Memo.init(alloc),
        };
    }

    fn deinit(self: *Memos) void {
        self.possible.deinit();
        self.impossible.deinit();
    }

    fn isPossible(self: Memos, design: Design) bool {
        return self.possible.has(design);
    }
    fn isImpossible(self: Memos, design: Design) bool {
        return self.impossible.has(design);
    }
};

fn isPossible(patterns: []const Pattern, design: Design, memo: *Memos) bool {
    if (design.len == 0) return true;
    if (memo.isPossible(design)) return true;
    if (memo.isImpossible(design)) return false;

    //std.debug.print("Is possible {s}?\n", .{design});
    for (patterns) |pat| {
        if (std.mem.startsWith(u8, design, pat)) {
            if (isPossible(patterns, design[pat.len..], memo)) {
                memo.possible.put(design);
                return true;
            }
        }
    }
    memo.impossible.put(design);
    return false;
}

fn patternsThatArePossible(alloc: std.mem.Allocator, input: PatternsAndDesigns) usize {
    var memos = Memos.init(alloc);
    defer memos.deinit();

    var result: usize = 0;
    for (input.designs.items, 0..) |design, index| {
        std.debug.print("Testing desgin {}: {s}\n", .{ index, design });
        if (isPossible(input.patterns.items, design, &memos)) result += 1;
    }
    return result;
}

const example_input =
    \\r, wr, b, g, bwu, rb, gb, br
    \\
    \\brwrr
    \\bggr
    \\gbbr
    \\rrbgbr
    \\ubwu
    \\bwurrg
    \\brgr
    \\bbrgwb
;
test "p1 - example" {
    const patternsAndDesigns = try parse(std.testing.allocator, example_input);
    defer patternsAndDesigns.deinit();
    const result = patternsThatArePossible(std.testing.allocator, patternsAndDesigns);
    try std.testing.expectEqual(6, result);
}

const CountingMemo = struct {
    hash: std.StringArrayHashMap(usize),

    fn init(alloc: std.mem.Allocator) CountingMemo {
        return CountingMemo{ .hash = std.StringArrayHashMap(usize).init(alloc) };
    }

    fn deinit(self: *CountingMemo) void {
        self.hash.deinit();
    }

    fn put(self: *CountingMemo, design: Design, n: usize) void {
        self.hash.put(design, n) catch unreachable;
    }

    fn get(self: CountingMemo, design: Design) ?usize {
        return self.hash.get(design);
    }
};

fn waysPossible(patterns: []const Pattern, design: Design, memo: *CountingMemo) usize {
    if (design.len == 0) return 1;
    if (memo.get(design)) |res| return res;

    var ways: usize = 0;
    for (patterns) |pat| {
        if (std.mem.startsWith(u8, design, pat)) {
            const w = waysPossible(patterns, design[pat.len..], memo);
            ways += w;
        }
    }
    memo.put(design, ways);
    return ways;
}

fn totalWaysPatternsPossible(alloc: std.mem.Allocator, input: PatternsAndDesigns) usize {
    var memo = CountingMemo.init(alloc);
    defer memo.deinit();

    var result: usize = 0;
    for (input.designs.items, 0..) |design, index| {
        std.debug.print("Testing desgin {}: {s}\n", .{ index, design });
        result += waysPossible(input.patterns.items, design, &memo);
    }
    return result;
}

test "p2 - example" {
    const patternsAndDesigns = try parse(std.testing.allocator, example_input);
    defer patternsAndDesigns.deinit();
    const result = totalWaysPatternsPossible(std.testing.allocator, patternsAndDesigns);
    try std.testing.expectEqual(16, result);
}
