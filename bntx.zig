const std = @import("std");

pub const BNTX = extern struct {
    const Self = @This();
    // zig fmt: off
    Magic: [8]u8,
    DataLength    : u32,
    ByteOrderMark : u16,
    FormatRevision: u16,
    NameAddress   : u32,
    StringsAddress: u32,
    RelocAddress  : u32,
    FileLength    : u32,
    // zig fmt: on
    pub fn init(bytes: *const [@sizeOf(Self)]u8) error{NotBNTX}!Self {
        var v: Self = @bitCast(bytes.*);
        if (!std.mem.eql(u8, "BNTX\x00\x00\x00\x00", &v.Magic)) return error.NotBNTX;
        const bom = v.ByteOrderMark;
        if (bom != 0xfeff) std.mem.byteSwapAllFields(Self, &v);
        v.ByteOrderMark = bom;
        v.StringsAddress >>= 16;
        return v;
    }
};

pub const NX = extern struct {
    const Self = @This();
    // zig fmt: off
    Magic: [4]u8,
    TexturesCount  : u32,
    InfoPtrsAddress: u64,
    DataBlkAddress : u64,
    DictAddress    : u64,
    StrDictLength  : u32,
    // zig fmt: on
    pub fn init(bytes: *const [@sizeOf(Self)]u8, bom: u16) error{NotNX}!Self {
        var v: Self = @bitCast(bytes.*);
        if (!std.mem.eql(u8, "NX  ", &v.Magic)) return error.NotNX;
        if (bom != 0xfeff) std.mem.byteSwapAllFields(Self, &v);
        return v;
    }
};

pub const BRTI = extern struct {
    const Self = @This();
    // zig fmt: off
    Magic: [4]u8,
    BRTILength0     : u32,
    BRTILength1     : u64,
    Flags           : u8,
    Dimensions      : u8,
    TileMode        : u16,
    SwizzleSize     : u16,
    MipmapCount     : u16,
    MultiSampleCount: u16,
    _1: u16, // 1A
    FormatVariant   : TextureFormatVar,
    FormatType      : TextureFormatType,
    _2: u16, // 20
    AccessFlags     : u32,
    Width           : u32,
    Height          : u32,
    Depth           : u32,
    ArrayCount      : u32,
    GobHeightLog2   : u32,
    _3: [6]u32, // 38-4C
    DataLength      : u32,
    Alignment       : u32,
    ChannelTypes    : [4]ChannelType,
    TextureType     : TextureType,
    NameAddress     : u64,
    ParentAddress   : u64,
    PtrsAddress     : u64,
    // zig fmt: on
    pub fn init(bytes: *const [@sizeOf(Self)]u8, bom: u16) error{NotBRTI}!Self {
        var v: Self = @bitCast(bytes.*);
        if (!std.mem.eql(u8, "BRTI", &v.Magic)) return error.NotBRTI;
        if (bom != 0xfeff) std.mem.byteSwapAllFields(Self, &v);
        return v;
    }
    pub fn getSwizzle(self: *const Self) !Swizzle {
        return Swizzle.init(
            self.Width,
            self.FormatType.getBlkWidth(),
            @intCast(self.FormatType.getBppLog2()),
            @intCast(self.GobHeightLog2),
        );
    }
    pub fn getWHInBlks(self: *const Self) struct { usize, usize } {
        return .{
            std.math.divCeil(usize, self.Width, self.FormatType.getBlkWidth()) catch 0,
            std.math.divCeil(usize, self.Height, self.FormatType.getBlkHeight()) catch 0,
        };
    }
    pub fn getDataLen(self: *const Self) usize {
        const bw, const bh = self.getWHInBlks();
        return (bw * bh) << @intCast(self.FormatType.getBppLog2());
    }
};

pub const ChannelType = enum(u8) {
    // zig fmt: off
    Zero  = 0,
    One   = 1,
    Red   = 2,
    Green = 3,
    Blue  = 4,
    Alpha = 5,
    _,
    // zig fmt: on
};

pub const TextureType = enum(u32) {
    // zig fmt: off
    Image1D = 0,
    Image2D = 1,
    Image3D = 2,
    Cube    = 3,
    CubeFar = 8,
    _,
    // zig fmt: on
};

pub const TextureFormatVar = enum(u8) {
    // zig fmt: off
    UNorm  = 1,
    SNorm  = 2,
    UInt   = 3,
    SInt   = 4,
    Single = 5,
    SRGB   = 6,
    UHalf  = 10,
    _,
    // zig fmt: on
};

pub const TextureFormatType = enum(u8) {
    // zig fmt: off
    R5G6B5    = 0x07,
    R8G8      = 0x09,
    R16       = 0x0a,
    R8G8B8A8  = 0x0b,
    R11G11B10 = 0x0f,
    R32       = 0x14,
    BC1       = 0x1a,
    BC2       = 0x1b,
    BC3       = 0x1c,
    BC4       = 0x1d,
    BC5       = 0x1e,
    ASTC4x4   = 0x2d,
    ASTC5x4   = 0x2e,
    ASTC5x5   = 0x2f,
    ASTC6x5   = 0x30,
    ASTC6x6   = 0x31,
    ASTC8x5   = 0x32,
    ASTC8x6   = 0x33,
    ASTC8x8   = 0x34,
    ASTC10x5  = 0x35,
    ASTC10x6  = 0x36,
    ASTC10x8  = 0x37,
    ASTC10x10 = 0x38,
    ASTC12x10 = 0x39,
    ASTC12x12 = 0x3a,
    _,
    // zig fmt: on
    pub fn getBppLog2(self: @This()) u8 {
        return switch (self) {
            .R5G6B5, .R8G8, .R16 => 1,
            .R8G8B8A8, .R11G11B10, .R32 => 2,
            .BC1, .BC4 => 3,
            else => 4,
        };
    }
    pub fn getBlkWidth(self: @This()) u8 {
        return switch (self) {
            .BC1, .BC2, .BC3, .BC4, .BC5, .ASTC4x4 => 4,
            .ASTC5x4, .ASTC5x5 => 5,
            .ASTC6x5, .ASTC6x6 => 6,
            .ASTC8x5, .ASTC8x6, .ASTC8x8 => 8,
            .ASTC10x5, .ASTC10x6, .ASTC10x8, .ASTC10x10 => 10,
            .ASTC12x10, .ASTC12x12 => 12,
            else => 1,
        };
    }
    pub fn getBlkHeight(self: @This()) u8 {
        return switch (self) {
            .BC1, .BC2, .BC3, .BC4, .BC5, .ASTC4x4, .ASTC5x4 => 4,
            .ASTC5x5, .ASTC6x5, .ASTC8x5, .ASTC10x5 => 5,
            .ASTC6x6, .ASTC8x6, .ASTC10x6 => 6,
            .ASTC8x8, .ASTC10x8 => 8,
            .ASTC10x10, .ASTC12x10 => 10,
            .ASTC12x12 => 12,
            else => 1,
        };
    }
};

pub const Swizzle = struct {
    const Self = @This();
    const ShAmt = std.math.Log2Int(usize);
    wInGobs: usize,
    lg2GobH: ShAmt,
    lg2BppX: ShAmt,
    pub fn init(img_w: usize, blk_w: usize, log2_bppx: ShAmt, log2_gobh: ShAmt) !Self {
        const round_w = (std.math.divCeil(usize, img_w, blk_w) catch 0) * blk_w;
        return .{
            .wInGobs = std.math.divCeil(usize, round_w << log2_bppx, 1 << 6) catch 0,
            .lg2GobH = log2_gobh,
            .lg2BppX = log2_bppx,
        };
    }
    pub fn swiz(self: Self, x: usize, y: usize) usize {
        const xLow, const xLeft = depWithLeft(0b10010_1111, x << self.lg2BppX);
        const yLow, const yLeft = depWithLeft(0b01101_0000, y);
        return xLow + yLow +
            (((yLeft >> self.lg2GobH) * self.wInGobs + xLeft) << (9 + self.lg2GobH)) +
            ((yLeft % (@as(usize, 1) << self.lg2GobH)) << 9);
    }
};

fn depWithLeft(comptime mask: usize, v_: usize) struct { usize, usize } {
    var v = v_;
    var res: usize = 0;
    comptime var pow: usize = 1;
    inline while (pow != 0 and mask >= pow) {
        if (mask & pow != 0) {
            if (v & 1 != 0) res |= pow;
            v >>= 1;
        }
        pow <<= 1;
    }
    return .{ res, v };
}
