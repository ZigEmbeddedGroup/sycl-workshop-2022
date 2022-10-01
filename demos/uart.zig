const std = @import("std");
const microzig = @import("microzig");
const rp2040 = microzig.hal;
const time = rp2040.time;

pub const log = rp2040.uart.log;
pub const log_level = .debug;

pub fn panic(
    message: []const u8,
    _: ?*std.builtin.StackTrace,
    _: ?usize,
) noreturn {
    std.log.err("panic: {s}", .{message});
    @breakpoint();
    while (true) {}
}

pub fn main() void {
    const uart = rp2040.uart.UART.init(0, .{
        .baud_rate = 115200,
        .tx_pin = 0,
        .rx_pin = 1,
        .clock_config = rp2040.clock_config,
    });

    rp2040.uart.initLogger(uart);

    while (true) {
        std.log.info("hello world!", .{});
        time.sleepMs(1000);
        if (uart.isReadable())
            @panic("I'M NOT LISTENING TO YOUR DRIVEL");
    }
}
