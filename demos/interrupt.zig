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
//! * blinky
//! * button
//!

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
const threshold_ms: u32 = std.time.ms_per_s / 30;
const init_period_ms: u32 = 1000;

var interrupt_happened: u32 = 0;
var delay_period_ms: u32 = init_period_ms;

pub const interrupts = struct {
    pub fn IO_IRQ_BANK0() void {
        // this isn't really required in this example, but if there were
        // other interrupts that accessed the shared variable, it's
        // possible that they might preempt this interrupt.
        cpu.cli();
        defer cpu.sei();

        // decrement the blinking period a bit
        const new_period = volatileRead(&delay_period_ms) - 200;
        volatileWrite(&delay_period_ms, if (new_period < threshold_ms)
            init_period_ms
        else
            new_period);

        volatileWrite(&interrupt_happened, 1);

        // Acknowledge the interrupt to the CPU, and tell it
        // we handled it. If we don't do that, the interrupt is immediatly
        // invoked again after the return.
        regs.IO_BANK0.INTR1.modify(.{ .GPIO9_EDGE_LOW = 1 });
    }
};

pub fn main() void {
    gpio.reset();

    // see blinky.zig for an explanation here:
    gpio.setFunction(led, .sio);
    gpio.setFunction(button, .sio);
    gpio.setDir(led, .out);
    gpio.setDir(button, .in);
    gpio.setPullUpDown(button, .up);

    // here's an example of writing directly to a register
    regs.IO_BANK0.PROC0_INTE1.modify(.{ .GPIO9_EDGE_LOW = 1 });

    // initialize nvic and tell it to route the
    // IO_IRQ_BANK0 into our code
    irq.enable("IO_IRQ_BANK0");

    // lfg
    cpu.sei();
    while (true) {
        // we use a block here to minimize the time interrupts are
        // disabled.
        const delay_ms = blk: {
            cpu.cli();
            defer cpu.sei();

            break :blk volatileRead(&delay_period_ms);
        };

        gpio.toggle(led);
        sleepMsInterruptible(delay_ms);
    }
}

// Use a variant of the sleep routine here that can be interrupted
// by our ... interrupt.
// This gives us immediate feedback on when the user clicks the button
// and not like 990ms later, the LED will start blinking twice as fast.
fn sleepMsInterruptible(delay_ms: u32) void {
    const end_time = time.Absolute{
        .us_since_boot = time.getTimeSinceBoot().us_since_boot + 1000 * @as(u64, delay_ms),
    };

    volatileWrite(&interrupt_happened, 0);
    while (!time.reached(end_time)) {
        if (volatileRead(&interrupt_happened) != 0)
            return;
    }
}

// Aux function to do a guaranteed read from a variable
// that won't be optimized away.
fn volatileRead(ptr: *volatile u32) u32 {
    return ptr.*;
}

// Aux function to do a guaranteed write to a variable.
fn volatileWrite(ptr: *volatile u32, value: u32) void {
    ptr.* = value;
}
