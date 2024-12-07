const std = @import("std");

const puzzle_input = @embedFile("input.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const eqs = try Equations.parse(gpa.allocator(), puzzle_input);
    defer eqs.deinit();

    const result1 = calculateTotalCalibrationResult(eqs);
    std.debug.print("Total calibration result: {}\n", .{result1});

    const result2 = calculateTotalCalibrationResult2(eqs);
    std.debug.print("Total calibration result (with concat): {}\n", .{result2});
}

const Num = u64;

const Equation = struct {
    test_value: Num,
    operands: []const Num,

    pub fn format(
        value: Equation,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{}: ", .{value.test_value});
        for (value.operands) |op| {
            try writer.print("{} ", .{op});
        }
    }
};

const Equations = struct {
    eqs: std.ArrayList(Equation),
    operands_mem: []u64,

    const OpsAlloc = struct {
        memory: []Num,
        start: usize,
        end: usize,

        fn init(buffer: []Num) OpsAlloc {
            return .{
                .memory = buffer,
                .start = 0,
                .end = 0,
            };
        }

        fn append(self: *OpsAlloc, item: Num) void {
            self.memory[self.end] = item;
            self.end += 1;
        }

        fn get(self: *OpsAlloc) []Num {
            const result = self.memory[self.start..self.end];
            self.start = self.end;
            return result;
        }
    };

    fn parseEq(alloc: *OpsAlloc, line: []const u8) !Equation {
        var i: usize = 0;
        const test_val = _: {
            const begin = 0;
            while (i < line.len and line[i] != ':') : (i += 1) {}

            break :_ try std.fmt.parseInt(Num, line[begin..i], 10);
        };

        var iter = std.mem.tokenizeScalar(u8, line[i + 1 ..], ' ');
        while (iter.next()) |part| {
            const operand = try std.fmt.parseInt(Num, part, 10);
            alloc.append(operand);
        }

        const ops = alloc.get();

        return Equation{ .test_value = test_val, .operands = ops };
    }

    fn deinit(self: Equations) void {
        self.eqs.allocator.free(self.operands_mem);
        self.eqs.deinit();
    }

    fn print(self: Equations) void {
        for (self.eqs.items) |eq| {
            std.debug.print("{any}\n", .{eq});
        }
    }

    fn parse(alloc: std.mem.Allocator, input: []const u8) !Equations {
        var iter = std.mem.tokenizeScalar(u8, input, '\n');
        const line_num, const total_ops = ln: {
            var lnum: u32 = 0;
            var ops: u32 = 0;
            while (iter.next()) |line| {
                lnum += 1;
                ops += @intCast(std.mem.count(u8, line, " "));
            }
            break :ln .{ lnum, ops };
        };
        var eqs = try std.ArrayList(Equation).initCapacity(alloc, line_num);

        const ops_mem = try alloc.alloc(Num, total_ops);
        var ops_alloc = OpsAlloc.init(ops_mem);

        iter.reset();
        while (iter.next()) |line| {
            const eq = try parseEq(&ops_alloc, line);
            eqs.appendAssumeCapacity(eq);
        }

        return Equations{
            .eqs = eqs,
            .operands_mem = ops_mem,
        };
    }
};

fn findIfPossible(test_val: Num, result: Num, ops: []const Num) bool {
    if (ops.len == 0) {
        return test_val == result;
    }
    const operand = ops[0];
    const rest = ops[1..];
    return findIfPossible(test_val, result + operand, rest) or
        findIfPossible(test_val, result * operand, rest);
}

fn testEquation(eq: Equation) bool {
    return findIfPossible(eq.test_value, eq.operands[0], eq.operands[1..]);
}

fn calculateTotalCalibrationResult(eqs: Equations) Num {
    var result: Num = 0;
    for (eqs.eqs.items) |eq| {
        if (testEquation(eq)) result += eq.test_value;
    }
    return result;
}

test "example-1" {
    const input =
        \\190: 10 19
        \\3267: 81 40 27
        \\83: 17 5
        \\156: 15 6
        \\7290: 6 8 6 15
        \\161011: 16 10 13
        \\192: 17 8 14
        \\21037: 9 7 18 13
        \\292: 11 6 16 20
    ;
    const eqs = try Equations.parse(std.testing.allocator, input);
    defer eqs.deinit();

    //eqs.print();

    const result = calculateTotalCalibrationResult(eqs);
    try std.testing.expectEqual(3749, result);
}

fn concat(a: Num, b: Num) Num {
    if (b == 0) {
        return a * 10;
    }
    const n = std.math.log10(b);
    const mult = std.math.pow(Num, 10, n + 1);
    return a * mult + b;
}

fn findIfPossible2(test_val: Num, result: Num, ops: []const Num) bool {
    if (ops.len == 0) {
        return test_val == result;
    }
    const operand = ops[0];
    const rest = ops[1..];
    return findIfPossible2(test_val, result + operand, rest) or
        findIfPossible2(test_val, result * operand, rest) or
        findIfPossible2(test_val, concat(result, operand), rest);
}

fn testEquation2(eq: Equation) bool {
    return findIfPossible2(eq.test_value, eq.operands[0], eq.operands[1..]);
}

fn calculateTotalCalibrationResult2(eqs: Equations) Num {
    var result: Num = 0;
    for (eqs.eqs.items) |eq| {
        if (testEquation2(eq)) result += eq.test_value;
    }
    return result;
}

test "example-2" {
    const input =
        \\190: 10 19
        \\3267: 81 40 27
        \\83: 17 5
        \\156: 15 6
        \\7290: 6 8 6 15
        \\161011: 16 10 13
        \\192: 17 8 14
        \\21037: 9 7 18 13
        \\292: 11 6 16 20
    ;
    const eqs = try Equations.parse(std.testing.allocator, input);
    defer eqs.deinit();

    //eqs.print();

    const result = calculateTotalCalibrationResult2(eqs);
    try std.testing.expectEqual(11387, result);
}
