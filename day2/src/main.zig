const std = @import("std");
const ArrayList = @import("std").ArrayList;
const Allocator = std.mem.Allocator;

const ParseError = error{InvalidFormat};

const CubeSet = struct {
    red: u32,
    green: u32,
    blue: u32,

    fn print(set: CubeSet) void {
        std.debug.print("red: {d}, green: {d}, blue: {d}\n", .{ set.red, set.green, set.blue });
    }
};

const Game = struct {
    id: u32,
    sets: []CubeSet,
    allocator: Allocator,

    fn init(allocator: Allocator, set_count: usize) !Game {
        const sets = try allocator.alloc(CubeSet, set_count);
        errdefer allocator.free(sets);

        return .{ .id = 0, .sets = sets, .allocator = allocator };
    }

    fn deinit(game: Game) void {
        const allocator = game.allocator;
        allocator.free(game.sets);
    }

    fn print(game: Game) void {
        std.debug.print("id: {d}\n", .{game.id});

        for (0..game.sets.len) |i| {
            CubeSet.print(game.sets[i]);
        }
    }

    fn is_possible_with(game: Game, red: u32, green: u32, blue: u32) bool {
        var res: bool = true;
        for (game.sets) |set| {
            const set_possible =
                set.red <= red and set.green <= green and set.blue <= blue;
            res = res and set_possible;
        }
        return res;
    }

    fn power_of_fewest(game: Game) u32 {
        var max_red: u32 = 0;
        var max_green: u32 = 0;
        var max_blue: u32 = 0;

        for (game.sets) |set| {
            max_red = @max(set.red, max_red);
            max_green = @max(set.green, max_green);
            max_blue = @max(set.blue, max_blue);
        }
        return max_red * max_green * max_blue;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const path = try std.fs.realpathAlloc(gpa.allocator(), "./input");
    defer gpa.allocator().free(path);

    const input = try std.fs.cwd().readFileAlloc(gpa.allocator(), path, 1000000);
    defer gpa.allocator().free(input);

    try task1(gpa.allocator(), input);
    try task2(gpa.allocator(), input);
}

pub fn task1(allocator: Allocator, in: []const u8) !void {
    std.debug.print("Task 1:\n\n", .{});

    const games = try parse_input(in, allocator);
    defer {
        for (games) |game| game.deinit();
        allocator.free(games);
    }

    var sum: u32 = 0;
    for (games) |game| {
        if (Game.is_possible_with(game, 12, 13, 14)) {
            sum += game.id;
            std.debug.print("Game {d} is possible!\n", .{game.id});
        }
    }

    std.debug.print("The sum of possible games is: {d}\n\n", .{sum});
}

pub fn task2(allocator: Allocator, in: []const u8) !void {
    std.debug.print("Task 2:\n\n", .{});

    const games = try parse_input(in, allocator);
    defer {
        for (games) |game| game.deinit();
        allocator.free(games);
    }

    var sum: u32 = 0;
    for (games) |game| {
        const power: u32 = Game.power_of_fewest(game);
        sum += power;
        std.debug.print("The power of Game {d} is {d}.\n", .{ game.id, power });
    }

    std.debug.print("The sum is: {d}\n\n", .{sum});
}

pub fn parse_input(in: []const u8, allocator: Allocator) ![]const Game {
    std.debug.print("parse_input: {s}\n", .{in});

    var expected_games = std.mem.tokenizeAny(u8, in, "\n\r");
    var list = ArrayList(Game).init(allocator);
    defer list.deinit();

    while (expected_games.next()) |expected_game| {
        const curr = try parse_game(expected_game, allocator);
        try list.append(curr);
    }

    const res = try allocator.alloc(Game, list.items.len);
    std.mem.copyForwards(Game, res, list.items);
    return res;
}

pub fn parse_game(in: []const u8, allocator: Allocator) !Game {
    std.debug.print("parse_game: {s}\n", .{in});

    var id_then_sets = std.mem.tokenizeAny(u8, in, ":\n\r");
    const expected_game_id = id_then_sets.next();
    const expected_sets = id_then_sets.next();

    if (expected_game_id == null or expected_sets == null) {
        return ParseError.InvalidFormat;
    }

    const id = try parse_game_id(expected_game_id.?);
    var expected_sets_tokenized = std.mem.tokenizeAny(u8, expected_sets.?, ";");
    var list = ArrayList(CubeSet).init(allocator);
    defer list.deinit();

    while (expected_sets_tokenized.next()) |expected_set| {
        const set = try parse_game_set(expected_set);
        try list.append(set);
    }

    if (list.items.len <= 0) {
        std.debug.print("Failed to read any set from game definition.\n", .{});
    }

    var res = try Game.init(allocator, list.items.len);
    res.id = id;
    for (0..list.items.len) |i| {
        res.sets[i] = list.items[i];
    }

    return res;
}

pub fn parse_game_id(in: []const u8) !u32 {
    std.debug.print("parse_game_id: {s}\n", .{in});
    // assert game prefix and remove
    if (!std.mem.eql(u8, in[0..5], "Game ")) {
        return ParseError.InvalidFormat;
    }

    const integer_expected = in[5..];
    return std.fmt.parseInt(u32, integer_expected, 10);
}

pub fn parse_game_set(in: []const u8) !CubeSet {
    std.debug.print("parse_game_set: {s}\n", .{in});

    var in_splitted = std.mem.split(u8, in, ",");
    var res: CubeSet = .{ .red = 0, .green = 0, .blue = 0 };

    while (in_splitted.next()) |split_dirty| {
        const split = remove_spaces(split_dirty);

        var pair = std.mem.split(u8, split, " ");
        const expected_int = pair.next();
        const expected_col = pair.next();

        if (expected_int == null or expected_col == null) {
            return ParseError.InvalidFormat;
        }

        const Colors = enum { red, green, blue };

        std.debug.print("{s} {s}\n", .{ expected_col.?, expected_int.? });

        const count: u32 = try std.fmt.parseInt(u32, expected_int.?, 10);
        const col: ?Colors = std.meta.stringToEnum(Colors, expected_col.?);

        if (col == null) {
            return ParseError.InvalidFormat;
        }

        switch (col.?) {
            .red => res.red += count,
            .green => res.green += count,
            .blue => res.blue += count,
        }
    }

    return res;
}

//oh no
pub fn remove_spaces(in: []const u8) []const u8 {
    var low: usize = 0;
    var overall_len: usize = in.len;

    for (0..in.len) |i| {
        if (in[i] == ' ') {
            low += 1;
        } else {
            break;
        }
    }

    for (1..in.len - 1) |i| {
        const j = in.len - i;
        if (in[j] == ' ') {
            overall_len -= 1;
        } else {
            break;
        }
    }

    return in[low..overall_len];
}

test "parse_game" {
    const test_allocator = std.testing.allocator;
    const case = "Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green\nGame 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue\nGame 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red\nGame 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red\nGame 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green\n";
    const expected_sum: u32 = 8;
    const check: CubeSet = .{ .red = 12, .green = 13, .blue = 14 };

    const games = try parse_input(case, test_allocator);
    defer {
        for (games) |game| game.deinit();
        test_allocator.free(games);
    }

    std.debug.print("PARSED GAMES -> \n", .{});
    for (games) |game| {
        Game.print(game);
    }

    var sum: u32 = 0;
    for (games) |game| {
        if (Game.is_possible_with(game, check.red, check.green, check.blue)) {
            sum += game.id;
        }
    }
    if (sum == expected_sum) {
        std.debug.print("\nSUCCESS!\n\n", .{});
    } else {
        std.debug.print("\nFAILED!\n\n", .{});
    }
}

test "task2" {
    const test_allocator = std.testing.allocator;
    const case = "Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green\nGame 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue\nGame 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red\nGame 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red\nGame 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green\n";
    const expected_sum: u32 = 2286;

    const games = try parse_input(case, test_allocator);
    defer {
        for (games) |game| game.deinit();
        test_allocator.free(games);
    }

    var sum: u32 = 0;
    for (games) |game| {
        sum += Game.power_of_fewest(game);
    }

    if (sum == expected_sum) {
        std.debug.print("\nSUCCESS!\n\n", .{});
    } else {
        std.debug.print("\nFAILED!\n\n", .{});
    }
}
