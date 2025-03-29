const std = @import("std");
const builtin = @import("builtin");
const net = @import("std").net;

pub const Socket = struct {
    _address: std.net.Address,
    _stream: std.net.Stream,

    pub fn init() !Socket {
        const addr = try net.Address.parseIp4("0.0.0.0", 8080);
        const socket = try std.posix.socket(addr.any.family, std.posix.SOCK.STREAM, std.posix.IPPROTO.TCP);
        const stream = net.Stream{ .handle = socket };
        return Socket{ ._address = addr, ._stream = stream };
    }
};
