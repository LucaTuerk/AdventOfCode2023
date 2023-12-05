const std = @import("std");
const ArrayList = @import("std").ArrayList;
const AutoHashMap = @import("std").AutoHashMap;
const HashMap = @import("std").HashMap;
const Allocator = std.mem.Allocator;

const input = @embedFile("input");
const test_input = @embedFile("test_input");
const Self = @This();

const MapError = error{ KeyTaken, NotFound };

fn str_hash(str: []const u8) u64 {
    return std.hash.Wyhash.hash(0, str);
}

const Range = struct {
    from: u64,
    to: u64,
    count: u64,

    pub fn get(this: *const Range, key: u64) ?u64 {
        if (key >= this.from and key < this.from + this.count) {
            return this.to + key - this.from;
        }
        return null;
    }
};

const Map = struct {
    _from_pretty: []const u8,
    _to_pretty: []const u8,
    from: u64,
    to: u64,
    map: ArrayList(Range),
    allocator: Allocator,

    pub fn init(allocator: Allocator, from: []const u8, to: []const u8) !Map {
        const map = ArrayList(Range).init(allocator);
        const res: Map = .{
            ._from_pretty = from,
            ._to_pretty = to,
            .from = str_hash(from),
            .to = str_hash(to),
            .map = map,
            .allocator = allocator,
        };
        return res;
    }

    pub fn deinit(this: *Map) void {
        this.map.deinit();
    }

    pub fn get(this: *const Map, key: u64) u64 {
        for (this.map.items) |range| {
            const val = range.get(key);
            if (val != null) {
                return val.?;
            }
        }
        return key;
    }

    pub fn put_range(this: *Map, from: u64, to: u64, count: u64) !void {
        const range: Range = .{ .from = from, .to = to, .count = count };
        try this.map.append(range);
    }
};

const MapContext = struct {
    pub fn hash(ctx: MapContext, map: Map) u64 {
        _ = ctx;
        return map.from ^ map.to;
    }

    pub fn eql(ctx: MapContext, lhs: Map, rhs: Map) bool {
        return MapContext.hash(ctx, lhs) == MapContext.hash(ctx, rhs);
    }
};

const MapChain = struct {
    _from_pretty: []const u8,
    _to_pretty: []const u8,
    from: u64,
    to: u64,
    _maps: []Map,
    allocator: Allocator,

    pub fn get(this: *MapChain, key: u64) u64 {
        var res = key;
        for (this._maps) |map| {
            res = map.get(res);
        }
        return res;
    }

    const BFSError = error{BacktraceError};

    pub fn find_init(allocator: Allocator, all_maps: []Map, from: []const u8, to: []const u8) !MapChain {
        const from_hash = str_hash(from);
        const to_hash = str_hash(to);

        var stack = ArrayList(Map).init(allocator);
        defer stack.deinit();

        var visited = HashMap(Map, void, MapContext, std.hash_map.default_max_load_percentage).init(allocator);
        defer visited.deinit();

        var parents = HashMap(Map, Map, MapContext, std.hash_map.default_max_load_percentage).init(allocator);
        defer parents.deinit();

        const _slice = try find_from(allocator, all_maps, from_hash);
        defer allocator.free(_slice);

        if (_slice.len == 0) {
            return MapError.NotFound;
        }

        var found = false;
        const start = _slice[0];
        var goal: ?Map = null;
        try stack.append(start);
        std.debug.print("Starting BFS:\n", .{});
        while (stack.popOrNull()) |v| {
            if (!visited.contains(v)) {
                std.debug.print("\tVisiting {s}-to-{s}\n", .{ v._from_pretty, v._to_pretty });

                try visited.put(v, {});
                if (v.to == to_hash) {
                    std.debug.print("\nGoal {s}-to-{s} found!\n", .{ v._from_pretty, v._to_pretty });

                    found = true;
                    goal = v;
                } else {
                    const slice = try find_from(allocator, all_maps, v.to);
                    defer allocator.free(slice);

                    for (slice) |map| {
                        try parents.put(map, v);
                    }
                    const from_slice = try find_from(allocator, all_maps, v.to);
                    defer allocator.free(from_slice);

                    try stack.appendSlice(from_slice);
                }
            }
            if (found) break;
        }

        if (goal == null)
            return MapError.NotFound;

        // backtrace
        var path = ArrayList(Map).init(allocator);
        defer path.deinit();

        std.debug.print("\nStarting backtrace: (searching {s}-to-{s})\n", .{ start._from_pretty, start._to_pretty });

        var curr: Map = goal.?;
        while (parents.get(curr)) |next| {
            std.debug.print("\tTracing from {s}-to-{s}\n", .{ curr._from_pretty, curr._to_pretty });
            try path.insert(0, curr);
            curr = next;
        }
        try path.insert(0, start);

        for (path.items, 0..) |map, i| {
            std.debug.print("{s}->", .{map._from_pretty});
            if (i == path.items.len - 1) std.debug.print("{s}\n\n", .{map._to_pretty});
        }

        const res: MapChain = .{
            ._from_pretty = from,
            ._to_pretty = to,
            .from = from_hash,
            .to = to_hash,
            ._maps = try path.toOwnedSlice(),
            .allocator = allocator,
        };

        return res;
    }

    fn find_from(allocator: Allocator, maps: []Map, from_hash: u64) ![]Map {
        var list = ArrayList(Map).init(allocator);
        defer list.deinit();

        for (maps) |map| {
            if (map.from == from_hash) {
                try list.append(map);
            }
        }
        return list.toOwnedSlice();
    }

    pub fn deinit(this: *MapChain) void {
        this.allocator.free(this._maps);
    }
};

const ParseError = error{UnexpectedInput};

pub fn read_seeds(allocator: Allocator, in: []const u8) ![]u64 {
    std.debug.print("\nread_seeds: \n{s}\n", .{in});

    const seeds = in[0..7];
    const nums = in[7..];

    if (!std.mem.eql(u8, seeds, "seeds: ")) {
        return ParseError.UnexpectedInput;
    }

    var list = ArrayList(u64).init(allocator);
    defer list.deinit();

    var numbers_split = std.mem.tokenizeAny(u8, nums, "\n\r ");
    while (numbers_split.next()) |num| {
        const num_parsed = try std.fmt.parseInt(u64, num, 10);
        try list.append(num_parsed);
    }

    return list.toOwnedSlice();
}

pub fn read_map(allocator: Allocator, in: []const u8) !Map {
    std.debug.print("\nread_map: \n{s}\n", .{in});

    var lines = std.mem.tokenizeAny(u8, in, "\n\r");
    const first_line = lines.next();

    if (first_line == null) {
        return ParseError.UnexpectedInput;
    }

    var expected_map_def = std.mem.tokenizeAny(u8, first_line.?, " ");
    const expected_from_to = expected_map_def.next();
    const expected_map = expected_map_def.next();

    if (expected_map == null or expected_from_to == null or expected_map == null) {
        return ParseError.UnexpectedInput;
    }

    if (!std.mem.eql(u8, expected_map.?, "map:")) {
        return ParseError.UnexpectedInput;
    }

    var from_to_split = std.mem.tokenizeAny(u8, expected_from_to.?, "-");
    const expected_from = from_to_split.next();
    const expected_connect = from_to_split.next();
    const expected_to = from_to_split.next();

    if (expected_from == null or expected_connect == null or expected_to == null) {
        return ParseError.UnexpectedInput;
    }

    if (!std.mem.eql(u8, expected_connect.?, "to")) {
        return ParseError.UnexpectedInput;
    }

    std.debug.print("Creating {s} to {s} map.\n", .{ expected_from.?, expected_to.? });
    var map = try Map.init(allocator, expected_from.?, expected_to.?);

    while (lines.next()) |line| {
        std.debug.print("{s}\n", .{line});
        var split = std.mem.tokenizeAny(u8, line, "\n\r ");

        const to_start = split.next();
        const from_start = split.next();
        const count = split.next();

        if (from_start == null or to_start == null or count == null) {
            return ParseError.UnexpectedInput;
        }

        const from_start_int = try std.fmt.parseInt(u64, from_start.?, 10);
        const to_start_int = try std.fmt.parseInt(u64, to_start.?, 10);
        const count_int = try std.fmt.parseInt(u64, count.?, 10);

        try map.put_range(from_start_int, to_start_int, count_int);
    }

    return map;
}

pub fn read_maps(allocator: Allocator, in: []const u8) ![]Map {
    std.debug.print("\nread_maps: \n{s}\n", .{in});
    var maps_split = std.mem.tokenizeSequence(u8, in, "\n\r\n");

    var list = ArrayList(Map).init(allocator);
    defer list.deinit();

    while (maps_split.next()) |split| {
        const map = read_map(allocator, split) catch null;
        if (map != null) try list.append(map.?);
    }

    return list.toOwnedSlice();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    try task1(gpa.allocator(), input);
    try task2(gpa.allocator(), input); // this is pretty inefficient but should finish in 20 min or so
}

pub fn task1(allocator: Allocator, in: []const u8) !void {
    var split = std.mem.tokenizeAny(u8, in, "\n");

    const seeds: []u64 = try read_seeds(allocator, split.next().?);
    defer allocator.free(seeds);

    const maps: []Map = try read_maps(allocator, in);
    defer {
        for (0..maps.len) |i| {
            maps[i].deinit();
        }
        allocator.free(maps);
    }

    var chain: MapChain = try MapChain.find_init(allocator, maps, "seed", "location");
    defer chain.deinit();

    var min: u64 = std.math.maxInt(u64);
    for (seeds) |seed| {
        const dest = chain.get(seed);
        std.debug.print("seed->location : {d} -> {d}\n", .{ seed, dest });
        min = @min(min, dest);
    }

    std.debug.print("\n\nTask 1 : {d}\n", .{min});
}

pub fn task2(allocator: Allocator, in: []const u8) !void {
    var split = std.mem.tokenizeAny(u8, in, "\n");

    const seeds: []u64 = try read_seeds(allocator, split.next().?);
    defer allocator.free(seeds);

    const maps: []Map = try read_maps(allocator, in);
    defer {
        for (0..maps.len) |i| {
            maps[i].deinit();
        }
        allocator.free(maps);
    }

    var chain: MapChain = try MapChain.find_init(allocator, maps, "seed", "location");
    defer chain.deinit();

    var min: u64 = std.math.maxInt(u64);

    var i: usize = 0;
    while (i < seeds.len - 1) : (i += 2) {
        var seed: usize = seeds[i];
        const max = seeds[i] + seeds[i + 1];
        std.debug.print("{d}...\n", .{seeds[i]});
        while (seed < max) : (seed += 1) {
            const dest = chain.get(seed);
            min = @min(min, dest);
        }
    }

    std.debug.print("\n\nTask 2 : {d}\n", .{min});
}

test "simple test" {
    const test_allocator = std.testing.allocator;

    std.debug.print("\n\nTest:\n\n", .{});

    var split = std.mem.tokenizeAny(u8, test_input, "\n");

    const seeds: []u64 = try read_seeds(test_allocator, split.next().?);
    defer test_allocator.free(seeds);

    const maps: []Map = try read_maps(test_allocator, test_input);
    defer {
        for (0..maps.len) |i| {
            maps[i].deinit();
        }
        test_allocator.free(maps);
    }

    std.debug.print("\n", .{});
    for (seeds) |seed| {
        std.debug.print("{d} ", .{seed});
    }
    std.debug.print("\n", .{});

    for (maps) |map| {
        std.debug.print("Map from {s} to {s} read.\n", .{ map._from_pretty, map._to_pretty });
    }

    std.debug.print("\n", .{});
    var chain: MapChain = try MapChain.find_init(test_allocator, maps, "seed", "location");
    defer chain.deinit();

    for (seeds) |seed| {
        const dest = chain.get(seed);
        std.debug.print("seed->location : {d} -> {d}\n", .{ seed, dest });
    }
}
