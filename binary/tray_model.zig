pub const TrayIcon = union(enum) {
    text: TextIcon,
    sf_symbol: SfSymbolIcon,
    base64_image: Base64Icon,
};

pub const TextIcon = struct {
    title: [*:0]const u8,
};

pub const SfSymbolIcon = struct {
    name: [*:0]const u8,
    accessibility_description: [*:0]const u8,
};

pub const Base64Icon = struct {
    base64_data: [*:0]const u8,
};

pub const ActionKind = union(enum) {
    quit,
    callback: u32,
};

pub const ActionItem = struct {
    title: [*:0]const u8,
    key_equivalent: [*:0]const u8,
    kind: ActionKind,
    sf_symbol_name: ?[*:0]const u8 = null,
};

pub const TextLineItem = struct {
    title: [*:0]const u8,
    is_separator: bool = false,
    sf_symbol_name: ?[*:0]const u8 = null,
};

pub const MenuItem = union(enum) {
    action: ActionItem,
    text: TextLineItem,
};

pub const TrayConfig = struct {
    icon: TrayIcon,
    items: []const MenuItem,
};
