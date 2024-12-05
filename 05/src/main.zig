const std = @import("std");

const puzzle_input = @embedFile("input.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const rules = try PrintingRules.parse(gpa.allocator(), puzzle_input);
    defer rules.deinit();

    const result1 = rules.sumOfCorrectMiddlePageNumbers();
    std.debug.print("Result from correct updates: {}\n", .{result1});

    const result2 = rules.sumOfCorrectedMiddlePageNumbers();
    std.debug.print("Result from corrected updates: {}\n", .{result2});
}

const PageNumber = u32;

const PrintingRules = struct {
    ordering_rules: std.ArrayList(Rule),
    updates: std.ArrayList(PageNumbers),

    const Rule = struct { PageNumber, PageNumber };
    const PageNumbers = std.ArrayList(PageNumber);

    fn deinit(self: PrintingRules) void {
        self.ordering_rules.deinit();
        for (self.updates.items) |u| {
            const pn: PageNumbers = u;
            pn.deinit();
        }
        self.updates.deinit();
    }

    // quite ugly, I must say
    fn parse(alloc: std.mem.Allocator, input: []const u8) !PrintingRules {
        var rules = std.ArrayList(Rule).init(alloc);
        errdefer rules.deinit();

        var stream = std.io.fixedBufferStream(input);
        const reader = stream.reader();

        var buf: [1024]u8 = undefined;
        var fixed_bs = std.io.fixedBufferStream(&buf);
        while (true) {
            try reader.streamUntilDelimiter(fixed_bs.writer(), '\n', fixed_bs.buffer.len);

            const line: []const u8 = fixed_bs.getWritten();
            if (line.len == 0) break; //  \n\n

            var line_stream = std.io.fixedBufferStream(line);
            const begin1 = line_stream.pos;

            const line_reader = line_stream.reader();
            try line_reader.skipUntilDelimiterOrEof('|');

            const first = line[begin1 .. line_stream.pos - 1]; // skips |, so need to go back one
            //std.debug.print("Parse first: {s}", .{first});

            const page1 = try std.fmt.parseInt(PageNumber, first, 10);

            const begin2 = line_stream.pos;
            const second = line[begin2..];
            //std.debug.print(", second: {s}\n", .{second});
            const page2 = try std.fmt.parseInt(PageNumber, second, 10);

            try rules.append(Rule{ page1, page2 });

            fixed_bs.reset();
        }

        var updates = std.ArrayList(PageNumbers).init(alloc);
        errdefer updates.deinit();

        var eof = false;
        while (!eof) {
            fixed_bs.reset();
            reader.streamUntilDelimiter(fixed_bs.writer(), '\n', fixed_bs.buffer.len) catch |err| switch (err) {
                error.EndOfStream => eof = true,
                else => return err,
            };

            const line: []const u8 = fixed_bs.getWritten();
            if (line.len == 0) break; //  \n\n - end of input

            var update = PageNumbers.init(alloc);
            errdefer update.deinit();

            var line_stream = std.io.fixedBufferStream(line);
            while (true) {
                const begin = line_stream.pos;

                const line_reader = line_stream.reader();
                try line_reader.skipUntilDelimiterOrEof(',');

                if (line_stream.pos == begin) {
                    break;
                }

                const end = if (line_stream.pos == line.len) line.len else line_stream.pos - 1;
                const str = line[begin..end];
                //std.debug.print("str:{s}, ", .{str});
                const num = try std.fmt.parseInt(PageNumber, str, 10);

                try update.append(num);
            }

            try updates.append(update);
        }

        //std.debug.print("Rules: {any}\n", .{rules.items});
        //std.debug.print("Updates: ", .{});
        //for (updates.items) |update| {
        //    std.debug.print("{any},", .{update.items});
        //}
        //std.debug.print("\n", .{});

        return PrintingRules{
            .ordering_rules = rules,
            .updates = updates,
        };
    }

    fn isPageOrderingCorrect(self: PrintingRules, update: PageNumbers.Slice) bool {
        for (update[0 .. update.len - 1], 0..) |former_page, page_ix| {
            // find any latter page that has a rule that would put this page into wrong order
            const start = page_ix + 1;
            for (update[start..update.len]) |latter_page| {
                for (self.ordering_rules.items) |rule| {
                    const first: PageNumber, const second: PageNumber = rule;
                    //if (first == latter_page or second == former_page) {
                    //    std.debug.print("{}:{} -- {any}\n", .{ former_page, latter_page, rule });
                    //}
                    if (first == latter_page and second == former_page)
                        return false;
                }
            }
        }
        return true;
    }

    fn sumOfCorrectMiddlePageNumbers(self: PrintingRules) u32 {
        var result: u32 = 0;
        for (self.updates.items) |update| {
            if (self.isPageOrderingCorrect(update.items)) {
                const mid_index = update.items.len / 2;
                const middle_page = update.items[mid_index];
                //std.debug.print("update: {any}\n", .{update.items});
                //std.debug.print("middle_page: {}\n", .{middle_page});
                result += middle_page;
            }
        }
        return result;
    }

    fn findIncorrectPageIndex(self: PrintingRules, page: PageNumber, update: PageNumbers.Slice) ?usize {
        if (update.len == 0) return null;

        const rules = self.ordering_rules.items;
        for (update, 0..) |latter, latter_ix| {
            for (rules) |rule| {
                const first: PageNumber, const second: PageNumber = rule;
                if (first == latter and second == page) {
                    return latter_ix + 1;
                }
            }
        }
        return null;
    }

    fn fixPageOrdering(self: PrintingRules, update: PageNumbers.Slice) void {
        if (update.len <= 1) return;

        while (self.findIncorrectPageIndex(update[0], update[1..])) |latter_index| {
            //const first_page = update[0];
            const latter_page = update[latter_index];

            for (0..latter_index) |i| {
                update[latter_index - i] = update[latter_index - i - 1];
            }
            update[0] = latter_page;
            //update[1] = first_page;
        }
        fixPageOrdering(self, update[1..]);
    }

    fn sumOfCorrectedMiddlePageNumbers(self: PrintingRules) u32 {
        var result: u32 = 0;
        for (self.updates.items) |update| {
            if (self.isPageOrderingCorrect(update.items)) continue;

            self.fixPageOrdering(update.items);

            const mid_index = update.items.len / 2;
            const middle_page = update.items[mid_index];
            //std.debug.print("update: {any}\n", .{update.items});
            //std.debug.print("middle_page: {}\n", .{middle_page});
            result += middle_page;
        }
        return result;
    }
};

test "example-1" {
    const input =
        \\47|53
        \\97|13
        \\97|61
        \\97|47
        \\75|29
        \\61|13
        \\75|53
        \\29|13
        \\97|29
        \\53|29
        \\61|53
        \\97|53
        \\61|29
        \\47|13
        \\75|47
        \\97|75
        \\47|61
        \\75|61
        \\47|29
        \\75|13
        \\53|13
        \\
        \\75,47,61,53,29
        \\97,61,53,29,13
        \\75,29,13
        \\75,97,47,61,53
        \\61,13,29
        \\97,13,75,29,47
    ;
    const rules = try PrintingRules.parse(std.testing.allocator, input);
    defer rules.deinit();
    const result = rules.sumOfCorrectMiddlePageNumbers();
    try std.testing.expectEqual(143, result);
}

test "example-2" {
    const input =
        \\47|53
        \\97|13
        \\97|61
        \\97|47
        \\75|29
        \\61|13
        \\75|53
        \\29|13
        \\97|29
        \\53|29
        \\61|53
        \\97|53
        \\61|29
        \\47|13
        \\75|47
        \\97|75
        \\47|61
        \\75|61
        \\47|29
        \\75|13
        \\53|13
        \\
        \\75,47,61,53,29
        \\97,61,53,29,13
        \\75,29,13
        \\75,97,47,61,53
        \\61,13,29
        \\97,13,75,29,47
    ;
    const rules = try PrintingRules.parse(std.testing.allocator, input);
    defer rules.deinit();
    const result = rules.sumOfCorrectedMiddlePageNumbers();
    try std.testing.expectEqual(123, result);
}
