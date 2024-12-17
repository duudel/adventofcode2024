const std = @import("std");

const puzzle_input =
    \\Register A: 33940147
    \\Register B: 0
    \\Register C: 0
    \\
    \\Program: 2,4,1,5,7,5,1,6,4,2,5,5,0,3,3,0
;

pub fn main() !void {
    var computer = try Computer.parse(std.heap.page_allocator, puzzle_input);
    defer computer.deinit();

    const output_string = try computer.run();
    defer computer.free(output_string);

    std.debug.print("Part 1 output: {s}\n", .{output_string});

    std.debug.print("----\n", .{});
    disassemble(computer.program);

    // going through all possible register A values is too slow
    //const result_reg_a = solve(computer.program);
    //std.debug.print("Reg A = {}\n", .{result_reg_a});

    // solve by recursively generating possible values
    const result_reg_a = solveByGeneration();
    std.debug.print("Smallest register A value that reproduces program = {}\n", .{result_reg_a});
}

const Word = i32;

const Opcode = enum(u3) {
    adv = 0,
    bxl = 1,
    bst = 2,
    jnz = 3,
    bxc = 4,
    out = 5,
    bdv = 6,
    cdv = 7,
};

const Computer = struct {
    registers: struct { A: Word, B: Word, C: Word },
    program: []u3,
    alloc: std.mem.Allocator,

    fn outputToString(self: *Computer, output: []u3) ![]const u8 {
        const output_buffer: []u8 = try self.alloc.alloc(u8, output.len * 2 - 1);
        errdefer self.alloc.free(output_buffer);
        var stream = std.io.fixedBufferStream(output_buffer);
        const writer = stream.writer();
        for (output, 0..) |v, index| {
            if (index < output.len - 1) {
                try std.fmt.format(writer, "{},", .{v});
            } else {
                try std.fmt.format(writer, "{}", .{v});
            }
        }
        return stream.getWritten();
    }

    fn parse(alloc: std.mem.Allocator, input: []const u8) !Computer {
        var line_iter = std.mem.splitScalar(u8, input, '\n');
        const a = try std.fmt.parseInt(Word, line_iter.next().?["Register X: ".len..], 10);
        const b = try std.fmt.parseInt(Word, line_iter.next().?["Register X: ".len..], 10);
        const c = try std.fmt.parseInt(Word, line_iter.next().?["Register X: ".len..], 10);
        _ = line_iter.next();

        const program_string = line_iter.next().?["Program: ".len..];
        var iter = std.mem.splitScalar(u8, program_string, ',');

        var program = std.ArrayList(u3).init(alloc);

        while (iter.next()) |n| {
            const code = try std.fmt.parseInt(u3, n, 10);
            try program.append(code);
        }

        return Computer{
            .registers = .{ .A = a, .B = b, .C = c },
            .program = try program.toOwnedSlice(),
            .alloc = alloc,
        };
    }

    fn deinit(self: *Computer) void {
        self.alloc.free(self.program);
    }

    fn free(self: *Computer, output: []const u8) void {
        self.alloc.free(output);
    }

    fn combo(self: Computer, operand: u3) Word {
        return switch (operand) {
            0, 1, 2, 3 => operand,
            4 => self.registers.A,
            5 => self.registers.B,
            6 => self.registers.C,
            7 => unreachable,
        };
    }

    fn literal(operand: u3) Word {
        return operand;
    }

    fn run(self: *Computer) ![]const u8 {
        var output = std.ArrayList(u3).init(self.alloc);
        defer output.deinit();

        const program = self.program;
        var ip: u32 = 0;
        while (ip < program.len - 1) {
            const opcode: Opcode = @enumFromInt(program[ip]);
            const operand = program[ip + 1];
            ip += 2;
            switch (opcode) {
                .adv => {
                    const num = self.registers.A;
                    const denom = self.combo(operand);
                    self.registers.A = @divTrunc(num, std.math.pow(Word, 2, denom));
                },
                .bxl => {
                    self.registers.B = self.registers.B ^ literal(operand);
                },
                .bst => {
                    self.registers.B = self.combo(operand) & 0x7;
                },
                .jnz => {
                    if (self.registers.A == 0) break;
                    ip = @intCast(literal(operand));
                },
                .bxc => {
                    self.registers.B = self.registers.B ^ self.registers.C;
                },
                .out => {
                    const v: u3 = @intCast(self.combo(operand) & 0x7);
                    try output.append(v);
                },
                .bdv => {
                    const num = self.registers.A;
                    const denom = self.combo(operand);
                    self.registers.B = @divTrunc(num, std.math.pow(Word, 2, denom));
                },
                .cdv => {
                    const num = self.registers.A;
                    const denom = self.combo(operand);
                    self.registers.C = @divTrunc(num, std.math.pow(Word, 2, denom));
                },
            }
        }
        return self.outputToString(output.items);
    }

    fn reset(computer: *Computer, a: Word) void {
        computer.registers = .{ .A = a, .B = 0, .C = 0 };
    }
};

test "p1 - example" {
    const input =
        \\Register A: 729
        \\Register B: 0
        \\Register C: 0
        \\
        \\Program: 0,1,5,4,3,0
    ;
    var computer = try Computer.parse(std.testing.allocator, input);
    defer computer.deinit();
    const output_string = try computer.run();
    defer computer.free(output_string);
    try std.testing.expectEqualStrings("4,6,3,5,6,3,5,2,1,0", output_string);
}

fn findRegisterA(computer: *Computer) Word {
    const program_string = computer.outputToString(computer.program) catch unreachable;
    defer computer.free(program_string);

    var reg_a: Word = 0;
    while (reg_a < 200000) : (reg_a += 1) {
        if (reg_a & 0xfff == 0) std.debug.print("A: {}\n", .{reg_a});
        computer.reset(reg_a);
        const output_string = computer.run() catch continue;
        defer computer.free(output_string);
        if (std.mem.eql(u8, output_string, program_string)) {
            return reg_a;
        }
    }
    return 0;
}

test "p2 example - naïve" {
    const input =
        \\Register A: 2024
        \\Register B: 0
        \\Register C: 0
        \\
        \\Program: 0,3,5,4,3,0
    ;
    var computer = try Computer.parse(std.testing.allocator, input);
    defer computer.deinit();

    const reg_a = findRegisterA(&computer);

    try std.testing.expectEqual(117440, reg_a);
}

fn comboS(operand: u3) []const u8 {
    return switch (operand) {
        0 => "#0",
        1 => "#1",
        2 => "#2",
        3 => "#3",
        4 => "A",
        5 => "B",
        6 => "C",
        7 => unreachable,
    };
}

fn literalS(operand: u3) []const u8 {
    return switch (operand) {
        0 => "#0",
        1 => "#1",
        2 => "#2",
        3 => "#3",
        4 => "#4",
        5 => "#5",
        6 => "#6",
        7 => "#7",
    };
}

fn disassemble(program: []u3) void {
    std.debug.print("Program: ", .{});
    for (program) |c| {
        std.debug.print("{},", .{c});
    }
    std.debug.print("\n----\n", .{});

    var ip: u32 = 0;
    while (ip < program.len - 1) {
        const opcode: Opcode = @enumFromInt(program[ip]);
        const operand: u3 = program[ip + 1];
        ip += 2;

        const operand_str = switch (opcode) {
            .adv => comboS(operand),
            .bxl => literalS(operand),
            .bst => comboS(operand),
            .jnz => literalS(operand),
            .bxc => "C",
            .out => comboS(operand),
            .bdv => comboS(operand),
            .cdv => comboS(operand),
        };

        var comment_buf: [1024]u8 = .{0} ** 1024;
        const comment = switch (opcode) {
            .adv => std.fmt.bufPrint(&comment_buf, "A <- A / 2**{s}", .{operand_str}),
            .bxl => std.fmt.bufPrint(&comment_buf, "B <- B ^ {s}", .{operand_str}),
            .bst => std.fmt.bufPrint(&comment_buf, "B <- {s} & 0x7", .{operand_str}),
            .jnz => std.fmt.bufPrint(&comment_buf, "IP <- if (A == 0) IP else {s}", .{operand_str}),
            .bxc => std.fmt.bufPrint(&comment_buf, "B <- B ^ C", .{}),
            .out => std.fmt.bufPrint(&comment_buf, "out <- {s} & 0x7", .{operand_str}),
            .bdv => std.fmt.bufPrint(&comment_buf, "B <- A / 2**{s}", .{operand_str}),
            .cdv => std.fmt.bufPrint(&comment_buf, "C <- A / 2**{s}", .{operand_str}),
        } catch unreachable;

        std.debug.print("{s} {s}\t // {s}\n", .{ std.enums.tagName(Opcode, opcode).?, operand_str, comment });
    }
}

// Disassembly of the program
// --
// bst A	 // B <- A & 0x7
// bxl #5	 // B <- B ^ #5
// cdv B	 // C <- A / 2**B
// bxl #6	 // B <- B ^ #6
// bxc C	 // B <- B ^ C
// out B	 // out <- B & 0x7
// adv #3	 // A <- A / 2**#3
// jnz #0	 // IP <- if (A == 0) IP else #0
fn run_program(start_a: usize) usize {
    var output: usize = 0;

    var a = start_a;
    var b: usize = 0;
    var c: usize = 0;

    while (a > 0) {
        b = a & 7;
        b = b ^ 5;
        c = a >> @intCast(b);
        b = b ^ 6;
        b = b ^ c;
        const out: u3 = @intCast(b & 7);
        output = (output << 3) | out;
        a = a >> 3;
    }

    return output;
}

fn canProduceStartingN(comptime n: u3, a: usize) bool {
    // ..000..XXX
    // ...111.XXX
    // 222....XXX
    // .333...XXX
    // ......444X
    // .......555
    // ....666XXX
    // .....777XX
    return switch (a & 7) {
        0 => ((a >> 5) & 7) ^ 3 == n,
        1 => ((a >> 4) & 7) ^ 2 == n,
        2 => ((a >> 7) & 7) ^ 1 == n,
        3 => ((a >> 6) & 7) ^ 0 == n,
        4 => ((a >> 1) & 7) ^ 7 == n,
        //5 => ((a >> 0) & 7) ^ 6 == n,
        5 => 3 == n, // 101 ^ 110 = 011 == n
        6 => ((a >> 3) & 7) ^ 5 == n,
        7 => ((a >> 2) & 7) ^ 4 == n,
        else => unreachable,
    };
}

fn solve(target: []u3) usize {
    const target_int: usize = blk: {
        var res: usize = 0;
        for (target, 0..) |n, index| {
            res |= @as(usize, @intCast(n)) << @intCast((index * 3));
        }
        break :blk res;
    };
    std.debug.print("Target integer: {}\n", .{target_int});
    //var loops: usize = 0;
    var reg_a = (@as(usize, 1) << @intCast(target.len * 3 + 3));
    const max_reg_a = reg_a << 3;
    while (reg_a < max_reg_a) {
        if (false) {
            const result = run_program(reg_a);
            if (result == target_int) return reg_a;
        }

        //const prev_a = reg_a;

        //Program: 2,4,1,5,7,5,1,6,4,2,5,5,0,3,3,0
        reg_a += 1;
        while (!(
        //
            canProduceStartingN(2, reg_a) and
            canProduceStartingN(4, reg_a >> 3) and
            canProduceStartingN(1, reg_a >> 6) and
            canProduceStartingN(5, reg_a >> 9) and
            canProduceStartingN(7, reg_a >> 12) and
            canProduceStartingN(5, reg_a >> 15) and
            canProduceStartingN(1, reg_a >> 18) and
            canProduceStartingN(6, reg_a >> 21) and
            canProduceStartingN(4, reg_a >> 24) and
            canProduceStartingN(2, reg_a >> 27) and
            canProduceStartingN(5, reg_a >> 30) and
            canProduceStartingN(5, reg_a >> 33) and
            canProduceStartingN(0, reg_a >> 36) and
            canProduceStartingN(3, reg_a >> 39) and
            canProduceStartingN(3, reg_a >> 42) and
            canProduceStartingN(0, reg_a >> 45))) : (reg_a += 1)
        {}

        return reg_a;

        //std.debug.print("pot A = {}, prev {} diff {}\n", .{ reg_a, prev_a, reg_a - prev_a });

        //loops += 1;
        //if (loops & 0x1 == 0) std.debug.print("A={}\n", .{reg_a});

        //if (loops > 40) break;
    }
    return 0;
}

fn solveByGeneration() usize {
    // program in reversed order
    const target: [16]u3 = .{ 0, 3, 3, 0, 5, 5, 2, 4, 6, 1, 5, 7, 5, 1, 4, 2 };
    return generate(&target, 0).?;
}

fn isValid(reg_a: usize) bool {
    return canProduceStartingN(2, reg_a) and
        canProduceStartingN(4, reg_a >> 3) and
        canProduceStartingN(1, reg_a >> 6) and
        canProduceStartingN(5, reg_a >> 9) and
        canProduceStartingN(7, reg_a >> 12) and
        canProduceStartingN(5, reg_a >> 15) and
        canProduceStartingN(1, reg_a >> 18) and
        canProduceStartingN(6, reg_a >> 21) and
        canProduceStartingN(4, reg_a >> 24) and
        canProduceStartingN(2, reg_a >> 27) and
        canProduceStartingN(5, reg_a >> 30) and
        canProduceStartingN(5, reg_a >> 33) and
        canProduceStartingN(0, reg_a >> 36) and
        canProduceStartingN(3, reg_a >> 39) and
        canProduceStartingN(3, reg_a >> 42) and
        canProduceStartingN(0, reg_a >> 45);
}

fn generateBits(comptime target: u3, rest: []const u3, result: usize) ?usize {
    var n: usize = 0;
    while (n < 8) : (n += 1) {
        if (canProduceStartingN(target, result | n)) {
            //std.debug.print("{} can produce {}\n", .{ n, target });
            if (generate(rest, result | n)) |ok| {
                if (isValid(ok)) return ok;
            }
        }
    }
    return null;
}

fn generate(target: []const u3, result: usize) ?usize {
    if (target.len == 0) return result;
    const next = target[0];
    switch (next) {
        0 => return generateBits(0, target[1..], result << 3),
        1 => return generateBits(1, target[1..], result << 3),
        2 => return generateBits(2, target[1..], result << 3),
        3 => return generateBits(3, target[1..], result << 3),
        4 => return generateBits(4, target[1..], result << 3),
        5 => return generateBits(5, target[1..], result << 3),
        6 => return generateBits(6, target[1..], result << 3),
        7 => return generateBits(7, target[1..], result << 3),
    }
}
