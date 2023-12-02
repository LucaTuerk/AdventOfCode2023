const std = @import("std");
const ascii = @import("std").ascii;

pub fn main() !void {
    var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const path = try std.fs.realpath("./src/input", &path_buffer);

    var file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var sum: i32 = 0;

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var first: i32 = -1;
        var last: i32 = -1;

        for (0.., line) |i, ch| {
            var out: u8 = 0;
            if (str_digit(line, i, &out)) {
                if (first == -1) {
                    first = out - 48;
                }
                last = out - 48;
            } else if (ascii.isDigit(ch)) {
                if (first == -1) {
                    first = ch - 48;
                }
                last = ch - 48;
            }
        }

        std.debug.print("{s} {d}\n", .{ line[0 .. line.len - 1], first * 10 + last });
        sum += first * 10 + last;
    }
    std.debug.print("{d}\n", .{sum});
}

pub fn str_digit(line: []u8, i: usize, out: *u8) bool {
    if (str_comp(line[i..], "zero")) {
        out.* = 48;
    }
    if (str_comp(line[i..], "one")) {
        out.* = 48 + 1;
    }
    if (str_comp(line[i..], "two")) {
        out.* = 48 + 2;
    }

    if (str_comp(line[i..], "three")) {
        out.* = 48 + 3;
    }

    if (str_comp(line[i..], "four")) {
        out.* = 48 + 4;
    }

    if (str_comp(line[i..], "five")) {
        out.* = 48 + 5;
    }

    if (str_comp(line[i..], "six")) {
        out.* = 48 + 6;
    }

    if (str_comp(line[i..], "seven")) {
        out.* = 48 + 7;
    }

    if (str_comp(line[i..], "eight")) {
        out.* = 48 + 8;
    }

    if (str_comp(line[i..], "nine")) {
        out.* = 48 + 9;
    }

    if (out.* == 0) {
        return false;
    }
    return true;
}

pub fn str_comp(str_a: []u8, str_b: []const u8) bool {
    return str_a.len >= str_b.len and std.mem.eql(u8, str_a[0..str_b.len], str_b);
}

pub fn min(a: usize, b: usize) usize {
    return if (a < b) a else b;
}
