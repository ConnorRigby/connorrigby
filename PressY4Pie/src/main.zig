const std = @import("std");
const stdio = @cImport({
    @cInclude("stdio.h");
});

const termios = @cImport({
    @cInclude("termios.h");
});

const unistd = @cImport({
    @cInclude("unistd.h");
});

pub fn main() anyerror!void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Press Y\n", .{});

    var oldt: termios.termios = std.mem.zeroes(termios.termios);
    var newt = oldt;
    _ = termios.tcgetattr(unistd.STDIN_FILENO, &oldt);
    newt.c_lflag &= ~@bitCast(c_uint, termios.ICANON);
    _ = termios.tcsetattr(unistd.STDIN_FILENO, termios.TCSANOW, &newt);

    var input_buffer: [1]u8 = undefined;
    while(input_buffer[0] != 'y' and input_buffer[0] != 'Y') {
        _ = try stdin.read(input_buffer[0..]);
    }
    try stdout.print("🥧\n", .{});
    _ = termios.tcsetattr(unistd.STDIN_FILENO, termios.TCSANOW, &oldt);
}
