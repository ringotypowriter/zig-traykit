export type IconType = "text" | "sf_symbol" | "base64_image";

export type IconConfig = {
  type: IconType;
  title?: string;
  name?: string;
  accessibility_description?: string;
  base64_data?: string;
};

export type TextMenuItem = {
  type: "text";
  title: string;
  is_separator?: boolean;
};

export type ActionMenuItem = {
  type: "action";
  title: string;
  key_equivalent?: string;
  kind: "callback" | "quit";
};

export type MenuItemConfig = TextMenuItem | ActionMenuItem;

export type TrayState = {
  icon: IconConfig;
  items: MenuItemConfig[];
};

export type TrayClientOptions = {
  binaryPath?: string;
  configJson?: string;
  debug?: boolean;
};

const DEFAULT_STATE: TrayState = Object.freeze({
  icon: {
    type: "sf_symbol",
    name: "checkmark.circle",
    accessibility_description: "TrayKit",
  },
  items: [],
});

export function createDefaultState(): TrayState {
  return cloneState(DEFAULT_STATE);
}

export function defaultConfigJson(): string {
  return serializeState(createDefaultState());
}

export function stateFromConfigJson(configJson?: string): TrayState {
  if (!configJson) {
    return createDefaultState();
  }

  try {
    const parsed = JSON.parse(configJson);
    const icon = parseIcon(parsed?.icon) ?? cloneIcon(DEFAULT_STATE.icon);
    const items = Array.isArray(parsed?.items)
      ? parsed.items
          .map((item: unknown) => parseMenuItem(item))
          .filter((item: MenuItemConfig | null): item is MenuItemConfig => Boolean(item))
      : [];
    return { icon, items };
  } catch {
    return createDefaultState();
  }
}

export function serializeState(state: TrayState): string {
  return JSON.stringify({
    icon: state.icon,
    items: state.items,
  });
}

export function updateIconState(
  state: TrayState,
  params: Record<string, unknown>,
): void {
  const icon: IconConfig = {
    type: coerceIconType(params.type) ?? state.icon.type,
  };

  if (typeof params.title === "string") icon.title = params.title;
  if (typeof params.name === "string") icon.name = params.name;
  if (typeof params.accessibility_description === "string") {
    icon.accessibility_description = params.accessibility_description;
  }
  if (typeof params.base64_data === "string") icon.base64_data = params.base64_data;

  state.icon = icon;
}

export function insertTextItem(
  state: TrayState,
  params: { title: string; is_separator?: boolean; index?: number },
): number {
  const index = clampIndex(params.index, state.items.length);
  const item: TextMenuItem = {
    type: "text",
    title: params.title,
    is_separator: Boolean(params.is_separator),
  };
  state.items.splice(index, 0, item);
  return index;
}

export function insertActionItem(
  state: TrayState,
  params: {
    title: string;
    key_equivalent?: string;
    kind: "callback" | "quit";
    index?: number;
  },
): number {
  const index = clampIndex(params.index, state.items.length);
  const item: ActionMenuItem = {
    type: "action",
    title: params.title,
    key_equivalent: params.key_equivalent,
    kind: params.kind,
  };
  state.items.splice(index, 0, item);
  return index;
}

export function removeItemAt(state: TrayState, index: number): boolean {
  if (index < 0 || index >= state.items.length) {
    return false;
  }
  state.items.splice(index, 1);
  return true;
}

function parseIcon(value: unknown): IconConfig | null {
  if (!value || typeof value !== "object") return null;
  const type = coerceIconType((value as Record<string, unknown>).type);
  if (!type) return null;
  const icon: IconConfig = { type };
  const record = value as Record<string, unknown>;
  if (typeof record.title === "string") icon.title = record.title;
  if (typeof record.name === "string") icon.name = record.name;
  if (typeof record.accessibility_description === "string") {
    icon.accessibility_description = record.accessibility_description;
  }
  if (typeof record.base64_data === "string") icon.base64_data = record.base64_data;
  return icon;
}

function parseMenuItem(value: unknown): MenuItemConfig | null {
  if (!value || typeof value !== "object") return null;
  const record = value as Record<string, unknown>;
  if (record.type === "text" && typeof record.title === "string") {
    return {
      type: "text",
      title: record.title,
      is_separator: Boolean(record.is_separator),
    };
  }
  if (record.type === "action" && typeof record.title === "string") {
    const kind = record.kind === "callback" ? "callback" : "quit";
    const action: ActionMenuItem = {
      type: "action",
      title: record.title,
      key_equivalent:
        typeof record.key_equivalent === "string" ? record.key_equivalent : undefined,
      kind,
    };
    return action;
  }
  return null;
}

function clampIndex(idx: number | undefined, length: number): number {
  if (typeof idx !== "number" || Number.isNaN(idx)) {
    return length;
  }
  if (idx < 0) return 0;
  if (idx > length) return length;
  return idx;
}

function cloneIcon(icon: IconConfig): IconConfig {
  return { ...icon };
}

function cloneState(state: TrayState): TrayState {
  return {
    icon: cloneIcon(state.icon),
    items: state.items.map((item: MenuItemConfig) => ({ ...item })),
  };
}

function coerceIconType(value: unknown): IconType | null {
  if (value === "text" || value === "sf_symbol" || value === "base64_image") {
    return value;
  }
  return null;
}
