const std = @import("std");
const lib = @import("./bntx.zig");

pub fn Slice(comptime T: anytype) type {
    return struct {
        const Self = @This();
        const Error = error{EOF};
        left: T,
        pub fn take(self: *Self, n: anytype) Error!@TypeOf(self.left[0..n]) {
            if (self.left.len < n) return Error.EOF;
            defer self.left = self.left[n..];
            return self.left[0..n];
        }
    };
}

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();
    _ = args.next();
    const i_name = args.next() orelse {
        std.debug.print("usage: <bntxfile> [outfile=INNAME-INDEX-WIDTHxHEIGHT-FORMAT.data]\n", .{});
        return error.NeedArgs;
    };
    const o_patt = args.next() orelse "INNAME-INDEX-WIDTHxHEIGHT-FORMAT.data";
    const i_repl = if (std.mem.indexOfScalar(u8, o_patt, std.fs.path.delimiter) == null and
        std.mem.startsWith(u8, o_patt, "INNAME")) i_name else std.fs.path.basename(i_name);
    const bytes = try std.fs.cwd().readFileAlloc(alloc, i_name, std.math.maxInt(usize));
    defer alloc.free(bytes);
    var pointer = Slice([]u8){ .left = bytes };
    const bntx = try lib.BNTX.init(try pointer.take(@sizeOf(lib.BNTX)));
    const nx = try lib.NX.init(try pointer.take(@sizeOf(lib.NX)), bntx.ByteOrderMark);
    const infoPtrs: [*]align(1) u64 = @ptrCast(bytes[nx.InfoPtrsAddress..]);
    for (0..nx.TexturesCount, infoPtrs) |i, infoPtr| {
        const brti = try lib.BRTI.init(bytes[infoPtr..][0..@sizeOf(lib.BRTI)], bntx.ByteOrderMark);
        const ptrs: [*]align(1) u64 = @ptrCast(bytes[brti.PtrsAddress..]);
        const swizz = bytes[ptrs[0]..];
        const unswi = try alloc.alloc(u8, brti.getDataLen());
        defer alloc.free(unswi);
        const swizzle = try brti.getSwizzle();
        const wb, const hb = brti.getWHInBlks();
        const log2bpp = brti.FormatType.getBppLog2();
        const len_bpp = @as(usize, 1) << @intCast(log2bpp);
        for (0..wb) |x| for (0..hb) |y| {
            const u_off = (y * wb + x) << @intCast(log2bpp);
            const s_off = swizzle.swiz(x, y);
            @memcpy(unswi[u_off..][0..len_bpp], swizz[s_off..][0..len_bpp]);
        };
        const outname = try makeOutName(alloc, i_repl, o_patt, &brti, i);
        defer alloc.free(outname);
        std.debug.print("[{}] {s} {}x{} -> {s}\n", .{ i, fmtName(brti.FormatType), brti.Width, brti.Height, outname });
        try std.fs.cwd().writeFile(.{ .sub_path = outname, .data = unswi });
    }
}

fn makeOutName(alloc: std.mem.Allocator, i_repl: []const u8, o_patt: []const u8, brti: *const lib.BRTI, i: usize) ![]u8 {
    var strTemp: [32]u8 = undefined;
    const n_INNAME = try std.mem.replaceOwned(u8, alloc, o_patt, "INNAME", i_repl);
    defer alloc.free(n_INNAME);
    const n_INDEX = try std.mem.replaceOwned(u8, alloc, n_INNAME, "INDEX", //
        std.fmt.bufPrintIntToSlice(&strTemp, i, 10, .lower, .{}));
    defer alloc.free(n_INDEX);
    const n_FORMAT = try std.mem.replaceOwned(u8, alloc, n_INDEX, "FORMAT", fmtName(brti.FormatType));
    defer alloc.free(n_FORMAT);
    const n_WIDTH = try std.mem.replaceOwned(u8, alloc, n_FORMAT, "WIDTH", //
        std.fmt.bufPrintIntToSlice(&strTemp, brti.Width, 10, .lower, .{}));
    defer alloc.free(n_WIDTH);
    const n_HEIGHT = try std.mem.replaceOwned(u8, alloc, n_WIDTH, "HEIGHT", //
        std.fmt.bufPrintIntToSlice(&strTemp, brti.Height, 10, .lower, .{}));
    return n_HEIGHT;
}

fn fmtName(fmt: lib.TextureFormatType) []const u8 {
    return switch (fmt) {
        .R5G6B5 => "R5G6B5",
        .R8G8 => "R8G8",
        .R16 => "R16",
        .R8G8B8A8 => "R8G8B8A8",
        .R11G11B10 => "R11G11B10",
        .R32 => "R32",
        .BC1 => "BC1",
        .BC2 => "BC2",
        .BC3 => "BC3",
        .BC4 => "BC4",
        .BC5 => "BC5",
        .ASTC4x4 => "ASTC4x4",
        .ASTC5x4 => "ASTC5x4",
        .ASTC5x5 => "ASTC5x5",
        .ASTC6x5 => "ASTC6x5",
        .ASTC6x6 => "ASTC6x6",
        .ASTC8x5 => "ASTC8x5",
        .ASTC8x6 => "ASTC8x6",
        .ASTC8x8 => "ASTC8x8",
        .ASTC10x5 => "ASTC10x5",
        .ASTC10x6 => "ASTC10x6",
        .ASTC10x8 => "ASTC10x8",
        .ASTC10x10 => "ASTC10x10",
        .ASTC12x10 => "ASTC12x10",
        .ASTC12x12 => "ASTC12x12",
        else => "unknown",
    };
}
