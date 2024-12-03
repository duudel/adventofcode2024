const std = @import("std");

const puzzle_input = @embedFile("./input.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const reports = try Report.parseReports(gpa.allocator(), puzzle_input);
    defer Report.deinitReports(reports);

    const valid_num = count_valid_reports(reports);
    std.debug.print("valid reports = {}\n", .{valid_num});

    const valid_with_dampener_num = count_valid_reports2(reports);
    std.debug.print("valid reports (with dampener) = {}\n", .{valid_with_dampener_num});
}

const Report = struct {
    levels: std.ArrayList(u32),

    pub fn deinit(self: Report) void {
        self.levels.deinit();
    }

    pub fn isValid(self: Report) bool {
        const levs = self.levels;
        if (levs.items.len < 2) {
            std.debug.print("OH NO! {any}\n", .{levs.items});
            unreachable;
        }

        var a0: i32 = @intCast(levs.items[0]);
        var a1: i32 = @intCast(levs.items[1]);
        var diff = a0 - a1;
        const sign: bool = diff > 0;
        if (!(1 <= @abs(diff) and @abs(diff) <= 3)) return false;
        for (levs.items[2..]) |lev| {
            a0 = a1;
            a1 = @intCast(lev);
            diff = a0 - a1;

            const s = diff > 0;
            if (s != sign) return false;
            if (!(1 <= @abs(diff) and @abs(diff) <= 3)) return false;
        }
        return true;
    }

    pub fn isValidWithout(self: Report, removed_index: usize) bool {
        const levs = self.levels.items;

        var ai: usize = 0;
        var bi: usize = 1;
        var sign: i2 = 0;
        while (bi < levs.len) {
            if (ai == removed_index) {
                ai += 1;
            } else if (bi == removed_index) {
                bi += 1;
            }
            if (ai == bi) {
                bi += 1;
            }
            if (bi >= levs.len) break;

            const a = levs[ai];
            const b = levs[bi];
            const diff = @as(i32, @intCast(b)) - @as(i32, @intCast(a));
            if (@abs(diff) == 0 or @abs(diff) > 3) {
                return false;
            }
            if (sign == 0) {
                sign = if (diff < 0) -1 else 1;
            } else if (sign == -1 and diff > 0) {
                return false;
            } else if (sign == 1 and diff < 0) {
                return false;
            }

            ai += 1;
            bi += 1;
        }

        return true;
    }

    pub fn isValidWithDampener(self: Report) bool {
        const levs = self.levels.items;

        for (0..levs.len) |removed_index| {
            if (self.isValidWithout(removed_index)) {
                return true;
            }
        }

        return false;
    }

    pub fn parse(alloc: std.mem.Allocator, line: []const u8) !Report {
        var levs = std.ArrayList(u32).init(alloc);
        var i: usize = 0;
        while (i < line.len) {
            const begin = i;
            while (i < line.len and std.ascii.isDigit(line[i])) : (i += 1) {}
            const end = i;
            const n = try std.fmt.parseInt(u32, line[begin..end], 10);
            try levs.append(n);

            while (i < line.len and std.ascii.isWhitespace(line[i])) : (i += 1) {}
        }
        return Report{ .levels = levs };
    }

    pub fn deinitReports(reports: std.ArrayList(Report)) void {
        for (reports.items) |report| {
            report.deinit();
        }
        reports.deinit();
    }

    pub fn parseReports(alloc: std.mem.Allocator, input: []const u8) !std.ArrayList(Report) {
        var result = std.ArrayList(Report).init(alloc);
        errdefer Report.deinitReports(result);

        var i: usize = 0;
        while (i < input.len) {
            const line_begin = i;
            while (i < input.len and input[i] != '\n') : (i += 1) {}
            const line_end = i;

            if (line_begin == line_end) break;

            const line = input[line_begin..line_end];
            const report = try Report.parse(alloc, line);
            try result.append(report);

            if (i < input.len) {
                std.debug.assert(input[i] == '\n');
                i += 1;
            }
        }
        return result;
    }
};

fn count_valid_reports(reports: std.ArrayList(Report)) u32 {
    var num: u32 = 0;
    for (reports.items) |report| {
        const is_valid = report.isValid();
        num += if (is_valid) 1 else 0;

        //if (!is_valid)
        //    std.debug.print("{any} : {}\n", .{ report.levels.items, is_valid });
    }
    return num;
}

fn count_valid_reports2(reports: std.ArrayList(Report)) u32 {
    var num: u32 = 0;
    for (reports.items) |report| {
        const is_valid = report.isValidWithDampener();
        num += if (is_valid) 1 else 0;

        //if (!is_valid)
        //    std.debug.print("{any} : {}\n", .{ report.levels.items, is_valid });
    }
    return num;
}

test "example-1" {
    const input =
        \\7 6 4 2 1
        \\1 2 7 8 9
        \\9 7 6 2 1
        \\1 3 2 4 5
        \\8 6 4 4 1
        \\1 3 6 7 9
    ;
    const reports = try Report.parseReports(std.testing.allocator, input);
    defer Report.deinitReports(reports);
    const result = count_valid_reports(reports);
    try std.testing.expectEqual(2, result);
}

test "example-2" {
    const input =
        \\7 6 4 2 1
        \\1 2 7 8 9
        \\9 7 6 2 1
        \\1 3 2 4 5
        \\8 6 4 4 1
        \\1 3 6 7 9
    ;
    const reports = try Report.parseReports(std.testing.allocator, input);
    defer Report.deinitReports(reports);
    const result = count_valid_reports2(reports);
    try std.testing.expectEqual(4, result);
}
