//! This example demonstrates how to handle a mechanical button.
//!
//! You might have noticed that in the `button.zig` example,
//! the led sometimes behaves a little bit flaky. Some button presses
//! will make the LED blink rapidly or just not toggle at all.
//!
//! This isn't a problem in your code, but a property of mechanical
//! switches and buttons. They usually fling a metal piece around
//! and push it against a contact surface. This is fine for low
//! frequency sampling, but as our microcontroller samples several
//! thousand times per second, we will also measure the springy behaviour
//! of the metal piece:
//!
//! The piece will literally bouncy on the contact surface on impact,
//! releasing the contact several times before finally resting still
//! on the surface.
//!
//! There are several ways of handling this, both electrically, and in
//! software:
//!
//! One solution is to attach a capacitor to the button and physically
//! filter out high frequency signals. This is usually a nice solution,
//! but will bring our GPIO pin into illegal states, thus requiring a
//! schmitt trigger.
//!
//! Another option is reduce the sample rate to very low values
//! like 10 Hz or even lower. This will have the problem that we're
//! having latencies on the input, which is sometimes not wanted.
//!
//! In this example, we're showing a pretty simple and stable method
//! that can filter glitches on both pressing and releasing the button,
//! while still retaining a relativly high sample rate.
//!
//! The functionality of this example is the same as in `button.zig`.
//!
//! Prerequisites: `button.zig`
//!

const std = @import("std");
const microzig = @import("microzig");
const rp2040 = microzig.hal;
const gpio = rp2040.gpio;

const led = 25;
const button = 9;

pub fn main() void {
    // see blinky.zig and button.zig for an explanation here:
    gpio.reset();
    gpio.setFunction(led, .sio);
    gpio.setFunction(button, .sio);
    gpio.setDir(led, .out);
    gpio.setDir(button, .in);
    gpio.setPullUpDown(button, .up);

    // This variable will be used as a glitch filter, or sliding window.
    // We will sample our button states into the filter and will
    // only react to (filter != 0) and (filter == 0) states.
    // This way, a switch from false to true is quickly detected,
    // but the state will be held for 16 samples. Only after 16 `0`s are
    // sampled, the state will switch back.
    //
    // Adjusting the integer size will increase/decrease the
    // sensitivity of the glitch filter.
    var glitch_filter: u16 = 0;

    var last_button_pressed: bool = false;
    while (true) {
        // advance the glitch filter by one binary digit
        glitch_filter <<= 1;
        if (gpio.read(button) == 0) {
            // if the button is currently pressed,
            // shift a bit into the filter. This way,
            // the filter will be != 0 for 16 samples.
            glitch_filter |= 1;
        }
        // and finally check if we have any bit set in our
        // glitch filter. A improved, but more complex variant
        // can use @popCount to check if there are more than half
        // of the bits set.
        const button_pressed = (glitch_filter != 0);

        // same logic as in `button.zig` from here on:

        defer last_button_pressed = button_pressed;

        if (button_pressed != last_button_pressed and button_pressed) {
            gpio.toggle(led);
        }

        // delay a little bit, so we don't have 100 MHz sample rate
        rp2040.time.sleepUs(10);
    }
}
