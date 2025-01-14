const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const binary = b.addExecutable(.{
        .name = "__change__",
        .root_source_file = b.path("src/main.zig"),
        // or (implicit LazyPath struct, w/ path field)
        // .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // build C and/or C++

    // Need use libc to C code build? uncomment below

    // binary.addIncludePath(Path.relative("myinclude"));
    // binary.addCSourceFile(.{ .file = Path.relative("src/main.c"), .flags = &.{ "-Wall", "-Wextra" } });
    // binary.addCSourceFiles(&.{ "foo.cc", "bar.cc" }, &.{ "-Wall", "-std=c++17" });

    // warning to mixing C and C++ code. Use same flags, but c++flags(exclusive) not working (e.g.: "-std=c++11")
    // binary.addCSourceFiles(&.{ "foo.cc", "bar.c" }, &.{ "-Wall", "-Werror" });

    // linking
    // binary.linklibC(); // get libc and c-stdlib
    // for C++
    // binary.linklibCpp(); // builtin llvm-libcxx/abi + libunwind (+ stl) + libc (avoid duplicate - no need linklibC())

    // copy binary from zig-cache to zig-out/bin [default]
    b.installArtifact(binary);

    // overwrite default output
    b.resolveInstallPrefix(b.fmt("zig-out/{s}/{s}", .{
        @tagName(binary.rootModuleTarget().cpu.arch),
        @tagName(optimize),
    }), .{});

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(binary);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc.`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", b.fmt("Run the {s} app", .{binary.name}));
    run_step.dependOn(&run_cmd.step);
}
