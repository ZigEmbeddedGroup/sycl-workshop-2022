const std = @import("std");
const rp2040 = @import("deps/rp2040/build.zig");
const uf2 = @import("deps/uf2/src/main.zig");

const demos = .{
    "blinky", // done
    "button", // done
    "button-debounced", // done
    "uart", // done
    "pwm", // done
    "adc", // done
    "encoder", // done
    "interrupt",
};

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();

    inline for (demos) |demo| {
        var demo_exe = rp2040.addPiPicoExecutable(b, demo, "demos/" ++ demo ++ ".zig", .{});
        demo_exe.setBuildMode(mode);
        demo_exe.install();

        const uf2_step = uf2.Uf2Step.create(demo_exe.inner, .{ .family_id = .RP2040 });
        uf2_step.install();
    }

    var solution_exe = rp2040.addPiPicoExecutable(b, "solution", "solution/solution.zig", .{});
    solution_exe.setBuildMode(mode);
    solution_exe.install();

    const uf2_step = uf2.Uf2Step.create(solution_exe.inner, .{ .family_id = .RP2040 });
    uf2_step.install();
}
