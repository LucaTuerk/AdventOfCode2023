const std = @import("std");
const Allocator = std.mem.Allocator;

const ParseError = error {
    InvalidFormat
}

struct CubeSet {
    red : u32,
    green : u32,
    blue : u32,
}

struct Game {
    id : u32,
    sets : [] CubeSet,
    allocator: Allocator

    fn init( allocator : Allocator, set_count : usize ) !Game {
        var sets = try allocator.alloc(CubeSet, set_count);
        errdefer allocator.free(sets)

        return .{
            .id = -1,
            .sets = sets,
            .allocator = allocator
        }
    }

    fn deinit( game: Game ) void {
        const allocator = game.allocator;
        allocator.free(game.sets);
    }
}

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}

pub fn parse_game( in : [] const u8 ) !Game {
    
}

pub fn parse_game_id(in : [] const u8) !u32 {
    // assert game prefix and remove
    if( !std.mem.eql(u8, in[0..5], "Game ")) {
        return ParseError.InvalidFormat;
    }
    
    const integer_expected = in[5..];
    return std.fmt.parseInt(u32, integer_expected, 10);    
}

pub fn parse_game_set(in:[] const u8) !CubeSet {
    var in_splitted = std.mem.split(u8, in, ',');
    while( in_splitted.next() ) |split| {

        var pair = std.mem.split(u8, split, ' ');
        var expected_int = pair.next();
        var expected_col = pair.next();
        const case = enum {red,green,blue};
    }

}

//oh no
pub fn remove_spaces(in:[] const u8) [] const u8 {
    var low = 0;
    var overall_len = in.len;

    for(0..in.len) |i| {
        if( in[i] == ' ') {
            low++;
            overall_len--; // decease
        } else {
            break;
        }
    }

    for(in.len - 1 .. 0) |j| {
        if(in[j] == ' ') {
            overall_len--;
        } else {
            break;
        }
    }
    
    return in[low..overall_len]
}

test "parse_game" {
    const case = "Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green\nGame 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue\nGame 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red\nGame 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red\nGame 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green\n"

}
