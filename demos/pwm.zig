//! The PWM is a counter that increments once every clock until it reaches
//! a certain limit. When that limit is hit, the counter is reset to 0.
//! This behaviour is called a PWM slice. Each slice has also two channels.
//! Each Channel (a and b) has a level value. As soon as the PWM hits that level
//! value, you can perform some actions, such as interrupts.
//! You can also configure a pin to be a "PWM channel output". This means:
//! - on counter reset, the pin is set to high level
//! - on counter level match, the pin is reset to low level
//! By this, you can generate square waves with a certain frequency and duty cycle.
//!
//! NOTE: Each pin has a fixed PWM slice and channel assigned, you can look these up
//! in the datasheet.
//!
//! In this example, we're going to use the PWM slice 4, channel b, which happens to be
//! attached to the LED pin (25). We're going to set a fixed frequency, and move the
//! duty cycle between 0% and 50% forth and back. This way, the LED will slowly blink
//! in a smooth fashion.
//!

const std = @import("std");
const microzig = @import("microzig");
const rp2040 = microzig.hal;
const pwm = rp2040.pwm;
const time = rp2040.time;

pub fn main() void {
    // Don't forget to reset the PWM into a well-defined state
    rp2040.resets.reset(&.{.pwm});

    // We want the pwm to count from 0 to 10_000
    const pwm_limit = 10_000;
    // and we are using the system clock
    const sys_freq = comptime rp2040.clock_config.pll_sys.?.frequency();
    // and we want to achieve a well defined target frequency. This frequency defines
    // how often the PWM sweeps from 0 to 10_000 per second.
    const target_freq = 500; // Hz
    // The PWM increments its counter once per clock, so we need to have a much higher
    // input frequency:
    const increment_freq = pwm_limit * target_freq;
    // The PWM clock is derived from the system clock, and uses a divider to get its own
    // clock. Thus, we compute the divider here.
    // We're using @divExact as we want to trigger a compile error when the PWM frequency
    // cannot be perfectly hit.
    const divider = @divExact(sys_freq, increment_freq);

    // Now let's set up the PWM:

    var led_pwm = pwm.PWM(4, .b){}; // get a handle to PWM 4 Channel B

    // get the PWM slice from our channel handle and set up the values
    const slice = led_pwm.slice();
    slice.setClkDiv(divider, 0);
    slice.setWrap(pwm_limit);

    slice.enable(); // start the counter

    rp2040.gpio.setFunction(25, .pwm); // route the LED pin to the PWM output

    // Sweep the duty cycle up and down.
    // By using a delay of 250µs and a limit of 10_000, this loop will repeat
    // every 2.5 seconds.
    while (true) {
        var level: u16 = 0;
        while (level < pwm_limit / 2) : (level += 1) {
            led_pwm.setLevel(level);
            time.sleepUs(250);
        }

        while (level > 0) {
            level -= 1;
            led_pwm.setLevel(level);
            time.sleepUs(250);
        }
    }
}
