//! Instead of polling our device for state, most of the peripherals/subsystems
//! have a corresponding interrupt handler function that is invoked when a
//! specific event takes place.
//!
//! There are caveats to using interrupts. One is that your program may be
//! preempted by an interrupt, so variables accessed both by regular code and
//! interrupts could lead to a data race. In order to protect against this, you
//! can disable all interrupts in your program as you access shared resources
//! (in both execution contexts).
//!
//! For MicroZig powered projects we can declare our interrupt handler
//! functions in a public `interrupts` namespace exported from your
//! application. The name of the handler must match the name of the interrupt,
//! you can find the vector table type in `deps/rp2040/src/rp2040.zig`
//! (register definitions). OR you can define a function with some random name
//! to get a compile error listing the available options for this
//! microcontroller.
//!
//! In our example, we'll do two things concurrently, we'll use an
//! interrupt to detect when the button on the encoder is pushed, that
//! will double the rate at which the LED blinks. Once a threshold is hit,
//! the rate of blinking will reset.
//!
//! Prerequisites:
//! * encoder
//! * pwm
//! * uart

const std = @import("std");
const microzig = @import("microzig");
const cpu = microzig.cpu;
const regs = microzig.chip.registers;
const rp2040 = microzig.hal;
const gpio = rp2040.gpio;
const irq = rp2040.irq;
const time = rp2040.time;

const led = 25;
const button = 9;

// stop when we've gotten to 30Hz
const threshold_ms: u32 = (30 / 2) * std.time.ms_per_s;
const init_period_ms: u32 = 1000;

var delay_period_ms: u32 = init_period_ms;

pub const interrupts = struct {
    pub fn IO_IRQ_BANK0() void {
        // this isn't really required in this example, but if there were
        // other interrupts that accessed the shared variable, it's
        // possible that they might preempt this interrupt.
        cpu.cli();
        defer cpu.sei();

        const new_period = delay_period_ms / 2;
        delay_period_ms = if (new_period < threshold_ms)
            init_period_ms
        else
            new_period;
    }
};

pub fn main() void {
    gpio.reset();

    // see blinky.zig for an explanation here:
    gpio.reset();
    gpio.setFunction(led, .sio);
    gpio.setFunction(button, .sio);
    gpio.setDir(led, .out);
    gpio.setDir(button, .in);
    gpio.setPullUpDown(button, .up);

    // here's an example of writing directly to a register
    regs.IO_BANK0.INTR1.modify(.{
        .GPIO9_EDGE_HIGH = 1,
    });

    // initialize nvic
    irq.enable("IO_IRQ_BANK0");

    // lfg
    cpu.sei();
    while (true) {
        // we use a block here to minimize the time interrupts are
        // disabled.
        const delay_ms = blk: {
            cpu.cli();
            defer cpu.sei();

            break :blk delay_period_ms;
        };

        gpio.toggle(led);
        time.sleepMs(delay_ms);
    }
}
