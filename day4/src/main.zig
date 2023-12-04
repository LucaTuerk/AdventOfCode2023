const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = @import("std").ArrayList;

const test_input = @embedFile("test_input");
const input = @embedFile("input");

const Card = struct {
    id: u32,
    winning_numbers: ?[]u32,
    numbers: ?[]u32,
    allocator: Allocator,

    fn empty(allocator: Allocator) Card {
        return .{ .id = 0, .winning_numbers = null, .numbers = null, .allocator = allocator };
    }

    pub fn init(allocator: Allocator, buf: []const u8) !Card {
        var wn_list = ArrayList(u32).init(allocator);
        defer wn_list.deinit();

        var n_list = ArrayList(u32).init(allocator);
        defer wn_list.deinit();

        const id: u32 = 0;

        var res: Card = Card.empty(allocator);
        res.id = id;

        var split = std.mem.tokenizeAny(u8, buf, ":|");
        const card = split.next() orelse "";
        const winning = split.next() orelse "";
        const numbers = split.next() orelse "";

        var card_split = std.mem.tokenizeAny(u8, card, " ");
        var winning_split = std.mem.tokenizeAny(u8, winning, " ");
        var numbers_split = std.mem.tokenizeAny(u8, numbers, " ");

        while (card_split.next()) |smth| {
            const val: ?u32 = std.fmt.parseInt(u32, smth, 10) catch null;
            if (val != null) res.id = val.?;
        }

        while (winning_split.next()) |smth| {
            const val: ?u32 = std.fmt.parseInt(u32, smth, 10) catch null;
            if (val != null) try wn_list.append(val.?);
        }

        while (numbers_split.next()) |smth| {
            const val: ?u32 = std.fmt.parseInt(u32, smth, 10) catch null;
            if (val != null) try n_list.append(val.?);
        }

        if (wn_list.items.len > 0) {
            res.winning_numbers = try wn_list.toOwnedSlice();
        }

        if (n_list.items.len > 0) {
            res.numbers = try n_list.toOwnedSlice();
        }

        return res;
    }

    pub fn deinit(card: Card) void {
        if (card.winning_numbers != null) {
            card.allocator.free(card.winning_numbers.?);
        }

        if (card.numbers != null) {
            card.allocator.free(card.numbers.?);
        }
    }

    pub fn value(card: Card) u32 {
        const count = win_count(card);
        if (count == 0) return 0;

        const res: u32 = 1;
        return res << @as(u5, @intCast(count - 1)); // oh god why
    }

    pub fn win_count(card: Card) u32 {
        var count: u32 = 0;

        if (card.winning_numbers == null or card.numbers == null) {
            return 0;
        }

        for (card.numbers.?) |num| {
            for (card.winning_numbers.?) |win_num| {
                if (num == win_num) {
                    count += 1;
                    break;
                }
            }
        }

        return count;
    }

    pub fn print(card: Card) void {
        std.debug.print("Card {d}: \n", .{card.id});

        if (card.winning_numbers != null) {
            std.debug.print("Winning Numbers: ", .{});
            for (card.winning_numbers.?) |num| {
                std.debug.print("{d} ", .{num});
            }
            std.debug.print("\n", .{});
        }

        if (card.numbers != null) {
            std.debug.print("Own Numbers: ", .{});
            for (card.numbers.?) |num| {
                std.debug.print("{d} ", .{num});
            }
            std.debug.print("\n", .{});
        }

        std.debug.print("Value: {d}\n", .{Card.value(card)});
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    try task1(gpa.allocator(), input);
    try task2(gpa.allocator(), input);
}

pub fn task1(allocator: Allocator, input_raw: []const u8) !void {
    var cards_raw = std.mem.tokenizeAny(u8, input_raw, "\n\r");

    var card_stack = ArrayList(Card).init(allocator);
    defer {
        for (card_stack.items) |card| {
            Card.deinit(card);
        }
        card_stack.deinit();
    }

    while (cards_raw.next()) |card_raw| {
        const card = try Card.init(allocator, card_raw);
        try card_stack.append(card);
    }

    var sum: u32 = 0;
    for (0..card_stack.items.len) |i| {
        Card.print(card_stack.items[i]);
        sum += Card.value(card_stack.items[i]);
    }

    std.debug.print("Task 1: The sum is {d}\n", .{sum});
}

const CardError = error{InstancesMissed};

const CardStack = struct {
    cards: []Card,
    counts: []u32,
    changed: []u32,
    allocator: Allocator,

    pub fn init(allocator: Allocator, cards: []Card) !CardStack {
        const res: CardStack = .{ .cards = cards, .counts = try allocator.alloc(u32, cards.len), .changed = try allocator.alloc(u32, cards.len), .allocator = allocator };
        for (0..res.cards.len) |i| {
            res.counts[i] = 0;
            res.changed[i] = 1;
        }
        return res;
    }

    pub fn deinit(stack: CardStack) void {
        for (stack.cards) |card| {
            Card.deinit(card);
        }

        stack.allocator.free(stack.cards);
        stack.allocator.free(stack.counts);
        stack.allocator.free(stack.changed);
    }

    pub fn propagate_counts(stack: CardStack, index: usize) !void {
        const card: Card = stack.cards[index];
        const count = Card.win_count(card);

        if (count == 0) {
            stack.counts[index] += stack.changed[index];
            stack.changed[index] = 0;
            return;
        }

        var i: u32 = card.id;
        while (i < index + count + 1 and i < stack.cards.len) : (i += 1) {
            // std.debug.print("{d}({d}) -> {d} : {d}\n", .{ card.id, count, i + 1, stack.counts[index] });
            stack.changed[i] += stack.changed[index];
            try propagate_counts(stack, i);
        }

        stack.counts[index] += stack.changed[index];
        stack.changed[index] = 0;
    }

    pub fn cards_with_changed(stack: CardStack) ?usize {
        for (stack.changed, 0..) |val, i| {
            if (val > 0) {
                return i;
            }
        }
        return null;
    }

    pub fn get_count_sum(stack: CardStack) u32 {
        var sum: u32 = 0;
        for (stack.counts, stack.changed, 1..) |count, changed, i| {
            std.debug.print("Card {d} x {d}, changed {d} \n", .{ i, count, changed });
            sum += count;
        }
        return sum;
    }
};

pub fn task2(allocator: Allocator, input_raw: []const u8) !void {
    var cards_raw = std.mem.tokenizeAny(u8, input_raw, "\n\r");

    var cards = ArrayList(Card).init(allocator);
    defer {
        for (cards.items) |card| {
            Card.deinit(card);
        }
        cards.deinit();
    }

    while (cards_raw.next()) |card_raw| {
        const card = try Card.init(allocator, card_raw);
        try cards.append(card);
    }

    var card_stack = try CardStack.init(allocator, try cards.toOwnedSlice());
    defer card_stack.deinit();

    while (CardStack.cards_with_changed(card_stack)) |i| {
        std.debug.print("{d} ", .{i});
        try CardStack.propagate_counts(card_stack, i);
    }

    std.debug.print("Task 2 : The sum is: {d}\n", .{CardStack.get_count_sum(card_stack)});
}

pub fn has(val: u32, arr: []u32) bool {
    for (arr) |item| {
        if (item == val) return true;
    }
    return false;
}

test "simple test" {
    const test_allocator = std.testing.allocator;

    var card_stack = ArrayList(Card).init(test_allocator);
    defer {
        for (card_stack.items) |card| {
            Card.deinit(card);
        }
        card_stack.deinit();
    }

    var cards_raw = std.mem.tokenizeAny(u8, test_input, "\n\r");

    while (cards_raw.next()) |card_raw| {
        const card = try Card.init(test_allocator, card_raw);
        try card_stack.append(card);
    }

    for (0..card_stack.items.len) |i| {
        Card.print(card_stack.items[i]);
    }

    try task2(test_allocator, test_input);
}
