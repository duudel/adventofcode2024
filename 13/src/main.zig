const std = @import("std");

const puzzle_input = @embedFile("input.txt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var machines = try parse(gpa.allocator(), puzzle_input);
    defer machines.deinit();

    const fewest_tokens = calculateFewestTokens(machines.items);
    std.debug.print("Fewest tokens needed is {}\n", .{fewest_tokens});

    fixStartingPosition(machines.items);
    const fewest_tokens2 = calculateFewestTokens2(machines.items);
    std.debug.print("Fewest tokens needed is {}\n", .{fewest_tokens2});
}

const Button = struct { x: u32, y: u32 };
const Pos = struct { x: u64, y: u64 };

const ClawMachine = struct {
    A: Button,
    B: Button,
    prizePos: Pos,
};

fn parseButton(line: []const u8) !Button {
    const coords = line["Button A: ".len..];
    var it = std.mem.splitSequence(u8, coords, ", ");
    const X = it.next().?;
    const Y = it.next().?;

    const x = try std.fmt.parseInt(u32, X[2..], 10);
    const y = try std.fmt.parseInt(u32, Y[2..], 10);

    return Button{ .x = x, .y = y };
}

fn parsePrize(line: []const u8) !Pos {
    const coords = line["Prize: ".len..];
    var it = std.mem.splitSequence(u8, coords, ", ");
    const X = it.next().?;
    const Y = it.next().?;

    const x = try std.fmt.parseInt(u32, X[2..], 10);
    const y = try std.fmt.parseInt(u32, Y[2..], 10);

    return Pos{ .x = x, .y = y };
}

fn parse(alloc: std.mem.Allocator, input: []const u8) !std.ArrayList(ClawMachine) {
    var machines = std.ArrayList(ClawMachine).init(alloc);
    var iter = std.mem.splitScalar(u8, input, '\n');
    while (iter.next()) |line| {
        if (line.len < 2) continue;

        const A = try parseButton(line);
        const B = try parseButton(iter.next().?);
        const pos = try parsePrize(iter.next().?);

        try machines.append(ClawMachine{
            .A = A,
            .B = B,
            .prizePos = pos,
        });
    }
    return machines;
}

//
// a = number of button A presses
// b = number of button B presses
//
// (Ax, Ay) = claw movement from button A
// (Bx, By) = claw movement from button B
//
// (Px, Py) = prize coordinates
//
// a(Ax + Ay) + b(Bx + By) = Px + Py
// aAx + aAy + bBx + bBy = Px + Py
// (aAx + bBy) + (aAy + bBy) = Px + Py
// aAx + bBx = Px
// aAy + bBy = Py
//
// b = (Px - aAx) / Bx
// b = (Py - aAy) / By
//
// A mod B = 0
// A = n*B
//
// (Px - aAx) = n*Bx
// n = (Px - aAx) / Bx

fn solve(machine: ClawMachine) ?struct { u16, u16 } {
    const X = machine.prizePos.x;
    const Y = machine.prizePos.y;

    const A = machine.A;
    const B = machine.B;

    for (0..101) |a| {
        if (a * A.x > X) break;
        if (a * A.y > Y) break;

        const Dx = X - a * A.x;
        if (Dx % B.x == 0) {
            //std.debug.print("X: {} - {}*{} mod {} = 0\n", .{ X, a, A.x, B.x });

            const Dy = Y - a * A.y;
            if (Dy % B.y == 0) {
                std.debug.print("X: {} - {}*{} mod {} = 0\n", .{ X, a, A.x, B.x });
                std.debug.print("Y: {} - {}*{} mod {} = 0\n", .{ Y, a, A.y, B.y });

                const b = Dx / B.x;

                const Rx = a * A.x + b * B.x;
                const Ry = a * A.y + b * B.y;

                if (Rx != X) continue;
                if (Ry != Y) continue;

                std.debug.print(
                    "{} * ({}, {}) + {} * ({}, {}) = ({}, {}) : ({}, {})\n",
                    .{ a, A.x, A.y, b, B.x, B.y, Rx, Ry, X, Y },
                );

                std.debug.print("A={}, B={}\n", .{ a, b });

                return .{ @intCast(a), @intCast(b) };
            }
        }
    }

    return null;
}

fn calculateFewestTokens(machines: []const ClawMachine) u32 {
    var tokens: u32 = 0;
    for (machines, 0..) |m, index| {
        if (solve(m)) |res| {
            const t = res[0] * 3 + res[1] * 1;
            tokens += t;
            std.debug.print("Machine {}: {} tokens\n", .{ index, t });
        } else {
            std.debug.print("Machine {}: no solution\n", .{index});
        }
    }
    return tokens;
}

test "example-1" {
    const input =
        \\Button A: X+94, Y+34
        \\Button B: X+22, Y+67
        \\Prize: X=8400, Y=5400
        \\
        \\Button A: X+26, Y+66
        \\Button B: X+67, Y+21
        \\Prize: X=12748, Y=12176
        \\
        \\Button A: X+17, Y+86
        \\Button B: X+84, Y+37
        \\Prize: X=7870, Y=6450
        \\
        \\Button A: X+69, Y+23
        \\Button B: X+27, Y+71
        \\Prize: X=18641, Y=10279
    ;
    const machines = try parse(std.testing.allocator, input);
    defer machines.deinit();

    {
        const a, const b = solve(machines.items[0]).?;
        const tokens = a * 3 + b;

        try std.testing.expectEqual(280, tokens);
    }

    const total_tokens = calculateFewestTokens(machines.items);
    try std.testing.expectEqual(280 + 200, total_tokens);
}

fn fixStartingPosition(machines: []ClawMachine) void {
    for (0..machines.len) |i| {
        var m = &machines[i];
        m.prizePos.x += 10_000_000_000_000;
        m.prizePos.y += 10_000_000_000_000;
    }
}

fn solve2(machine: ClawMachine) ?struct { usize, usize } {
    const A = machine.A;
    const B = machine.B;
    const X: isize = @intCast(machine.prizePos.x);
    const Y: isize = @intCast(machine.prizePos.y);
    const Ax: isize = @intCast(A.x);
    const Ay: isize = @intCast(A.y);
    const Bx: isize = @intCast(B.x);
    const By: isize = @intCast(B.y);

    const axby = (Ax * By - Ay * Bx);
    const a1: isize = @divFloor(X * By, axby);
    const a2: isize = @divFloor(Y * Bx, axby);
    const a = a1 - a2;
    const b = std.math.divExact(isize, X - a * Ax, Bx) catch return null;

    //std.debug.print("a = {}, b = {}\n", .{ a, b });

    const Rx = a * A.x + b * B.x;
    const Ry = a * A.y + b * B.y;

    if (Rx != X) return null;
    if (Ry != Y) return null;

    if (a * Ax > X) return null;

    if (true) return .{ @intCast(a), @intCast(b) };
}

fn calculateFewestTokens2(machines: []const ClawMachine) usize {
    var tokens: usize = 0;
    for (machines, 0..) |m, index| {
        if (solve2(m)) |res| {
            const t = res[0] * 3 + res[1] * 1;
            tokens += t;
            std.debug.print("Machine {}: {} tokens\n", .{ index, t });
        } else {
            std.debug.print("Machine {}: no solution\n", .{index});
        }
    }
    return tokens;
}

test "example-2" {
    const input =
        \\Button A: X+94, Y+34
        \\Button B: X+22, Y+67
        \\Prize: X=8400, Y=5400
        \\
        \\Button A: X+26, Y+66
        \\Button B: X+67, Y+21
        \\Prize: X=12748, Y=12176
        \\
        \\Button A: X+17, Y+86
        \\Button B: X+84, Y+37
        \\Prize: X=7870, Y=6450
        \\
        \\Button A: X+69, Y+23
        \\Button B: X+27, Y+71
        \\Prize: X=18641, Y=10279
    ;
    var machines = try parse(std.testing.allocator, input);
    defer machines.deinit();
    fixStartingPosition(machines.items);

    const total_tokens = calculateFewestTokens2(machines.items);
    try std.testing.expectEqual(875318608908, total_tokens);
}
