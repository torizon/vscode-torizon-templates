const std = @import("std");
const log = std.log.scoped(.toradex);

// override the std implementation
pub const std_options = .{
    .log_level = .info,
};
pub fn main() void {
    log.info("Hello {s}!", .{"Torizon"});
    // output:
    // info(toradex): Hello Torizon!
}
