const std = @import("std");

const puzzle_input = @embedFile("input.txt");

pub fn main() !void {
    const checksum = calculateChecksum(puzzle_input);
    std.debug.print("Checksum: {}\n", .{checksum});

    const checksum2 = try calculateChecksum2(std.heap.page_allocator, puzzle_input);
    std.debug.print("Checksum 2: {}\n", .{checksum2});
}

fn calculateChecksum(initial_input: []const u8) usize {
    var result: usize = 0;

    const input = std.mem.trim(u8, initial_input, " \n");

    var i: usize = 0; // forward index
    var bi: usize = input.len - 1; // backward index

    var block_id: usize = 0;
    var block_id_back: usize = input.len / 2 + 1;

    //std.debug.print("id={}, back_id={}\n", .{ block_id, block_id_back });

    var block_i: usize = 0; // block index
    var block_value_back: u8 = 0;

    while (i < input.len and i != (bi + 1)) : (i += 1) {
        //std.debug.print("i={}, bi={} id={}->{}\n", .{ i, bi, block_id, block_id_back });
        const fv = input[i] - '0';
        if ((i & 1) == 0) {
            // fileblock

            //std.debug.print("file {} x {}\n", .{ block_id, fv });
            const block_i_end = block_i + fv;
            while (block_i < block_i_end) : (block_i += 1) {
                result += block_id * block_i;
                //std.debug.print("+ {} * {}\n", .{ block_id, block_i });
            }
            block_id += 1;
        } else {
            // free space - fill with file blocks from back

            var gap = fv;
            while (gap > 0) {
                while (gap > 0 and block_value_back > 0) : (block_i += 1) {
                    result += block_id_back * block_i;
                    //std.debug.print(":+ {} * {}\n", .{ block_id_back, block_i });
                    gap -= 1;
                    block_value_back -= 1;
                }
                if (block_value_back == 0) {
                    block_value_back = input[bi] - '0';
                    bi -= 2;
                    block_id_back -= 1;
                }
            }
        }
    }
    while (block_value_back > 0) : (block_i += 1) {
        result += block_id_back * block_i;
        //std.debug.print(":+ {} * {}\n", .{ block_id_back, block_i });
        block_value_back -= 1;
    }

    return result;
}

test "simple-1" {
    const input = "12345";
    const result = calculateChecksum(input);
    const expected: usize =
        0 * 0 + 1 * 2 + 2 * 2 + 3 * 1 + 4 * 1 + 5 * 1 + 6 * 2 + 7 * 2 + 8 * 2;
    try std.testing.expectEqual(expected, result);
}

test "example-1" {
    const input = "2333133121414131402";
    const result = calculateChecksum(input);
    try std.testing.expectEqual(1928, result);
}

fn calculateChecksum2(alloc: std.mem.Allocator, input0: []const u8) !usize {
    const input = std.mem.trim(u8, input0, " \n");

    const Block = struct {
        id: usize,
        size: u8,
        trailing_free: u32,
    };

    const List = std.DoublyLinkedList(Block);
    var itemsList = List{};

    var items: []List.Node = try alloc.alloc(List.Node, (input.len + 1) / 2);
    defer alloc.free(items);

    { // initialize items
        var i: usize = 0;
        while (i < input.len) : (i += 2) {
            const id = i / 2;
            const size = input[i] - '0';
            const free = if (i + 1 < input.len) input[i + 1] - '0' else 0;
            items[id] = List.Node{ .data = Block{
                .id = id,
                .size = size,
                .trailing_free = free,
            } };
            itemsList.append(&items[id]);
        }
    }

    var it = itemsList.last;
    while (it != itemsList.first) {
        const item_node = it.?;
        const item = item_node.data;

        var found_it: ?*List.Node = null;
        var search_it = itemsList.first;
        while (search_it != it) : (search_it = search_it.?.next) {
            const s_it = search_it.?;
            if (s_it.data.trailing_free >= item.size) {
                found_it = s_it;
                break;
            }
        }

        if (found_it) |found| {
            const it_prev = item_node.prev;
            it_prev.?.data.trailing_free += item.size + item.trailing_free;

            itemsList.remove(item_node);
            itemsList.insertAfter(found, item_node);

            item_node.data.trailing_free = found.data.trailing_free - item.size;
            found.data.trailing_free = 0;

            it = it_prev;
        } else {
            it = it.?.prev;
        }
    }

    var result: usize = 0;
    var index: usize = 0;

    it = itemsList.first;
    while (it != null) : (it = it.?.next) {
        const block = it.?.data;

        var i: u8 = 0;
        while (i < block.size) : (i += 1) {
            result += block.id * index;
            index += 1;
        }
        index += block.trailing_free;
    }

    return result;
}

test "example-2" {
    const input = "2333133121414131402";
    const result = calculateChecksum2(std.testing.allocator, input);
    try std.testing.expectEqual(2858, result);
}
