const std = @import("std");

const puzzle_input = @embedFile("input.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const parse_res = try parseInput(gpa.allocator(), puzzle_input);
    defer parse_res.free();
    const difference = calculate_difference(parse_res);
    const similarity = calculate_similarity_score(parse_res);

    std.debug.print("Difference = {}\n", .{difference});
    std.debug.print("Similarity = {}\n", .{similarity});
}

const ParseResult = struct {
    as: std.ArrayList(i32),
    bs: std.ArrayList(i32),

    pub fn free(self: ParseResult) void {
        self.as.deinit();
        self.bs.deinit();
    }
};

fn parseInput(alloc: std.mem.Allocator, input: []const u8) !ParseResult {
    var result = ParseResult{
        .as = std.ArrayList(i32).init(alloc),
        .bs = std.ArrayList(i32).init(alloc),
    };
    errdefer result.free();

    var i: u32 = 0;
    while (i < input.len) {
        {
            const start_i = i;
            while (i < input.len and std.ascii.isDigit(input[i])) : (i += 1) {}
            const end_i = i;

            const a = try std.fmt.parseInt(i32, input[start_i..end_i], 10);
            try result.as.append(a);
        }
        while (i < input.len and std.ascii.isWhitespace(input[i])) : (i += 1) {}
        {
            const start_i = i;
            while (i < input.len and std.ascii.isDigit(input[i])) : (i += 1) {}
            const end_i = i;

            const b = try std.fmt.parseInt(i32, input[start_i..end_i], 10);
            try result.bs.append(b);
        }
        while (i < input.len and std.ascii.isWhitespace(input[i])) : (i += 1) {}
    }
    return result;
}

fn calculate_difference(res: ParseResult) u32 {
    std.sort.insertion(i32, res.as.items, {}, std.sort.asc(i32));
    std.sort.insertion(i32, res.bs.items, {}, std.sort.asc(i32));
    var result: u32 = 0;
    for (res.as.items, res.bs.items) |a, b| {
        const diff = @abs(a - b);
        result += diff;
    }
    return result;
}

test "example-1" {
    const input =
        \\3   4
        \\4   3
        \\2   5
        \\1   3
        \\3   9
        \\3   3
    ;
    const parse_res = try parseInput(std.testing.allocator, input);
    defer parse_res.free();
    try std.testing.expectEqualSlices(i32, &.{ 3, 4, 2, 1, 3, 3 }, parse_res.as.items);
    try std.testing.expectEqualSlices(i32, &.{ 4, 3, 5, 3, 9, 3 }, parse_res.bs.items);
    const result = calculate_difference(parse_res);
    try std.testing.expectEqual(11, result);
}

fn calculate_similarity_score(res: ParseResult) u32 {
    var total: u32 = 0;
    for (res.as.items) |a| {
        var n: u32 = 0;
        for (res.bs.items) |b| {
            if (a == b) n += 1;
        }
        total += n * @as(u32, @intCast(a));
    }
    return total;
}

test "example-2" {
    const input =
        \\3   4
        \\4   3
        \\2   5
        \\1   3
        \\3   9
        \\3   3
    ;
    const parse_res = try parseInput(std.testing.allocator, input);
    defer parse_res.free();
    const result = calculate_similarity_score(parse_res);
    try std.testing.expectEqual(31, result);
}
