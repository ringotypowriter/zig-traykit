import {
  defaultConfigJson as modelDefaultConfigJson,
  insertActionItem,
  insertTextItem,
  removeItemAt,
  serializeState,
  stateFromConfigJson,
  clearItems,
  updateIconState,
} from "./model";
import type { TrayClientOptions, TrayState } from "./model";
import { JsonRpcClient } from "./rpc";
export type { TrayClientOptions } from "./model";

type MenuSlot =
  | { kind: "text" }
  | { kind: "action"; onClick?: () => void };

export function defaultConfigJson(): string {
  return modelDefaultConfigJson();
}

export class TrayClient {
  private readonly rpc: JsonRpcClient;
  private readonly debug: boolean;
  private readonly initialConfigJson: string;
  private state: TrayState;
  private readonly slots: MenuSlot[] = [];

  constructor(private readonly options?: TrayClientOptions) {
    this.debug = Boolean(options?.debug ?? process.env.TRAYKIT_DEBUG);
    const binaryPath = options?.binaryPath ?? `${import.meta.dir}/bin/zig-traykit`;
    this.initialConfigJson = options?.configJson ?? defaultConfigJson();
    this.state = stateFromConfigJson(this.initialConfigJson);
    this.rebuildSlotsFromState();

    this.rpc = new JsonRpcClient(binaryPath, this.debug);
    this.rpc.setActionHandler((index) => this.handleAction(index));
    void this.rpc.start(this.initialConfigJson);
  }

  async call<T = unknown>(
    method: string,
    params?: Record<string, unknown>,
  ): Promise<T> {
    return this.rpc.call<T>(method, params);
  }

  setIcon(params: Record<string, unknown>) {
    updateIconState(this.state, params);
    return this.rpc.call("setIcon", params);
  }

  addText(params: {
    title: string;
    is_separator?: boolean;
    index?: number;
  }) {
    const index = insertTextItem(this.state, params);
    this.slots.splice(index, 0, { kind: "text" });
    const payload = { ...params, index };
    return this.rpc.call("addText", payload);
  }

  addAction(params: {
    title: string;
    key_equivalent?: string;
    index?: number;
    onClick?: () => void;
  }) {
    const { onClick, ...rest } = params;
    const kind = onClick ? "callback" : "quit";
    const index = insertActionItem(this.state, { ...rest, kind });
    this.slots.splice(index, 0, { kind: "action", onClick });
    const payload = { ...rest, kind, index } as Record<string, unknown>;
    return this.rpc.call("addAction", payload);
  }

  removeItem(index: number) {
    if (removeItemAt(this.state, index) && index >= 0 && index < this.slots.length) {
      this.slots.splice(index, 1);
    }
    return this.rpc.call("removeItem", { index });
  }

  clearItems() {
    clearItems(this.state);
    this.slots.length = 0;
    return this.rpc.call("clearItems");
  }

  list() {
    return this.rpc.call("list");
  }

  async hide(): Promise<void> {
    await this.rpc.stop();
  }

  async show(): Promise<void> {
    if (this.rpc.isRunning()) return;
    await this.rpc.start(serializeState(this.state));
  }

  private rebuildSlotsFromState() {
    this.slots.length = 0;
    for (const item of this.state.items) {
      if (item.type === "action") {
        this.slots.push({ kind: "action" });
      } else {
        this.slots.push({ kind: "text" });
      }
    }
  }

  private handleAction(index: number) {
    const slot = this.slots[index];
    if (slot && slot.kind === "action" && slot.onClick) {
      try {
        slot.onClick();
      } catch (err) {
        console.error("TrayKit onClick error", err);
      }
    }
  }
}

export type TrayKitFacade = {
  readonly Client: typeof TrayClient;
  readonly createClient: (opts?: TrayClientOptions) => TrayClient;
  readonly defaultConfigJson: () => string;
};

export const TrayKit: TrayKitFacade = Object.freeze({
  Client: TrayClient,
  createClient: (opts?: TrayClientOptions) => new TrayClient(opts),
  defaultConfigJson,
});

export default TrayKit;
