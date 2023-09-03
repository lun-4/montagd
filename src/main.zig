const std = @import("std");

const c = @cImport({
    @cInclude("gd.h");
});

const log = std.log.scoped(.montagd);
pub extern "c" fn fdopen(fd: c_int) ?*c.FILE;
pub extern "c" fn fileno(stream: ?*std.c.FILE) std.os.fd_t;

const RIFF_HEADER = "RIFF";
const JPEG_HEADER = "\xff\xd8\xff";
const PNG_HEADER = "\x89\x50\x4e\x47\x0d\x0a\x1a\x0a";

const ImageType = enum { PNG, JPEG, WEBP };

pub fn imageTypeFromFile(file: std.fs.File) !ImageType {
    var header_buffer: [16]u8 = undefined;

    const read_bytes = try file.read(&header_buffer);
    try file.seekTo(0);
    const header = header_buffer[0..read_bytes];

    const result: ImageType = if (std.mem.startsWith(u8, header, RIFF_HEADER))
        .WEBP
    else if (std.mem.startsWith(u8, header, JPEG_HEADER))
        .JPEG
    else if (std.mem.startsWith(u8, header, PNG_HEADER))
        .PNG
    else
        return error.InvalidFormat;

    log.debug("image type {}", .{result});
    return result;
}

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
            // TODO check errno

            if (c_file == null) {
                log.err("failed to open {s}, got {}", .{ arg, std.c.getErrno(-1) });

                return error.FailedToOpenFile;
            }
            defer _ = if (c_file) |f| std.c.fclose(f);

            const real_c_file = @as(?*c.FILE, @ptrCast(@alignCast(c_file)));

            var file = std.fs.File{ .handle = fileno(c_file) };

            log.debug("open (fd={d})", .{file.handle});
            var incoming_image = switch (try imageTypeFromFile(file)) {
                .WEBP => c.gdImageCreateFromWebp(real_c_file),
                .JPEG => c.gdImageCreateFromJpeg(real_c_file),
                .PNG => c.gdImageCreateFromPng(real_c_file),
            };

            defer c.gdImageDestroy(incoming_image);
            if (incoming_image == null) return error.NoImage;

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
