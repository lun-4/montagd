const std = @import("std");

const c = @cImport({
    @cInclude("gd.h");
});

const log = std.log.scoped(.montagd);
pub extern "c" fn fdopen(fd: c_int) ?*c.FILE;

pub fn main() !void {
    var image = c.gdImageCreateTrueColor(1024, 512);
    defer _ = c.gdImageDestroy(image);

    c.gdImageFill(image, 0, 0, c.gdImageColorAllocateAlpha(image, 0, 0, 0, 127));

    var args_it = std.process.args();
    _ = args_it.skip(); // skip arg0
    var a: c_int = 0;
    var target_file: ?[*:0]const u8 = null;

    while (args_it.next()) |arg| {
        log.debug("arg: {s} ({d} out of {d})", .{
            arg,
            args_it.inner.index,
            args_it.inner.count,
        });
        if (std.mem.startsWith(u8, arg, "-")) {
            // this is an arg, ignore it, and ignore the next one too
            if (!args_it.skip()) return error.ExpectedOptionToIgnore;
            log.debug("skip!", .{});
        } else if (args_it.inner.index == args_it.inner.count) {
            log.debug("target = {s}", .{arg});
            target_file = arg;
        } else {
            log.debug("processing {s}", .{arg});
            //var file = try std.fs.openFileAbsolute(arg, .{ .mode = .read_only });
            //defer file.close();

            //const c_file = fdopen(file.handle);

            const c_file = std.c.fopen(arg, "r");

            if (c_file == null) return error.FailedToOpenFile;
            defer _ = if (c_file) |f| std.c.fclose(f);

            log.debug("open", .{});
            var incoming_image = c.gdImageCreateFromWebp(@as(?*c.FILE, @ptrCast(@alignCast(c_file))));
            defer c.gdImageDestroy(incoming_image);

            log.debug("alpha blend", .{});
            c.gdImageAlphaBlending(incoming_image, c.GD_TRUE);

            log.debug("copy resample", .{});
            c.gdImageCopyResampled(
                image,
                incoming_image,
                @mod(a, @as(c_int, 8)) * 128,
                @divTrunc(a, 8) * 128,
                0,
                0,
                128,
                128,
                c.gdImageSX(incoming_image),
                c.gdImageSY(incoming_image),
            );

            a += 1;
        }
    }

    c.gdImageSaveAlpha(image, c.GD_TRUE);
    log.debug("writing final file {?s}", .{target_file});

    const c_file = std.c.fopen(target_file orelse return error.ExpectedLastArg, "w");

    if (c_file == null) return error.FailLastArg;
    defer _ = if (c_file) |f| std.c.fclose(f);

    log.debug("open", .{});

    c.gdImagePng(image, @as(?*c.FILE, @ptrCast(@alignCast(c_file))));
}
