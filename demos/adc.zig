//! The ADC is ananalogue to digital converter.
//! In the RP2040, it has 4 channels ADC0 to ADC3 which are each
//! attached to a pin. The ADC can read a voltage between the GND level
//! and the voltage level on the ADC_VREF pin.
//!
//! This voltage level is then converted into a 12 bit unsigned integer,
//! utilizing the full range from 0 to 4095.
//!
//! In this example, we're sampling the data on pin ADC0 and sending
//! the raw data via uart to a host pc.
//!

const std = @import("std");
const microzig = @import("microzig");
const rp2040 = microzig.hal;
const adc = rp2040.adc;
const time = rp2040.time;

pub fn main() !void {
    // First, initialize the ADC. This will not only reset the ADC component,
    // but will also boot up the ADC analog components in the RP2040. This
    // is required to sample data.
    adc.init();

    // Initialize a UART on the default pins to
    // send out data.
    const uart = rp2040.uart.UART.init(0, .{
        .baud_rate = 115200,
        .tx_pin = 0,
        .rx_pin = 1,
        .clock_config = rp2040.clock_config,
    });

    // Then, initialize the AIN0 channel
    // and route the pin function:
    const pot = adc.Input.ain0;
    pot.init();

    while (true) {
        // Then, simply use the channel function to read from the ADC.
        // This is using a "single shot" method, which will start the
        // sampling process, and will return when the sample is ready.
        // There are other ADC sampling methods which can give better
        // performance results, but they are usually only required in
        // specific applications. Most of the time, just sampling the
        // ADC with single shot mode is enough.
        const sample: u12 = pot.read();

        // Now send off the data and wait a bit, so the user won't be
        // be overwhelmed with data.
        try uart.writer().print("sample: {}\r\n", .{sample});
        time.sleepMs(1000);
    }
}
