const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const ascii = @import("std").ascii;
const ArrayList = @import("std").ArrayList;

const Symbol = struct {
    value: u8,
    x: u32,
    y: u32,

    pub fn print(symbol: Symbol) void {
        std.debug.print("sym {c} at x: {d} y: {d}\n", .{ symbol.value, symbol.x, symbol.y });
    }
};

const Number = struct { value: u32, x_min: u32, x_max: u32, y: u32 };

const AoCError = error{ NotImplementedError, NoSymbols, NoNumbers };

const Schematic = struct {
    width: u32,
    height: u32,
    numbers: ?[]Number,
    symbols: ?[]Symbol,
    allocator: Allocator,

    pub fn init(allocator: Allocator, schematic: []const u8) !Schematic {
        var res: Schematic = .{ .width = 0, .height = 0, .numbers = null, .symbols = null, .allocator = allocator };

        //res.numbers = try parse_nums(allocator, schematic);
        res.symbols = try parse_symbols(allocator, schematic);

        return res;
    }

    pub fn deinit(schematic: Schematic) void {
        if (schematic.numbers != null) schematic.allocator.free(schematic.numbers.?);
        if (schematic.symbols != null) schematic.allocator.free(schematic.symbols.?);
    }

    fn parse_nums(allocator: Allocator, schematic: []const u8) ![]Number {
        var lines = std.mem.tokenizeAny(u8, schematic, "\n\r");
        std.debug.print("{s}\n", .{schematic});

        _ = try allocator.alloc(void, 1);

        while (lines.next()) |line| {
            std.debug.print("{s}\n", .{line});
        }
        return AoCError.NotImplementedError;
    }

    fn parse_symbols(allocator: Allocator, schematic: []const u8) ![]Symbol {
        var lines = std.mem.tokenizeAny(u8, schematic, "\n\r");
        std.debug.print("{s}\n", .{schematic});

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
};

pub fn main() !void {}

test "parse_test" {
    const testallocator = std.testing.allocator;
    const raw_schematic: []const u8 = "467..114..\n...*......\n..35..633.\n......#...\n617*......\n.....+.58.\n..592.....\n......755.\n...$.*....\n.664.598..\n";

    const schematic = try Schematic.init(testallocator, raw_schematic);
    defer Schematic.deinit(schematic);

    std.debug.print("SYMBOLS:\n", .{});
    if (schematic.symbols != null) {
        for (schematic.symbols.?) |symbol| {
            Symbol.print(symbol);
        }
    }
}
