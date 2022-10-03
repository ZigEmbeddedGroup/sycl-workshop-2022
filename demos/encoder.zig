//! This example demonstrates how to handle a rotary encoder.
//!
//! A rotary encoder creates a quadrature signal, which works basically like that:
//!
//! You have two inputs, A and B. They always change their state from low to high
//! or high to low consecutively:
//!
//! When turning clockwise, A will follow B:
//!
//!   A ▁▁▁╱▔▔▔╲▁▁▁╱▔▔▔╲▁▁▁╱▔▔▔╲▁▁▁╱▔▔▔╲▁▁▁
//!
//!   B ▁╱▔▔▔╲▁▁▁╱▔▔▔╲▁▁▁╱▔▔▔╲▁▁▁╱▔▔▔╲▁▁▁▁▁
//!
//! When turning counter-clockwise, B will follow A:
//!
//!   A ▁╱▔▔▔╲▁▁▁╱▔▔▔╲▁▁▁╱▔▔▔╲▁▁▁╱▔▔▔╲▁▁▁▁▁
//!
//!   B ▁▁▁╱▔▔▔╲▁▁▁╱▔▔▔╲▁▁▁╱▔▔▔╲▁▁▁╱▔▔▔╲▁▁▁
//!
//! We now need to decode this signal and recognize which of both lanes initiated the change.
//!
//! Prerequisites: `uart.zig`, `button-debounced.zig`
//!

const std = @import("std");
const microzig = @import("microzig");
const rp2040 = microzig.hal;
const gpio = rp2040.gpio;

// Set up logging via UART
pub const log = rp2040.uart.log;
pub const log_level = .debug;

const enc_a = 12;
const enc_b = 13;

pub fn main() void {
    // see blinky.zig and button.zig for an explanation of this:
    gpio.reset();
    gpio.setFunction(enc_a, .sio);
    gpio.setFunction(enc_b, .sio);
    gpio.setPullUpDown(enc_a, .up);
    gpio.setPullUpDown(enc_b, .up);
    gpio.setDir(enc_a, .in);
    gpio.setDir(enc_b, .in);

    // see uart.zig for an explanation of this:
    const uart = rp2040.uart.UART.init(0, .{
        .baud_rate = 115200,
        .tx_pin = 0,
        .rx_pin = 1,
        .clock_config = rp2040.clock_config,
    });
    rp2040.uart.initLogger(uart);

    // the encoder provides us with two inputs, so we need two glitch filters
    const filter_size = 8;
    var gf_a: std.meta.Int(.unsigned, filter_size) = 0;
    var gf_b: std.meta.Int(.unsigned, filter_size) = 0;

    // we need to store the state of our lanes so we can
    // detect changes
    var prev_state_a: bool = false;
    var prev_state_b: bool = false;

    std.log.info("ready.", .{});

    while (true) {
        gf_a <<= 1;
        gf_b <<= 1;
        if (gpio.read(enc_a) == 0) gf_a |= 1;
        if (gpio.read(enc_b) == 0) gf_b |= 1;

        const state_a = (@popCount(gf_a) >= (filter_size / 2));
        const state_b = (@popCount(gf_b) >= (filter_size / 2));
        defer {
            prev_state_a = state_a;
            prev_state_b = state_b;
        }

        // decode the rotary decoder here:

        // if we had a change,
        if (prev_state_a != state_a or prev_state_b != state_b) {
            const idle = (state_a == state_b);
            const prev_idle = (prev_state_a == prev_state_b);

            // and if we transitioned from (a == b) to (a != b)
            if (prev_idle != idle and !idle) {

                // then check, which lane changed.
                // As we just had a transition from "idle" to "change",
                // only a single lane can be active.
                const changed_a = (state_a != prev_state_a);
                const changed_b = (state_b != prev_state_b);
                std.debug.assert(changed_a != changed_b);

                // Now just select which direction we're going.
                // Done!
                if (changed_b) {
                    // B is leading A (changing before)
                    std.log.info("step increment", .{});
                } else {
                    // A is leading B (changing before)
                    std.log.info("step decrement", .{});
                }
            }
        }

        // delay a little bit, so we don't have 100 MHz sample rate
        rp2040.time.sleepUs(10);
    }
}
