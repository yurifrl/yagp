const std = @import("std");
const rl = @import("raylib");

// Core UI module
pub const UI = struct {
    allocator: std.mem.Allocator,
    frame: ?Frame = null,
    bottom_bar: ?BottomBar = null,
    inspector: ?Inspector = null,
    last_clicked_button: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator) UI {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *UI) void {
        if (self.bottom_bar != null) {
            self.bottom_bar.?.deinit();
        }
        if (self.inspector != null) {
            self.inspector.?.deinit();
        }
    }

    // Main render function
    pub fn render(self: *UI) void {
        if (self.frame) |frame| {
            frame.render();
        }

        if (self.bottom_bar) |*bar| {
            self.last_clicked_button = bar.render();
        }

        if (self.inspector) |*insp| {
            insp.render();
        }
    }

    // Create a frame with margins around window edges
    pub fn addFrame(self: *UI) *Frame {
        self.frame = Frame.init();
        return &self.frame.?;
    }

    // Create an inspector window
    pub fn addInspector(self: *UI, title: []const u8, x: i32, y: i32, width: i32, height: i32) !*Inspector {
        self.inspector = Inspector.init(self.allocator, title, x, y, width, height);
        return &self.inspector.?;
    }

    // Button item definition
    pub const BarItem = struct {
        id: []const u8,
        label: []const u8,
        color: rl.Color,
        // Optional fields
        icon: ?u32 = null,
    };

    // Initialize dynamic bottom bar
    pub fn initDynamicBar(self: *UI, height_mm: f32, button_size_mm: f32, spacing_mm: f32) void {
        self.bottom_bar = BottomBar.init(self.allocator, height_mm, button_size_mm, spacing_mm);
    }

    // Load all buttons at once
    pub fn loadButtons(self: *UI, items: []const BarItem) void {
        if (self.bottom_bar) |*bar| {
            bar.loadButtons(items);
        }
    }

    // Get ID of clicked button
    pub fn getClickedButton(self: UI) ?[]const u8 {
        return self.last_clicked_button;
    }
};

// Button state
const ButtonState = enum {
    Normal,
    Hovered,
    Pressed,
};

// Button in the bar
const Button = struct {
    id: []const u8,
    label: []const u8,
    label_z: [:0]const u8, // Null-terminated version for raylib
    color: rl.Color,
    icon: ?u32,
    state: ButtonState,

    fn init(allocator: std.mem.Allocator, item: UI.BarItem) !Button {
        const id_copy = try allocator.dupe(u8, item.id);
        const label_copy = try allocator.dupe(u8, item.label);
        const label_z = try allocator.dupeZ(u8, item.label); // Null-terminated

        return Button{
            .id = id_copy,
            .label = label_copy,
            .label_z = label_z,
            .color = item.color,
            .icon = item.icon,
            .state = .Normal,
        };
    }

    fn deinit(self: Button, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.label);
        allocator.free(self.label_z);
    }
};

// Bottom bar
const BottomBar = struct {
    allocator: std.mem.Allocator,
    buttons: std.ArrayList(Button),
    height_mm: f32,
    button_size_mm: f32,
    spacing_mm: f32,

    fn init(allocator: std.mem.Allocator, height_mm: f32, button_size_mm: f32, spacing_mm: f32) BottomBar {
        return BottomBar{
            .allocator = allocator,
            .buttons = std.ArrayList(Button).init(allocator),
            .height_mm = height_mm,
            .button_size_mm = button_size_mm,
            .spacing_mm = spacing_mm,
        };
    }

    fn deinit(self: *BottomBar) void {
        for (self.buttons.items) |button| {
            button.deinit(self.allocator);
        }
        self.buttons.deinit();
    }

    fn loadButtons(self: *BottomBar, items: []const UI.BarItem) void {
        // Clear existing buttons
        self.deinit();
        self.buttons = std.ArrayList(Button).init(self.allocator);

        // Add new buttons
        for (items) |item| {
            if (Button.init(self.allocator, item)) |button| {
                self.buttons.append(button) catch continue;
            } else |_| {
                continue;
            }
        }
    }

    fn render(self: *BottomBar) ?[]const u8 {
        const mm_to_px = 3.78; // 1mm ≈ 3.78px at 96 DPI

        const height_px = self.height_mm * mm_to_px;
        const button_size_px = self.button_size_mm * mm_to_px;
        const spacing_px = self.spacing_mm * mm_to_px;

        const screen_width = @as(f32, @floatFromInt(rl.getScreenWidth()));
        const screen_height = @as(f32, @floatFromInt(rl.getScreenHeight()));

        // Calculate button positions
        const bar_y = screen_height - height_px;
        const buttons_total_width = (button_size_px + spacing_px) * @as(f32, @floatFromInt(self.buttons.items.len));

        // Center the toolbar horizontally
        var button_x = (screen_width - buttons_total_width) / 2.0;

        var clicked_button: ?[]const u8 = null;
        const mouse_pos = rl.getMousePosition();

        // Draw background panel
        rl.drawRectangle(0, @intFromFloat(bar_y), @intFromFloat(screen_width), @intFromFloat(height_px), rl.Color{ .r = 30, .g = 30, .b = 30, .a = 200 });

        // Draw each button
        for (self.buttons.items) |*button| {
            const rect = rl.Rectangle{
                .x = button_x,
                .y = bar_y + (height_px - button_size_px) / 2.0,
                .width = button_size_px,
                .height = button_size_px,
            };

            // Check for mouse interaction
            const is_hover = rl.checkCollisionPointRec(mouse_pos, rect);
            const is_pressed = is_hover and rl.isMouseButtonDown(.left);
            const is_released = is_hover and rl.isMouseButtonReleased(.left);

            // Update button state
            if (is_pressed) {
                button.state = .Pressed;
            } else if (is_hover) {
                button.state = .Hovered;
            } else {
                button.state = .Normal;
            }

            // Draw the button
            const draw_color = switch (button.state) {
                .Normal => button.color,
                .Hovered => rl.Color{
                    .r = @min(255, button.color.r + 40),
                    .g = @min(255, button.color.g + 40),
                    .b = @min(255, button.color.b + 40),
                    .a = button.color.a,
                },
                .Pressed => rl.Color{
                    .r = @max(0, button.color.r - 40),
                    .g = @max(0, button.color.g - 40),
                    .b = @max(0, button.color.b - 40),
                    .a = button.color.a,
                },
            };

            rl.drawRectangleRec(rect, draw_color);

            // Draw button label - using null-terminated string
            const text_width = rl.measureText(button.label_z, 10);
            rl.drawText(button.label_z, @intFromFloat(rect.x + (rect.width - @as(f32, @floatFromInt(text_width))) / 2.0), @intFromFloat(rect.y + rect.height - 15.0), 10, rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 });

            // Draw icon if available
            if (button.icon) |texture_id| {
                _ = texture_id; // Acknowledge unused variable
            }

            // Handle button click
            if (is_released) {
                clicked_button = button.id;
            }

            // Move to next button position
            button_x += button_size_px + spacing_px;
        }

        return clicked_button;
    }
};

// Frame component
pub const Frame = struct {
    margin: f32 = 10.0, // Default 10mm margin
    thickness: f32 = 5.0, // Default 5mm thickness
    color: rl.Color = rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 }, // Default white

    pub fn init() Frame {
        return Frame{};
    }

    // Builder pattern methods
    pub fn setMargin(self: *Frame, margin_mm: f32) *Frame {
        self.margin = margin_mm;
        return self;
    }

    pub fn setThickness(self: *Frame, thickness_mm: f32) *Frame {
        self.thickness = thickness_mm;
        return self;
    }

    pub fn setColor(self: *Frame, col: rl.Color) *Frame {
        self.color = col;
        return self;
    }

    fn render(self: Frame) void {
        // Convert mm to pixels (assuming 96 DPI as standard)
        const mm_to_px = 3.78; // 1mm ≈ 3.78px at 96 DPI

        const margin_px = self.margin * mm_to_px;
        const thickness_px = self.thickness * mm_to_px;

        const screen_width = @as(f32, @floatFromInt(rl.getScreenWidth()));
        const screen_height = @as(f32, @floatFromInt(rl.getScreenHeight()));

        // Draw outer rectangle
        rl.drawRectangleLinesEx(rl.Rectangle{
            .x = margin_px,
            .y = margin_px,
            .width = screen_width - (margin_px * 2),
            .height = screen_height - (margin_px * 2),
        }, thickness_px, self.color);
    }
};

// TreeNode for Inspector
pub const TreeNode = struct {
    label: []const u8,
    children: std.ArrayList(TreeNode),

    pub fn init(allocator: std.mem.Allocator, label: []const u8) TreeNode {
        return .{
            .label = label,
            .children = std.ArrayList(TreeNode).init(allocator),
        };
    }

    pub fn deinit(self: *TreeNode) void {
        for (self.children.items) |*child| {
            child.deinit();
        }
        self.children.deinit();
    }

    pub fn addChild(self: *TreeNode, label: []const u8) !*TreeNode {
        const child = try self.children.addOne();
        child.* = TreeNode.init(self.children.allocator, label);
        return child;
    }
};

// Inspector component
pub const Inspector = struct {
    allocator: std.mem.Allocator,
    title: []const u8,
    title_z: [:0]const u8, // Null-terminated version for raylib
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    background_color: rl.Color,
    text_color: rl.Color,
    font_size: i32,
    line_height: i32,
    nodes: std.ArrayList(TreeNode),

    pub fn init(allocator: std.mem.Allocator, title: []const u8, x: i32, y: i32, width: i32, height: i32) Inspector {
        // Create null-terminated version of title
        const title_z = allocator.dupeZ(u8, title) catch unreachable;

        return .{
            .allocator = allocator,
            .title = title,
            .title_z = title_z,
            .x = x,
            .y = y,
            .width = width,
            .height = height,
            .background_color = rl.Color{ .r = 30, .g = 30, .b = 30, .a = 230 },
            .text_color = rl.Color{ .r = 225, .g = 225, .b = 225, .a = 255 },
            .font_size = 10,
            .line_height = 12,
            .nodes = std.ArrayList(TreeNode).init(allocator),
        };
    }

    pub fn deinit(self: *Inspector) void {
        for (self.nodes.items) |*node| {
            node.deinit();
        }
        self.nodes.deinit();
        self.allocator.free(self.title_z);
    }

    pub fn render(self: *Inspector) void {
        // Draw background
        rl.drawRectangle(self.x, self.y, self.width, self.height, self.background_color);

        // Draw title
        rl.drawRectangle(self.x, self.y, self.width, 30, rl.Color{ .r = 20, .g = 20, .b = 20, .a = 255 });
        rl.drawText(self.title_z, self.x + 10, self.y + 5, self.font_size, self.text_color);

        // Render tree content
        var current_y = self.y + 40;
        for (self.nodes.items) |*node| {
            current_y = self.renderNode(node, self.x + 10, current_y, "");
        }
    }

    fn renderNode(self: *Inspector, node: *TreeNode, x: i32, y: i32, prefix: []const u8) i32 {
        var current_y = y;

        // Draw current node with node label
        var label_buffer: [512]u8 = undefined;
        const label_text = std.fmt.bufPrintZ(&label_buffer, "{s}{s}", .{ prefix, node.label }) catch return current_y;
        rl.drawText(label_text, x, current_y, self.font_size, self.text_color);
        current_y += self.line_height;

        // Draw children
        if (node.children.items.len > 0) {
            for (node.children.items, 0..) |*child, i| {
                const is_last = i == node.children.items.len - 1;
                var prefix_buffer: [256]u8 = undefined;
                var child_label_buffer: [512]u8 = undefined;

                if (is_last) {
                    // Last item - use └── prefix
                    const branch_prefix = std.fmt.bufPrintZ(&prefix_buffer, "{s}└── ", .{prefix}) catch continue;
                    const new_prefix = std.fmt.bufPrintZ(&child_label_buffer, "{s}    ", .{prefix}) catch continue;

                    // Draw branch prefix
                    rl.drawText(branch_prefix, x, current_y, self.font_size, self.text_color);

                    // Draw child label after the branch
                    const child_label = self.allocator.dupeZ(u8, child.label) catch continue;
                    defer self.allocator.free(child_label);

                    const prefix_width = rl.measureText(branch_prefix, self.font_size);
                    rl.drawText(child_label, x + prefix_width, current_y, self.font_size, self.text_color);
                    current_y += self.line_height;

                    // Recursively draw grandchildren
                    if (child.children.items.len > 0) {
                        current_y = self.renderNode(child, x, current_y, new_prefix);
                    }
                } else {
                    // Middle item - use ├── prefix
                    const branch_prefix = std.fmt.bufPrintZ(&prefix_buffer, "{s}├── ", .{prefix}) catch continue;
                    const new_prefix = std.fmt.bufPrintZ(&child_label_buffer, "{s}│   ", .{prefix}) catch continue;

                    // Draw branch prefix
                    rl.drawText(branch_prefix, x, current_y, self.font_size, self.text_color);

                    // Draw child label after the branch
                    const child_label = self.allocator.dupeZ(u8, child.label) catch continue;
                    defer self.allocator.free(child_label);

                    const prefix_width = rl.measureText(branch_prefix, self.font_size);
                    rl.drawText(child_label, x + prefix_width, current_y, self.font_size, self.text_color);
                    current_y += self.line_height;

                    // Recursively draw grandchildren
                    if (child.children.items.len > 0) {
                        current_y = self.renderNode(child, x, current_y, new_prefix);
                    }
                }
            }
        }

        return current_y;
    }

    pub fn addNode(self: *Inspector, label: []const u8) !*TreeNode {
        const node = try self.nodes.addOne();
        node.* = TreeNode.init(self.allocator, label);
        return node;
    }
};
