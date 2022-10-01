const std = @import("std");
const rp2040 = @import("deps/rp2040/build.zig");
const uf2 = @import("deps/uf2/src/main.zig");

const demos = .{
    "blinky",
    "uart",
    "button",
    "interrupt",
    "pwm",
    "adc",
};

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();

    inline for (demos) |demo| {
        var exe = rp2040.addPiPicoExecutable(b, demo, "demos/" ++ demo ++ ".zig", .{});
        exe.setBuildMode(mode);
        exe.install();

        const uf2_step = uf2.Uf2Step.create(exe.inner, .{
            .family_id = .RP2040,
        });
        uf2_step.install();
    }
}
