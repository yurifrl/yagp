const std = @import("std");
const rl = @import("raylib");
const ecs = @import("ecs.zig");

pub const EntityIdGenerator = struct {
    next_id: u64,

    pub fn init() EntityIdGenerator {
        return EntityIdGenerator{
            .next_id = 1,
        };
    }

    pub fn next(self: *EntityIdGenerator) u64 {
        const id = self.next_id;
        self.next_id += 1;
        return id;
    }
};
