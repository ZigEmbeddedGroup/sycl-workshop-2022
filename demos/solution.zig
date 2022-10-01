const std = @import("std");
const microzig = @import("microzig");
const rp2040 = microzig.hal;
const time = rp2040.time;

const drivers = struct {
    const quadrature = @import("microzig.quadrature");
    const button = @import("microzig.button");
};

const uart_id = 0;
const baud_rate = 115200;
const uart_tx_pin = 0;
const uart_rx_pin = 1;

pub const log_level = .info;
pub const log = rp2040.uart.log;

const pin_config = rp2040.pins.GlobalConfiguration{
    // serial port
    // .GPIO0 = .{
    //     .name = "uart_tx",
    //     .function = .UART0_TX,
    // },
    // .GPIO1 = .{
    //     .name = "uart_rx",
    //     .function = .UART0_RX,
    // },

    // Digital outputs:
    .GPIO25 = .{
        .name = "led",
        .direction = .out,
    },

    // PWM outputs:
    .GPIO10 = .{
        .name = "servo",
        .direction = .out,
        // .function = .PWM5_A,
        .function = .SIO,
    },

    // Analog inputs:
    // .GPIO26 = .{
    //     .name = "poti",
    //     .function = .ADC0,
    // },

    // Digital inputs:
    .GPIO12 = .{
        .name = "rot_a",
        .direction = .in,
        .pull = .up,
    },
    .GPIO13 = .{
        .name = "rot_b",
        .direction = .in,
        .pull = .up,
    },
    .GPIO18 = .{
        .name = "rot_btn",
        .direction = .in,
        .pull = .up,
    },
};

const ControlMode = enum {
    absolute, // using the potentiometer
    relative, // using the rotary encoder
};

const poti: rp2040.adc.Input = .ain0;

const pwm: rp2040.pwm.PWM(5, .a) = .{};

const pwm_limit = 50_000;
comptime {
    _ = @as(u16, pwm_limit); // assert pwm_limit is in range for a u16, but keep it a comptime_int
}

fn mapToPwm(comptime T: type, value: T) u16 {
    const low = @divExact(pwm_limit, 20); // 1ms
    const high = 2 * low; // 2 ms

    const delta = high - low;
    if (delta == 0)
        @compileError("Cannot map to a small range.");

    const mapped_value = @as(u32, delta) * @as(u32, value) / @as(u32, std.math.maxInt(T));

    return @truncate(u16, low + mapped_value);
}

pub fn main() !void {
    const pins = pin_config.apply();

    var button = makeButton(pins.rot_btn, 0, null);
    var quadrature_decoder = makeDecoder(pins.rot_a, pins.rot_b);

    const uart = rp2040.uart.UART.init(uart_id, .{
        .baud_rate = baud_rate,
        .tx_pin = uart_tx_pin,
        .rx_pin = uart_rx_pin,
        .clock_config = rp2040.clock_config,
    });

    rp2040.uart.initLogger(uart);

    std.log.info("clocks enabled (wake):  {X:0>8}", .{microzig.chip.registers.CLOCKS.WAKE_EN0.raw});
    std.log.info("clocks enabled (sleep): {X:0>8}", .{microzig.chip.registers.CLOCKS.SLEEP_EN0.raw});
    std.log.info("clocks enabled (real):  {X:0>8}", .{microzig.chip.registers.CLOCKS.ENABLED0.raw});

    std.log.info("initialize pwm...", .{});

    {
        pins.servo.put(1);
        rp2040.resets.reset(&.{.pwm});

        const slice = pwm.slice();

        const sys_freq = comptime rp2040.clock_config.pll_sys.?.frequency();

        const target_freq = 50; // Hz

        const increment_freq = pwm_limit * target_freq;

        const divider = @divExact(sys_freq, increment_freq); // compile error on imperfect scaling

        // @compileLog(limit, sys_freq, target_freq, increment_freq, divider);

        slice.setClkDiv(divider, 0);
        slice.setWrap(pwm_limit);
        slice.setPhaseCorrect(false);

        pwm.setLevel(5_000);

        // rp2040.pwm.setChannelInversion(5, .a, true);

        slice.enable();

        rp2040.gpio.setFunction(10, .pwm);
    }

    // std.log.info("initialize adc...", .{});
    // {
    //     microzig.chip.registers.CLOCKS.WAKE_EN0.modify(.{
    //         .clk_sys_adc = 1,
    //     });

    //     rp2040.adc.init();
    //     poti.init();
    // }

    std.log.info("ready.", .{});

    var current_mode: ControlMode = .absolute;
    var current_position: u12 = 0; // using adc range here for position storage
    var main_loop_timer = ConstantTimeLoop.init(10); // 10 us tick time

    while (true) {
        defer main_loop_timer.waitCompleted(); // make sure we're always waiting for the timer to complete, even in case of continue or break.

        switch (button.tick()) {
            .idle => {},
            .pressed => {
                current_mode = switch (current_mode) {
                    .absolute => .relative,
                    .relative => .absolute,
                };

                _ = quadrature_decoder.tick(); // swallow event that might be "lingering" when switching modes

                std.log.info("new mode: {s}", .{@tagName(current_mode)});
            },
            .released => {},
        }

        // Position control:
        const previous_position = current_position;
        current_position = switch (current_mode) {
            .absolute => current_position +% 3, // poti.read(),
            .relative => switch (quadrature_decoder.tick()) {
                .idle => current_position,
                .increment => current_position +| 10,
                .decrement => current_position -| 10,
            },
        };

        if (previous_position != current_position) {
            std.log.info("new position: {}", .{current_position});
        }

        pwm.setLevel(mapToPwm(u12, current_position));

        // // TODO: Set servo position

        // Set LED mode:
        switch (current_mode) {
            // LED constantly on
            .absolute => pins.led.put(1),

            // LED blinking with 2 Hz
            .relative => pins.led.put(@boolToInt(time.getTimeSinceBoot().us_since_boot % 500_000 >= 250_000)),
        }
    }
}

/// A timer construct that allows building loops that run
/// with a fixed update rate.
const ConstantTimeLoop = struct {
    last_loop_start: time.Absolute,
    tick_period: u32,

    pub fn init(period_us: u32) ConstantTimeLoop {
        return .{
            .last_loop_start = time.getTimeSinceBoot(),
            .tick_period = period_us,
        };
    }

    pub fn waitCompleted(timer: *ConstantTimeLoop) void {
        timer.last_loop_start.us_since_boot += timer.tick_period; // this will overflow after over 500 000 years of constant operation, we're definitly safe.
        while (!time.reached(timer.last_loop_start)) {
            asm volatile ("" ::: "memory"); // do not optimize loop away!
        }
    }
};

pub const QuadratureEvent = enum {
    /// No change since the last decoding happened
    idle,
    /// The quadrature signal incremented a step.
    increment,
    /// The quadrature signal decremented a step.
    decrement,
};

pub fn makeDecoder(pin_a: anytype, pin_b: anytype) Decoder(@TypeOf(pin_a), @TypeOf(pin_b)) {
    return Decoder(@TypeOf(pin_a), @TypeOf(pin_b)).init(pin_a, pin_b);
}

pub fn Decoder(comptime PinA: type, comptime PinB: type) type {
    return struct {
        const Self = @This();

        a: PinA,
        b: PinB,
        last_a: u1,
        last_b: u1,

        pub fn init(a: PinA, b: PinB) Self {
            var self = Self{
                .a = a,
                .b = b,
                .last_a = undefined,
                .last_b = undefined,
            };

            self.last_a = self.a.read();
            self.last_b = self.b.read();

            return self;
        }

        pub fn tick(self: *Self) QuadratureEvent {
            const a = self.a.read();
            const b = self.b.read();
            defer self.last_a = a;
            defer self.last_b = b;

            const enable = a ^ b ^ self.last_a ^ self.last_b;
            const direction = a ^ self.last_b;

            if (enable != 0) {
                if (direction != 0) {
                    return .increment;
                } else {
                    return .decrement;
                }
            } else {
                return .idle;
            }
        }
    };
}

pub const ButtonEvent = enum {
    /// Nothing has changed.
    idle,

    /// The button was pressed. Will only trigger once per press.
    /// Use `Button.isPressed()` to check if the button is currently held.
    pressed,

    /// The button was released. Will only trigger once per release.
    /// Use `Button.isPressed()` to check if the button is currently held.
    released,
};

pub fn makeButton(pin: anytype, comptime active_state: u1, filter_depth: ?comptime_int) Button(@TypeOf(pin), active_state, filter_depth) {
    return Button(@TypeOf(pin), active_state, filter_depth).init(pin);
}

pub fn Button(
    /// The GPIO pin the button is connected to. Will be initialized when calling Button.init
    comptime Pin: type,
    /// The active state for the button. Use `.high` for active-high, `.low` for active-low.
    comptime active_state: u1,
    /// Optional filter depth for debouncing. If `null` is passed, 16 samples are used to debounce the button,
    /// otherwise the given number of samples is used.
    comptime filter_depth: ?comptime_int,
) type {
    return struct {
        const Self = @This();
        const DebounceFilter = std.meta.Int(.unsigned, filter_depth orelse 16);

        pin: Pin,
        debounce: DebounceFilter,
        state: u1,

        pub fn init(pin: Pin) Self {
            return Self{
                .pin = pin,
                .debounce = 0,
                .state = pin.read(),
            };
        }

        /// Polls for the button state. Returns the change event for the button if any.
        pub fn tick(self: *Self) ButtonEvent {
            const state = self.pin.read();
            const active_unfiltered = (state == active_state);

            const previous_debounce = self.debounce;
            self.debounce <<= 1;
            if (active_unfiltered) {
                self.debounce |= 1;
            }

            if (active_unfiltered and previous_debounce == 0) {
                return .pressed;
            } else if (!active_unfiltered and self.debounce == 0 and previous_debounce != 0) {
                return .released;
            } else {
                return .idle;
            }
        }

        /// Returns `true` when the button is pressed.
        /// Will only be updated when `poll` is regularly called.
        pub fn read(self: *Self) u1 {
            return @boolToInt(self.debounce != 0);
        }
    };
}
