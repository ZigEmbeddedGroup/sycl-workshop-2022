const std = @import("std");
const microzig = @import("microzig");
const rp2040 = microzig.hal;
const adc = rp2040.adc;
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

const pot: adc.Input = .ain0;

pub fn main() void {
    adc.init();
    const uart = rp2040.uart.UART.init(0, .{
        .baud_rate = 115200,
        .tx_pin = 0,
        .rx_pin = 1,
        .clock_config = rp2040.clock_config,
    });

    rp2040.uart.initLogger(uart);

    pot.init();

    while (true) {
        std.log.info("{}", .{pot.read()});
        time.sleepMs(1000);
    }
}
