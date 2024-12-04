const std = @import("std");

const puzzle_input = @embedFile("input.txt");

pub fn main() !void {
    const grid = Grid.fromInput(puzzle_input);

    const count1 = countXmas(grid);
    std.debug.print("Count of XMAS = {}\n", .{count1});

    const count2 = countX_Mas(grid);
    std.debug.print("Count of X-MAS = {}\n", .{count2});
}

const Grid = struct {
    data: []const u8,
    width: u32,
    height: u32,

    fn fromInput(input: []const u8) Grid {
        var width: u32 = 0;
        while (width < input.len and input[width] != '\n') : (width += 1) {}

        const height: u32 = @intCast((input.len + 1) / (width + 1));

        return Grid{
            .data = input,
            .width = width,
            .height = height,
        };
    }

    fn at(self: Grid, x: i32, y: i32) ?u8 {
        if (x < 0 or x >= self.width) return null;
        if (y < 0 or y >= self.height) return null;
        const index: usize = @as(u32, @intCast(y)) * (self.width + 1) + @as(u32, @intCast(x));
        return self.data[index];
    }
};

fn search(grid: Grid, initial_x: i32, initial_y: i32, dx: i2, dy: i2) u1 {
    const MAS = "MAS";
    var i: u8 = 0;
    var x = initial_x;
    var y = initial_y;
    while (i < MAS.len) : (i += 1) {
        x += dx;
        y += dy;

        if (MAS[i] != grid.at(x, y)) return 0;
    }
    return 1;
}

fn countXmas(grid: Grid) u32 {
    var result: u32 = 0;

    var y: i32 = 0;
    while (y < grid.height) : (y += 1) {
        var x: i32 = 0;
        while (x < grid.width) : (x += 1) {
            if (grid.at(x, y) == 'X') {
                result += search(grid, x, y, -1, 0);
                result += search(grid, x, y, -1, -1);
                result += search(grid, x, y, 0, -1);
                result += search(grid, x, y, 1, -1);
                result += search(grid, x, y, 1, 0);
                result += search(grid, x, y, 1, 1);
                result += search(grid, x, y, 0, 1);
                result += search(grid, x, y, -1, 1);
            }
        }
    }
    return result;
}

test "example-1" {
    const input =
        \\MMMSXXMASM
        \\MSAMXMSMSA
        \\AMXSXMAAMM
        \\MSAMASMSMX
        \\XMASAMXAMM
        \\XXAMMXXAMA
        \\SMSMSASXSS
        \\SAXAMASAAA
        \\MAMMMXMMMM
        \\MXMXAXMASX
    ;
    const grid = Grid.fromInput(input);
    const result = countXmas(grid);
    try std.testing.expectEqual(18, result);
}

fn searchX(grid: Grid, x: i32, y: i32) bool {
    const c00 = grid.at(x - 1, y - 1);
    const c10 = grid.at(x + 1, y - 1);
    const c01 = grid.at(x - 1, y + 1);
    const c11 = grid.at(x + 1, y + 1);

    const diag0 = (c00 == 'M' and c11 == 'S') or (c00 == 'S' and c11 == 'M');
    const diag1 = (c10 == 'M' and c01 == 'S') or (c10 == 'S' and c01 == 'M');

    return diag0 and diag1;
}

fn countX_Mas(grid: Grid) u32 {
    var result: u32 = 0;

    var y: i32 = 1;
    while (y < grid.height - 1) : (y += 1) {
        var x: i32 = 1;
        while (x < grid.width - 1) : (x += 1) {
            if (grid.at(x, y) != 'A') continue;

            if (searchX(grid, x, y)) result += 1;
        }
    }

    return result;
}

test "example-2" {
    const input =
        \\MMMSXXMASM
        \\MSAMXMSMSA
        \\AMXSXMAAMM
        \\MSAMASMSMX
        \\XMASAMXAMM
        \\XXAMMXXAMA
        \\SMSMSASXSS
        \\SAXAMASAAA
        \\MAMMMXMMMM
        \\MXMXAXMASX
    ;
    const grid = Grid.fromInput(input);
    const result = countX_Mas(grid);
    try std.testing.expectEqual(9, result);
}
