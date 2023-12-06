const std = @import("std");
const input = @embedFile("input");
const test_input = @embedFile("test_input");
const ArrayList = @import("std").ArrayList;
const Allocator = std.mem.Allocator;

fn containsString(in: []const u8, str: []const u8) bool {
    if (str.len > in.len) return false;
    const max: usize = in.len - str.len;
    for (0..max) |i| {
        if (std.mem.eql(u8, in[i .. str.len + i], str)) {
            return true;
        }
    }
    return false;
}

const Range = struct {
    min: i64,
    max: i64,

    pub fn possibilities(self: *const Range) i64 {
        return self.max - self.min + 1;
    }
};

const Race = struct {
    time: i64,
    record: i64,

    pub fn get(self: *const Race, i: i64) i64 {
        return (self.time - i) * i;
    }

    pub fn get_win_range(self: *const Race) Range {
        var range: Range = .{ .min = -1, .max = -1 };
        for (0..@as(usize, @intCast(self.time)) + 1) |i| {
            const curr = self.get(@as(i64, @intCast(i)));
            if (curr > self.record) {
                range.min = @as(i64, @intCast(i));
                break;
            }
        }

        for (0..@as(usize, @intCast(self.time)) + 1) |j| {
            const i = self.time - @as(i64, @intCast(j));
            const curr = self.get(@as(i64, @intCast(i)));
            if (curr > self.record) {
                range.max = @as(i64, @intCast(i));
                break;
            }
        }
        return range;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var races = ArrayList(Race).init(gpa.allocator());
    defer races.deinit();

    var lines = std.mem.tokenizeAny(u8, input, "\n\r");

    while (lines.next()) |line| {
        if (containsString(line, "Time:")) {
            var times = std.mem.tokenizeAny(u8, line, "\n\r:\t ");
            while (times.next()) |time| {
                const int_opt = std.fmt.parseInt(i64, time, 10) catch null;
                if (int_opt != null) {
                    const race: Race = .{ .time = int_opt.?, .record = -1 };
                    try races.append(race);
                }
            }
        }
        if (containsString(line, "Distance:")) {
            var records = std.mem.tokenizeAny(u8, line, "\n\r:\t ");
            var i: usize = 0;
            while (records.next()) |record| {
                const int_opt = std.fmt.parseInt(i64, record, 10) catch null;
                if (int_opt != null) {
                    races.items[i].record = int_opt.?;
                    i += 1;
                }
            }
        }
    }

    var product: i64 = 1;
    for (races.items) |item| {
        const range = item.get_win_range();
        std.debug.print("{d} {d} -> {d}-{d}\n", .{ item.time, item.record, range.min, range.max });
        product *= range.possibilities();
    }

    std.debug.print("\nTask 1: {d}\n\n\n", .{product});

    lines = std.mem.tokenizeAny(u8, input, "\n\r");

    var task2race: Race = .{ .time = 0, .record = 0 };
    while (lines.next()) |line| {
        if (containsString(line, "Time:")) {
            var times = std.mem.tokenizeAny(u8, line, "\n\r:\t ");
            while (times.next()) |time| {
                const int_opt = std.fmt.parseInt(i64, time, 10) catch null;
                if (int_opt != null and int_opt.? != 0) {
                    task2race.time *= std.math.pow(i64, 10, @as(i64, @intCast(time.len)));
                    task2race.time += int_opt.?;
                }
            }
        }
        if (containsString(line, "Distance:")) {
            var records = std.mem.tokenizeAny(u8, line, "\n\r:\t ");
            while (records.next()) |record| {
                const int_opt = std.fmt.parseInt(i64, record, 10) catch null;
                if (int_opt != null and int_opt.? != 0) {
                    task2race.record *= std.math.pow(i64, 10, @as(i64, @intCast(record.len)));
                    task2race.record += int_opt.?;
                }
            }
        }
    }

    std.debug.print("{d} {d}", .{ task2race.time, task2race.record });
    const range = task2race.get_win_range();
    std.debug.print(" -> {d}-{d}\n", .{ range.min, range.max });
    std.debug.print("Task 2 : {d}\n", .{range.possibilities()});
}

test "simple test" {
    var list = std.ArrayList(i64).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i64, 42), list.pop());
}
