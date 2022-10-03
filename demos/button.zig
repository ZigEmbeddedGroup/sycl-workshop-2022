//!
//! This example demonstrates how to read from a GPIO pin.
//!
//! The functionality that is implemented:
//! A button is connected between GND and GP9. Every time the button
//! is pressed down, the LED of the pico should toggle.
//!
//! Prerequisites: `blinky.zig`
//!

const std = @import("std");
const microzig = @import("microzig");
const rp2040 = microzig.hal;
const gpio = rp2040.gpio;

const led = 25;
const button = 9;

pub fn main() void {
    // see blinky.zig for an explanation here:
    gpio.reset();
    gpio.setFunction(led, .sio);
    gpio.setFunction(button, .sio);
    gpio.setDir(led, .out);

    // the button is attached to a pin and ground, so
    // we set the direction to input, and enable a
    // pull up resistor. The pico has two optional resistors
    // per pin (called "pad"), which can either pull
    // a floating (unconnected) pin to VCC or GND.
    // Usually, pull-ups are used, and the inputs use a
    // active-low (pin state 0 is "active") mode. We're doing
    // exactly this here:
    gpio.setDir(button, .in);
    gpio.setPullUpDown(button, .up);

    var last_button_pressed: bool = false;
    while (true) {
        // fetch the pin state and invert the logic value, so
        // 0 gets true and 1 gets false.
        const button_pressed = (gpio.read(button) == 0);
        defer last_button_pressed = button_pressed;

        // Check if the pin was changed since the last time we checked,
        // and also check if the button is now pressed.
        // This way, we check if the user clicked the button.
        if (button_pressed != last_button_pressed and button_pressed) {
            gpio.toggle(led);
        }
    }
}
