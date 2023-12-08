const std = @import("std");
const AutoHashMap = @import("std").AutoHashMap;
const ArrayList = @import("std").ArrayList;
const Allocator = std.mem.Allocator;
const input = @embedFile("input");
const test_input = @embedFile("test_input");

//const CardKind = enum(u8) { two = 2, three = 3, four = 4, five = 5, six = 6, seven = 7, eight = 8, nine = 9, T, J, Q, K, A };
const CardKind = enum(u8) { J, two = 2, three = 3, four = 4, five = 5, six = 6, seven = 7, eight = 8, nine = 9, T, Q, K, A };
const HandKind = enum(u8) { HighCard, OnePair, TwoPair, ThreeOfAKind, FullHouse, FourOfAKind, FiveOfAKind };

const Card = struct {
    kind: CardKind,

    pub fn from_char(ch: u8) ?Card {
        if (ch > '0' and ch <= '9') {
            return .{ .kind = @as(CardKind, @enumFromInt(ch - '0')) };
        } else {
            var str: [1]u8 = .{ch};
            const kind: ?CardKind = std.meta.stringToEnum(CardKind, str[0..]);
            if (kind != null) {
                return .{ .kind = kind.? };
            }
        }
        return null;
    }
};

const HandError = error{InvalidFormat};

const Hand = struct {
    kind: HandKind,
    cards: [5]Card,
    bid: i32,

    pub fn from_str(allocator: Allocator, str: []const u8) !Hand {
        var hand: Hand = .{ .kind = HandKind.FourOfAKind, .cards = undefined, .bid = 0 };

        const cards = str[0..5];
        const bid = str[6..];
        if (str[5] != ' ') {
            return HandError.InvalidFormat;
        }

        for (cards, 0..) |ch, i| {
            const card = Card.from_char(ch);
            if (card == null) return HandError.InvalidFormat;
            hand.cards[i] = card.?;
        }

        hand.bid = try std.fmt.parseInt(i32, bid, 10);

        //try hand.get_hand_kind_t1(allocator);
        try hand.get_hand_kind_t2(allocator);

        return hand;
    }

    fn get_hand_kind_t2(hand: *Hand, allocator: Allocator) !void {
        var hashMap = AutoHashMap(CardKind, i32).init(allocator);
        defer hashMap.deinit();

        var jokers: i32 = 0;
        var max: i32 = 0;
        for (hand.cards) |card| {
            const curr = hashMap.get(card.kind) orelse 0;
            if (card.kind == CardKind.J) {
                jokers += 1;
            } else {
                max = @max(curr + 1, max);
                try hashMap.put(card.kind, curr + 1);
            }
        }

        var keyItr = hashMap.keyIterator();
        var keyLen: i32 = 0;
        while (keyItr.next()) |_| {
            keyLen += 1;
        }

        const sum = max + jokers;
        switch (sum) {
            5 => hand.kind = HandKind.FiveOfAKind,
            4 => hand.kind = HandKind.FourOfAKind,
            3 => {
                if (keyLen == 3) {
                    // TJJAB
                    hand.kind = HandKind.ThreeOfAKind;
                } else {
                    // TJJAA
                    hand.kind = HandKind.FullHouse;
                }
            },
            2 => {
                if (keyLen == 3) {
                    hand.kind = HandKind.TwoPair;
                } else if (keyLen == 4) {
                    hand.kind = HandKind.OnePair;
                } else {
                    return HandError.InvalidFormat;
                }
            },
            1 => hand.kind = HandKind.HighCard,
            else => return HandError.InvalidFormat,
        }
    }

    fn get_hand_kind_t1(hand: *Hand, allocator: Allocator) !void {
        var hashMap = AutoHashMap(CardKind, i32).init(allocator);
        defer hashMap.deinit();

        for (hand.cards) |card| {
            const curr = hashMap.get(card.kind) orelse 0;
            try hashMap.put(card.kind, curr + 1);
        }

        var keyItr = hashMap.keyIterator();
        var keyLen: i32 = 0;
        while (keyItr.next()) |_| {
            keyLen += 1;
        }

        var valItr = hashMap.valueIterator();
        var maxVal: i32 = 0;
        while (valItr.next()) |val| {
            maxVal = @max(maxVal, val.*);
        }

        switch (keyLen) {
            1 => hand.kind = HandKind.FiveOfAKind,
            2 => {
                var _keyItr = hashMap.keyIterator();
                const val = hashMap.get(_keyItr.next().?.*).?;
                switch (val) {
                    3, 2 => hand.kind = HandKind.FullHouse,
                    else => hand.kind = HandKind.FourOfAKind,
                }
            },
            3 => {
                if (maxVal == 3) {
                    hand.kind = HandKind.ThreeOfAKind;
                } else {
                    hand.kind = HandKind.TwoPair;
                }
            },
            4 => hand.kind = HandKind.OnePair,
            5 => hand.kind = HandKind.HighCard,
            else => return HandError.InvalidFormat,
        }
    }

    pub fn cmp(lhs: *const Hand, rhs: *const Hand) i32 {
        if (rhs.kind != lhs.kind) {
            if (@intFromEnum(rhs.kind) > @intFromEnum(lhs.kind)) return -1;
            return 1;
        }
        for (0..5) |i| {
            if (rhs.cards[i].kind != lhs.cards[i].kind) {
                if (@intFromEnum(rhs.cards[i].kind) > @intFromEnum(lhs.cards[i].kind)) return -1;
                return 1;
            }
        }
        return 0;
    }
};

pub fn sort(allocator: Allocator, hands: *ArrayList(Hand)) !void {
    var list = ArrayList(Hand).init(allocator);
    defer list.deinit();

    while (hands.popOrNull()) |hand| {
        if (list.items.len == 0) {
            try list.append(hand);
            continue;
        }

        var i: usize = 0;
        var inserted: bool = false;
        while (i < list.items.len and !inserted) : (i += 1) {
            if (hand.cmp(&list.items[i]) < 0) {
                try list.insert(i, hand);
                inserted = true;
            }
        }
        if (!inserted) {
            try list.insert(list.items.len, hand);
        }
    }

    try hands.appendSlice(list.items);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var list = ArrayList(Hand).init(gpa.allocator());
    defer list.deinit();

    var lines = std.mem.tokenizeAny(u8, input, "\n\r");

    while (lines.next()) |line| {
        const hand = try Hand.from_str(gpa.allocator(), line);
        try list.append(hand);
    }

    try sort(gpa.allocator(), &list);
    var sum: i32 = 0;
    for (list.items, 1..) |hand, rank| {
        std.debug.print("{s} {d}\n", .{ @tagName(hand.kind), hand.bid });
        sum += @as(i32, @intCast(hand.bid)) * @as(i32, @intCast(rank));
    }
    std.debug.print("Task 1: {d}\n", .{sum});
}

test "simple test" {
    var list = ArrayList(Hand).init(std.testing.allocator);
    defer list.deinit();

    var lines = std.mem.tokenizeAny(u8, test_input, "\n\r");

    while (lines.next()) |line| {
        const hand = try Hand.from_str(std.testing.allocator, line);
        try list.append(hand);
    }

    try sort(std.testing.allocator, &list);
    var sum: i32 = 0;
    for (list.items, 1..) |hand, rank| {
        std.debug.print("{d}\n", .{hand.bid});
        std.debug.print("{s}\n", .{@tagName(hand.kind)});
        sum += @as(i32, @intCast(hand.bid)) * @as(i32, @intCast(rank));
    }
    std.debug.print("{d}\n", .{sum});
}
