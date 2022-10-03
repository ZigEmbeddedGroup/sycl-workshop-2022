const std = @import("std");
const rp2040 = @import("deps/rp2040/build.zig");
const uf2 = @import("deps/uf2/src/main.zig");

const demos = .{
    "blinky", // done
    "button", // done
    "button-debounced", // done
    "uart",
    "pwm", // done
    "adc", // done
    "encoder",
    "interrupt",
    "solution",
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

        const dump_step = b.addSystemCommand(&.{"./dump.sh"});
        dump_step.addArg(b.getInstallPath(exe.inner.install_step.?.dest_dir, demo));
        dump_step.step.dependOn(&exe.inner.install_step.?.step);
        b.getInstallStep().dependOn(&dump_step.step);
    }
}
