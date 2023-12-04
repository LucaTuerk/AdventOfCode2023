const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const ascii = @import("std").ascii;
const ArrayList = @import("std").ArrayList;
const input = @embedFile("input");

const Symbol = struct {
    value: u8,
    x: u32,
    y: u32,

    pub fn print(symbol: Symbol) void {
        std.debug.print("sym {c} at x: {d} y: {d}\n", .{ symbol.value, symbol.x, symbol.y });
    }
};

const Gear = struct {
    gear: Symbol,
    num_alpha: Number,
    num_beta: Number,

    pub fn ratio(gear: Gear) u32 {
        return gear.num_alpha.value * gear.num_beta.value;
    }
};

const Number = struct {
    value: u32,
    x_min: u32,
    x_max: u32,
    y: u32,

    pub fn print(number: Number) void {
        std.debug.print("num {d} at x: {d},{d} y: {d}\n", .{ number.value, number.x_min, number.x_max, number.y });
    }

    pub fn next_to(number: Number, _x: u32, _y: u32) bool {
        const x_min: u32 = if (number.x_min == 0) number.x_min else number.x_min - 1;
        const y_min: u32 = if (number.y == 0) number.y else number.y - 1;

        return _x >= x_min and _x <= number.x_max + 1 and _y >= y_min and _y <= number.y + 1;
    }
};

const AoCError = error{ NotImplementedError, NoSymbols, NoNumbers };

const Schematic = struct {
    numbers: ?[]Number,
    symbols: ?[]Symbol,
    allocator: Allocator,

    pub fn init(allocator: Allocator, schematic: []const u8) !Schematic {
        var res: Schematic = .{ .numbers = null, .symbols = null, .allocator = allocator };

        std.debug.print("\nParsing Schematic: \n{s}\n", .{schematic});
        res.numbers = try parse_nums(allocator, schematic);
        res.symbols = try parse_symbols(allocator, schematic);

        return res;
    }

    pub fn deinit(schematic: Schematic) void {
        if (schematic.numbers != null) schematic.allocator.free(schematic.numbers.?);
        if (schematic.symbols != null) schematic.allocator.free(schematic.symbols.?);
    }

    fn parse_nums(allocator: Allocator, schematic: []const u8) ![]Number {
        var lines = std.mem.tokenizeAny(u8, schematic, "\n\r");

        var list = ArrayList(Number).init(allocator);
        defer list.deinit();

        var min_x: u32 = 0;
        var curr: u32 = 0;
        var y: u32 = 0;
        while (lines.next()) |line| {
            var x: u32 = 0;
            for (line) |char| {
                if (ascii.isDigit(char)) {
                    if (curr == 0) {
                        min_x = x;
                    }
                    curr = 10 * curr + (char - '0');
                }
                if (!ascii.isDigit(char) or x == line.len - 1) {
                    if (curr != 0) {
                        const number: Number = .{ .value = curr, .x_min = min_x, .x_max = x - 1, .y = y };
                        try list.append(number);
                    }
                    curr = 0;
                    min_x = 0;
                }
                x += 1;
            }
            y += 1;
        }

        if (list.items.len == 0)
            return AoCError.NoNumbers;

        const arr: []Number = try allocator.alloc(Number, list.items.len);
        std.mem.copyForwards(Number, arr, list.items);

        return arr;
    }

    fn parse_symbols(allocator: Allocator, schematic: []const u8) ![]Symbol {
        var lines = std.mem.tokenizeAny(u8, schematic, "\n\r");

        var list = ArrayList(Symbol).init(allocator);
        defer list.deinit();

        var y: u32 = 0;
        while (lines.next()) |line| {
            var x: u32 = 0;
            for (line) |char| {
                if (!ascii.isDigit(char) and !(char == '.')) {
                    const curr: Symbol =
                        .{ .value = char, .x = x, .y = y };
                    try list.append(curr);
                }
                x += 1;
            }
            y += 1;
        }

        if (list.items.len == 0)
            return AoCError.NoSymbols;

        const arr: []Symbol = try allocator.alloc(Symbol, list.items.len);
        std.mem.copyForwards(Symbol, arr, list.items);

        return arr;
    }

    pub fn get_part_numbers(allocator: Allocator, schematic: Schematic) ![]u32 {
        if (schematic.numbers == null or schematic.symbols == null) {
            return try allocator.alloc(u32, 0);
        }

        var list = ArrayList(u32).init(allocator);
        defer list.deinit();

        for (schematic.numbers.?) |number| {
            var is_part_num: bool = false;
            for (schematic.symbols.?) |symbol| {
                is_part_num = is_part_num or Number.next_to(number, symbol.x, symbol.y);

                if (is_part_num) {
                    try list.append(number.value);
                    break;
                }
            }
        }

        const arr: []u32 = try allocator.alloc(u32, list.items.len);
        std.mem.copyForwards(u32, arr, list.items);

        return arr;
    }

    pub fn get_gears(allocator: Allocator, schematic: Schematic) ![]Gear {
        if (schematic.numbers == null or schematic.symbols == null) {
            return try allocator.alloc(Gear, 0);
        }

        var list = ArrayList(Gear).init(allocator);
        defer list.deinit();

        for (schematic.symbols.?) |symbol| {
            if (!(symbol.value == '*')) continue;

            var count: u32 = 0;
            var potential_alpha: Number = .{ .value = 0, .x_max = 0, .x_min = 0, .y = 0 };
            var potential_beta: Number = .{ .value = 0, .x_max = 0, .x_min = 0, .y = 0 };

            for (schematic.numbers.?) |number| {
                if (Number.next_to(number, symbol.x, symbol.y)) {
                    if (count == 0) potential_alpha = number;
                    if (count == 1) potential_beta = number;
                    count += 1;
                }
            }

            if (count == 2) {
                try list.append(.{ .gear = symbol, .num_alpha = potential_alpha, .num_beta = potential_beta });
            }
        }

        const arr: []Gear = try allocator.alloc(Gear, list.items.len);
        std.mem.copyForwards(Gear, arr, list.items);

        return arr;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const schematic = try Schematic.init(gpa.allocator(), input);
    defer Schematic.deinit(schematic);

    try task1(gpa.allocator(), schematic);
    try task2(gpa.allocator(), schematic);
}

pub fn task1(allocator: Allocator, schematic: Schematic) !void {
    const part_nums = try Schematic.get_part_numbers(allocator, schematic);
    defer allocator.free(part_nums);

    var sum: u32 = 0;
    for (part_nums) |part_num| {
        sum += part_num;
    }

    std.debug.print("TASK 1 : {d} \n", .{sum});
}

pub fn task2(allocator: Allocator, schematic: Schematic) !void {
    const gears = try Schematic.get_gears(allocator, schematic);
    defer allocator.free(gears);

    var sum: u32 = 0;
    for (gears) |gear| {
        sum += Gear.ratio(gear);
    }

    std.debug.print("TASK 2 : {d} \n", .{sum});
}

test "parse_test" {
    const testallocator = std.testing.allocator;
    const raw_schematic: []const u8 = "467..114..\n...*......\n..35..633.\n......#...\n617*......\n.....+.58.\n..592.....\n......755.\n...$.*....\n.664.598..\n";
    const expected_sum: u32 = 4361;

    const schematic = try Schematic.init(testallocator, raw_schematic);
    defer Schematic.deinit(schematic);

    std.debug.print("SYMBOLS:\n", .{});
    if (schematic.symbols != null) {
        for (schematic.symbols.?) |symbol| {
            Symbol.print(symbol);
        }
    }

    std.debug.print("NUMBERS:\n", .{});
    if (schematic.numbers != null) {
        for (schematic.numbers.?) |number| {
            Number.print(number);
        }
    }

    const part_nums = try Schematic.get_part_numbers(testallocator, schematic);
    defer testallocator.free(part_nums);

    std.debug.print("PART_NUMBERS:\n", .{});
    var sum: u32 = 0;
    for (part_nums) |part_num| {
        std.debug.print("{d}\n", .{part_num});
        sum += part_num;
    }

    const gears = try Schematic.get_gears(testallocator, schematic);
    defer testallocator.free(gears);

    std.debug.print("GEARS:\n", .{});
    var ratio_sum: u32 = 0;
    const expected_ratio_sum = 467835;
    for (gears) |gear| {
        Symbol.print(gear.gear);
        ratio_sum += Gear.ratio(gear);
    }

    if (expected_sum == sum) {
        std.debug.print("\nSUCCESS!\n\n", .{});
    } else {
        std.debug.print("\nFAILED!\n\n", .{});
    }

    if (expected_ratio_sum == ratio_sum) {
        std.debug.print("\nRATIO SUCCESS!\n\n", .{});
    } else {
        std.debug.print("\nRATIO FAILED!\n\n", .{});
    }
}
