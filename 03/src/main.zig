const std = @import("std");

const puzzle_input = @embedFile("./input.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const muls = try parse(gpa.allocator(), puzzle_input);
    defer gpa.allocator().free(muls);

    const sum = sum_of_products(muls);
    std.debug.print("sum of products is {}\n", .{sum});

    const muls2 = try parseWithConditions(gpa.allocator(), puzzle_input);
    defer gpa.allocator().free(muls2);

    const sum2 = sum_of_products(muls2);
    std.debug.print("sum of products (with conditions) is {}\n", .{sum2});
}

const Mul = struct { a: i32, b: i32 };

fn parse(alloc: std.mem.Allocator, input: []const u8) ![]const Mul {
    var results = std.ArrayList(Mul).init(alloc);

    var i: usize = 0;
    while (i + 6 < input.len) { // mul(,) = 6
        if (input[i] == 'm') {
            //if (i + 3 >= input.len) break;

            const mul_begin = i;
            if (!std.mem.eql(u8, "mul", input[mul_begin .. mul_begin + 3])) {
                i = mul_begin + 1;
                continue;
            }
            i += 3;

            //std.debug.print("{s}\n", .{input[mul_begin .. mul_begin + 8]});

            if (input[i] != '(') continue;
            i += 1;

            const a_begin = i;
            while (i < input.len and std.ascii.isDigit(input[i])) : (i += 1) {}
            if (i == a_begin) continue;
            if (i >= input.len) break;

            const a = try std.fmt.parseInt(i32, input[a_begin..i], 10);

            if (input[i] != ',') continue;
            i += 1;

            const b_begin = i;
            while (i < input.len and std.ascii.isDigit(input[i])) : (i += 1) {}
            if (i == b_begin) continue;
            if (i >= input.len) break;

            const b = try std.fmt.parseInt(i32, input[b_begin..i], 10);

            if (input[i] != ')') continue;
            i += 1;

            try results.append(Mul{ .a = a, .b = b });
        } else {
            i += 1;
        }
    }

    return results.toOwnedSlice();
}

fn sum_of_products(muls: []const Mul) i32 {
    var result: i32 = 0;
    for (muls) |m| {
        result += m.a * m.b;
    }
    return result;
}

test "example-1" {
    const input = "xmul(2,4)%&mul[3,7]!@^do_not_mul(5,5)+mul(32,64]then(mul(11,8)mul(8,5))";
    std.debug.print("{s}\n", .{input});

    const muls = try parse(std.testing.allocator, input);
    defer std.testing.allocator.free(muls);
    //std.debug.print("{any}\n", .{muls});

    const result = sum_of_products(muls);
    try std.testing.expectEqual(161, result);
}

fn parseWithConditions(alloc: std.mem.Allocator, input: []const u8) ![]const Mul {
    var results = std.ArrayList(Mul).init(alloc);

    var i: usize = 0;
    var enabled = true;
    while (i + 6 < input.len) { // mul(,) = 6
        if (input[i] == 'd') {
            if (std.mem.eql(u8, "do()", input[i .. i + 4])) {
                i += 4;
                enabled = true;
            } else if (i + 7 < input.len and std.mem.eql(u8, "don't()", input[i .. i + 7])) {
                i += "don't()".len;
                enabled = false;
            } else {
                i += 1;
            }
        } else if (enabled and input[i] == 'm') {
            //if (i + 3 >= input.len) break;

            const mul_begin = i;
            if (!std.mem.eql(u8, "mul", input[mul_begin .. mul_begin + 3])) {
                i = mul_begin + 1;
                continue;
            }
            i += 3;

            //std.debug.print("{s}\n", .{input[mul_begin .. mul_begin + 8]});

            if (input[i] != '(') continue;
            i += 1;

            const a_begin = i;
            while (i < input.len and std.ascii.isDigit(input[i])) : (i += 1) {}
            if (i == a_begin) continue;
            if (i >= input.len) break;

            const a = try std.fmt.parseInt(i32, input[a_begin..i], 10);

            if (input[i] != ',') continue;
            i += 1;

            const b_begin = i;
            while (i < input.len and std.ascii.isDigit(input[i])) : (i += 1) {}
            if (i == b_begin) continue;
            if (i >= input.len) break;

            const b = try std.fmt.parseInt(i32, input[b_begin..i], 10);

            if (input[i] != ')') continue;
            i += 1;

            try results.append(Mul{ .a = a, .b = b });
        } else {
            i += 1;
        }
    }

    return results.toOwnedSlice();
}

test "example-2" {
    const input = "xmul(2,4)&mul[3,7]!^don't()_mul(5,5)+mul(32,64](mul(11,8)undo()?mul(8,5))";
    std.debug.print("{s}\n", .{input});

    const muls = try parseWithConditions(std.testing.allocator, input);
    defer std.testing.allocator.free(muls);
    //std.debug.print("{any}\n", .{muls});

    const result = sum_of_products(muls);
    try std.testing.expectEqual(48, result);
}
