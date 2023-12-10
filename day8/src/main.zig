const std = @import("std");
const AutoHashMap = @import("std").AutoHashMap;
const ArrayList = @import("std").ArrayList;
const Allocator = std.mem.Allocator;
const test_input = @embedFile("test_input");
const input = @embedFile("input");

pub fn get_uid(name: []const u8) u32 {
    return @as(u32, @intCast(name[0])) +
        @as(u32, @intCast(name[1])) * 256 +
        @as(u32, @intCast(name[2])) * 65536;
}

const NodeVariantError = error{VariantInvalid};

const NodeVariant = struct {
    uid: u32,
    node: ?*Node,

    pub fn from_name(name: []const u8) NodeVariant {
        const nv: NodeVariant = .{ .uid = get_uid(name), .node = null };
        return nv;
    }

    pub fn from_node(node: *Node) NodeVariant {
        const nv: NodeVariant = .{ .uid = node.uid, .node = node };
        return nv;
    }

    pub fn get_node(self: *NodeVariant, map: *Map) !*Node {
        if (self.node != null) {
            return self.node.?;
        }
        const node = map.nodes.get(self.uid) orelse null;
        if (node == null) {
            return NodeVariantError.VariantInvalid;
        }
        self.node = node;
        return node.?;
    }
};

const Node = struct {
    name: []const u8,
    uid: u32,
    left: NodeVariant,
    right: NodeVariant,
    is_start_node: bool,
    is_end_node: bool,

    pub fn next(self: *Node, instruction: Instruction, map: *Map) !*Node {
        switch (instruction) {
            Instruction.L => return try self.left.get_node(map),
            Instruction.R => return try self.right.get_node(map),
        }
    }
};

// const CircleIterator = struct {
//     i : usize;
//     circle : Circle;

//     pub fn next(self : * CircleIterator) ?usize {
//         self.i += 1;
//         return circle.offset + (i * circle.length)
//     }
// }

const Circle = struct {
    offset: usize,
    length: usize,
    win_offsets: []usize,

    pub fn get_multiples(self: Circle, allocator: Allocator, start: usize, count: usize) ![]usize {
        var list = ArrayList(usize).init(allocator);
        defer list.deinit();
        var i: usize = start;
        while (i < start + count) : (i += 1) {
            try list.append(self.offset + (i * self.length));
        }
        return list.toOwnedSlice();
    }

    pub fn iterator(self: Circle, pc: usize) CircleIterator {
        return .{ .pc = pc, .circle = self };
    }
};

const CircleItError = error{InvalidProgramCounter};

const CircleIterator = struct {
    pc: usize,
    circle: Circle,

    pub fn next(self: *CircleIterator) !usize {
        if (self.pc < self.circle.offset) {
            return CircleItError.InvalidProgramCounter;
        }

        const in_circle_pos = (self.pc - self.circle.offset) % self.circle.length;
        // if (in_circle_pos != 0) {
        //     std.debug.print("{d} {d} : {d} {d} \n", .{ self.circle.offset, self.circle.length, self.pc, in_circle_pos });
        // }
        var smallest_non_zero_win_offset: usize = 1000000000000; // where is the usize_max
        for (self.circle.win_offsets) |off| {
            const curr = if (in_circle_pos < off) off - in_circle_pos else self.circle.length - in_circle_pos;
            if (curr > 0) {
                smallest_non_zero_win_offset = @min(smallest_non_zero_win_offset, curr);
            }
        }
        self.*.pc += smallest_non_zero_win_offset;
        return self.pc;
    }

    // pub fn synchronize(a: CircleIterator, b: CircleIterator) CircleIterator {
    //     if (a.pc < b.pc) {
    //         return CircleItError.InvalidProgramCounter;
    //     }

    //     while (b.pc < a.pc) {
    //         try b.next();
    //     }

    //     while (a.pc != b.pc) {
    //         if (a.pc < b.pc) try a.next();
    //         if (b.pc < a.pc) try b.next();
    //     }
    // }
};

const Instruction = enum { L, R };

const Map = struct {
    instructions: ArrayList(Instruction),
    nodes: AutoHashMap(u32, *Node),
    allocator: Allocator,

    pub fn init(allocator: Allocator) Map {
        const res: Map = .{
            .instructions = ArrayList(Instruction).init(allocator),
            .nodes = AutoHashMap(u32, *Node).init(allocator),
            .allocator = allocator,
        };
        return res;
    }

    pub fn deinit(self: *Map) void {
        self.instructions.deinit();
        var valItr = self.nodes.valueIterator();
        while (valItr.next()) |val| {
            self.allocator.destroy(val.*);
        }
        self.nodes.deinit();
    }

    pub fn add_instruction(self: *Map, inst: Instruction) !void {
        try self.instructions.append(inst);
    }

    pub fn add_node(self: *Map, name: []const u8, left: []const u8, right: []const u8) !*Node {
        // std.debug.print("{s} = {s} {s}\n", .{ name, left, right });

        const node: *Node = try self.allocator.create(Node);
        errdefer self.allocator.destroy(node);
        node.* = .{
            .name = name,
            .uid = get_uid(name),
            .left = NodeVariant.from_name(left),
            .right = NodeVariant.from_name(right),
            .is_start_node = name[2] == 'A',
            .is_end_node = name[2] == 'Z',
        };
        try self.nodes.putNoClobber(node.uid, node);

        if (node.*.is_end_node and left[2] == 'Z' and right[2] == 'Z') {
            std.debug.print("{s}\n", .{node.*.name});
        }

        return node;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // try task1(gpa.allocator());+
    try task2(gpa.allocator());
}

pub fn task1(allocator: Allocator) !void {
    var map: Map = Map.init(allocator);
    defer map.deinit();

    var lines = std.mem.tokenizeAny(u8, input, "\n\r");
    const instructions = lines.next().?;

    for (instructions) |ch| {
        const str: [1]u8 = .{ch};
        const enm = std.meta.stringToEnum(Instruction, &str).?;
        try map.add_instruction(enm);
        std.debug.print("{s}", .{@tagName(enm)});
    }
    std.debug.print("\n", .{});

    var node: *Node = undefined;
    const start: u32 = get_uid("AAA");
    const goal: u32 = get_uid("ZZZ");
    var init: bool = false;

    while (lines.next()) |line| {
        var names = std.mem.tokenizeAny(u8, line, "(),= \n\r");
        const name = names.next().?;
        const curr_uid = get_uid(name);

        const curr = try map.add_node(
            name,
            names.next().?,
            names.next().?,
        );
        if (curr_uid == start) {
            node = curr;
            init = true;
        }
    }

    if (!init) {
        std.debug.print("Could not find start node AAA. Abort!", .{});
        return;
    }

    var pc: usize = 0;
    while (node.uid != goal) : (pc += 1) {
        const inst: Instruction = map.instructions.items[pc % map.instructions.items.len];
        switch (inst) {
            Instruction.L => node = try node.left.get_node(&map),
            Instruction.R => node = try node.right.get_node(&map),
        }
    }

    std.debug.print("\nSteps: {d}", .{pc});
}

pub fn find_circle(allocator: Allocator, node: *Node, map: *Map) !Circle {
    var hash_map = AutoHashMap(u32, AutoHashMap(usize, usize)).init(allocator);
    defer {
        var keyIterator = hash_map.keyIterator();
        while (keyIterator.next()) |key| {
            var n_map = hash_map.get(key.*);
            if (n_map != null) {
                n_map.?.deinit();
            }
        }
        hash_map.deinit();
    }

    var pc: usize = 0;
    var circle_found: bool = false;
    var node_it: *Node = node;

    var length: usize = 0;
    var offset: usize = 0;

    while (!circle_found) : (pc += 1) {
        const inst: Instruction = map.instructions.items[pc % map.instructions.items.len];
        const pc_mod = pc % map.instructions.items.len;
        node_it = try node_it.next(inst, map);

        if (!node_it.is_end_node) continue; // we dont care about non winning nodes

        const uid = node_it.*.uid;
        var node_map = hash_map.get(uid);
        if (node_map != null) {
            const prev = node_map.?.get(pc_mod);
            if (prev != null) {
                // std.debug.print("Circle Found! \n", .{});
                circle_found = true;
                offset = prev.?;
                length = pc - offset;
            } else {
                try node_map.?.put(pc_mod, pc);
            }
        } else {
            var new_map = AutoHashMap(usize, usize).init(allocator);
            try new_map.put(pc_mod, pc);
            try hash_map.put(uid, new_map);
        }
    }

    var pc_from_off: usize = 0;

    var win_offsets = ArrayList(usize).init(allocator);
    defer win_offsets.deinit();

    while (pc_from_off < length) : (pc_from_off += 1) {
        const inst: Instruction = map.instructions.items[(pc_from_off + offset) % map.instructions.items.len];
        node_it = try node_it.next(inst, map);

        if (node_it.is_end_node) {
            std.debug.print("{d}\n", .{pc_from_off});
            try win_offsets.append(pc_from_off);
        }
    }

    return .{ .offset = offset, .length = length, .win_offsets = try win_offsets.toOwnedSlice() };
}

pub fn merge(allocator: Allocator, a: *ArrayList(usize), b: []usize) !void {
    var hash_map = AutoHashMap(usize, void).init(allocator);
    defer hash_map.deinit();

    while (a.*.popOrNull()) |val| try hash_map.put(val, {});
    for (b) |val| try hash_map.put(val, {});

    var it = hash_map.keyIterator();
    while (it.next()) |val| try a.*.append(val.*);
}

pub fn merge_common_in_first(allocator: Allocator, a: *ArrayList(usize), b: *ArrayList(usize)) !void {
    var a_hash = AutoHashMap(usize, void).init(allocator);
    defer a_hash.deinit();

    var b_hash = AutoHashMap(usize, void).init(allocator);
    defer b_hash.deinit();

    while (a.*.popOrNull()) |val| try a_hash.put(val, {});
    while (b.*.popOrNull()) |val| try b_hash.put(val, {});

    var it = a_hash.keyIterator();
    while (it.next()) |val| {
        if (b_hash.get(val.*) != null) {
            try a.*.append(val.*);
        }
    }
}

pub fn lcm(a: usize, b: usize) usize {
    return a * (b / std.math.gcd(a, b));
}

pub fn task2(allocator: Allocator) !void {
    var map: Map = Map.init(allocator);
    defer map.deinit();

    var lines = std.mem.tokenizeAny(u8, input, "\n\r");
    const instructions = lines.next().?;

    for (instructions) |ch| {
        const str: [1]u8 = .{ch};
        const enm = std.meta.stringToEnum(Instruction, &str).?;
        try map.add_instruction(enm);
    }

    var startNodesList = ArrayList(*Node).init(allocator);
    defer startNodesList.deinit();

    var init: bool = false;

    while (lines.next()) |line| {
        var names = std.mem.tokenizeAny(u8, line, "(),= \n\r");
        const name = names.next().?;

        const curr = try map.add_node(
            name,
            names.next().?,
            names.next().?,
        );
        if (curr.is_start_node) {
            try startNodesList.append(curr);
            init = true;
        }
    }

    if (!init) {
        std.debug.print("Could not find any start nodes of type XXA. Abort!", .{});
        return;
    }

    // var pc: usize = 0;
    // var num_winning_nodes: usize = 0;

    std.debug.print("Looking for {d} simultanious wins", .{startNodesList.items.len});

    // var hash_map = AutoHashMap(u32, void).init(allocator);
    // defer hash_map.deinit();
    // while (num_winning_nodes != startNodesList.items.len) : (pc += 1) {
    //     num_winning_nodes = 0;
    //     const inst = map.instructions.items[pc % map.instructions.items.len];
    //     var i: usize = 0;
    //     while (i < startNodesList.items.len) : (i += 1) {
    //         if (startNodesList.items[i].is_end_node) {
    //             num_winning_nodes += 1;
    //         }
    //         startNodesList.items[i] = try startNodesList.items[i].next(inst, &map);
    //         if (hash_map.get(startNodesList.items[i].uid) != null) {
    //             std.debug.print("Nodes have synchronized!", .{});
    //         } else {
    //             try hash_map.put(startNodesList.items[i].uid, {});
    //         }
    //     }
    //     hash_map.clearRetainingCapacity();
    // }

    // std.debug.print("\n{d}", .{pc - 1});

    var max_offset: usize = 0;
    var circles = ArrayList(Circle).init(allocator);

    for (startNodesList.items) |startNode| {
        const circle = try find_circle(allocator, startNode, &map);
        try circles.append(circle);
        max_offset = @max(circle.offset, max_offset);
    }
    std.debug.print("Max Circle Offset : {d} // After this we can use the circle to iterate.\n", .{max_offset});
    std.debug.print("Start iterating to {d}...\n", .{max_offset});

    var pc: usize = 0;
    var num_winning_nodes: usize = 0;
    var found: bool = false;

    while (pc < max_offset) : (pc += 1) {
        const inst = map.instructions.items[pc % map.instructions.items.len];

        var i: usize = 0;
        while (i < startNodesList.items.len) : (i += 1) {
            if (startNodesList.items[i].is_end_node) {
                num_winning_nodes += 1;
            }
            startNodesList.items[i] = try startNodesList.items[i].next(inst, &map);
        }

        if (num_winning_nodes == startNodesList.items.len) {
            found = true;
            break;
        }
    }

    if (found) {
        std.debug.print("Found solution : {d}\n", .{pc - 1});
        return;
    }
    std.debug.print("Done!\nStarting circle iteration...\n", .{});

    var circleIterators = ArrayList(CircleIterator).init(allocator);
    defer circleIterators.deinit();

    for (circles.items) |circle| {
        try circleIterators.append(circle.iterator(max_offset));
    }

    // pc -= 1;
    // const next = try circleIterators.items[0].next();
    // std.debug.print("Next expected {d}\n", .{next});
    // while (pc < next) : (pc += 1) {
    //     if (startNodesList.items[0].is_end_node) {
    //         std.debug.print("Fail! {}\n", .{pc});
    //         return;
    //     }
    //     const inst = map.instructions.items[pc % map.instructions.items.len];
    //     startNodesList.items[0] = try startNodesList.items[0].next(inst, &map);
    // }

    // if (!startNodesList.items[0].is_end_node) {
    //     std.debug.print("Fail!\n", .{});
    //     return;
    // }

    var max: usize = max_offset + 1;
    while (true) {
        var i: usize = 0;
        var win_count: usize = 0;
        while (i < circleIterators.items.len) : (i += 1) {
            while (circleIterators.items[i].pc < max) {
                _ = try circleIterators.items[i].next();
            }
            const curr_pc = circleIterators.items[i].pc;
            if (curr_pc == max) {
                win_count += 1;
            } else {
                max = curr_pc;
            }
        }
        if (win_count == circleIterators.items.len) {
            break;
        }
    }

    std.debug.print("\n\n MAX: {d}\n", .{max});
}

test "simple test" {
    const allocator = std.testing.allocator;

    var map: Map = Map.init(allocator);
    defer map.deinit();

    var lines = std.mem.tokenizeAny(u8, test_input, "\n\r");
    const instructions = lines.next().?;

    for (instructions) |ch| {
        const str: [1]u8 = .{ch};
        const enm = std.meta.stringToEnum(Instruction, &str).?;
        try map.add_instruction(enm);
        std.debug.print("{s}", .{@tagName(enm)});
    }
    std.debug.print("\n", .{});

    var node: *Node = undefined;
    var init: bool = false;
    var goal: u32 = 0;
    while (lines.next()) |line| {
        var names = std.mem.tokenizeAny(u8, line, "(),= \n\r");
        const name = names.next().?;
        goal = get_uid(name);

        const curr = try map.add_node(
            name,
            names.next().?,
            names.next().?,
        );
        if (!init) {
            node = curr;
            init = true;
        }
    }

    var pc: usize = 0;
    while (node.uid != goal) : (pc += 1) {
        const inst: Instruction = map.instructions.items[pc % map.instructions.items.len];
        switch (inst) {
            Instruction.L => node = try node.left.get_node(&map),
            Instruction.R => node = try node.right.get_node(&map),
        }
    }
    std.debug.print("Steps: {d}", .{pc});
}
