import { spawn } from "bun";
import type { FileSink } from "bun";

type JsonRpcRequest = {
  jsonrpc: "2.0";
  method: string;
  params?: Record<string, unknown>;
  id: number;
};

type JsonRpcResponse = {
  jsonrpc: "2.0";
  id: number;
  result?: unknown;
  error?: { code: number; message: string };
};

export type TrayClientOptions = {
  binaryPath?: string;
  configJson?: string;
  debug?: boolean;
};

const DEFAULT_CONFIG = Object.freeze({
  icon: {
    type: "sf_symbol",
    name: "checkmark.circle",
    accessibility_description: "TrayKit",
  },
  items: [],
});

export function defaultConfigJson(): string {
  return JSON.stringify(DEFAULT_CONFIG);
}

export class TrayClient {
  private readonly proc: ReturnType<typeof spawn>;
  private readonly stdout?: AsyncIterable<Uint8Array>;
  private readonly stdin?: FileSink;
  private nextId = 1;
  private readonly resolvers = new Map<
    number,
    (res: JsonRpcResponse) => void
  >();
  private unknownIdCount = 0;
  private readonly debug: boolean;
  private readonly inflight = new Set<number>();

  constructor(private readonly options?: TrayClientOptions) {
    this.debug = Boolean(options?.debug ?? process.env.TRAYKIT_DEBUG);
    const binaryPath =
      options?.binaryPath ??
      `${import.meta.dir}/../binary/zig-out/bin/zig-traykit`;
    const args = ["--config-json", options?.configJson ?? defaultConfigJson()];

    this.proc = spawn({
      cmd: [binaryPath, ...args],
      stdout: "pipe",
      stdin: "pipe",
      stderr: "inherit",
    });
    this.stdout = this.proc.stdout as AsyncIterable<Uint8Array> | undefined;
    this.stdin = this.proc.stdin as FileSink | undefined;

    void this.readLoop();
  }

  async call<T = unknown>(
    method: string,
    params?: Record<string, unknown>,
  ): Promise<T> {
    const id = this.nextId++;
    const req: JsonRpcRequest = { jsonrpc: "2.0", method, params, id };
    if (!this.stdin) {
      throw new Error("TrayClient stdin not available");
    }

    const line = JSON.stringify(req);
    if (this.debug) console.debug("TrayKit ->", line);
    this.stdin.write(line + "\n");
    // FileSink buffers; flush to push data to the child immediately.
    if (typeof (this.stdin as any).flush === "function") {
      await (this.stdin as any).flush();
    }
    this.inflight.add(id);

    return new Promise<T>((resolve, reject) => {
      this.resolvers.set(id, (res) => {
        if (res.error) {
          reject(res.error);
        } else {
          resolve(res.result as T);
        }
      });
    });
  }

  setIcon(params: Record<string, unknown>) {
    return this.call("setIcon", params);
  }

  addText(params: { title: string; is_separator?: boolean; index?: number }) {
    return this.call("addText", params);
  }

  addAction(params: {
    title: string;
    key_equivalent?: string;
    index?: number;
  }) {
    return this.call("addAction", params);
  }

  removeItem(index: number) {
    return this.call("removeItem", { index });
  }

  list() {
    return this.call("list");
  }

  private async readLoop() {
    if (!this.stdout) return;
    let buffer = "";

    const decoder = new TextDecoder();

    for await (const chunk of this.stdout) {
      buffer += decoder.decode(chunk, { stream: true });
      // Protect against a missing newline from the child process to avoid unbounded growth.
      if (buffer.length > 1_000_000) {
        console.error(
          "TrayKit stdout buffer exceeded 1MB without newline; dropping data to avoid OOM",
        );
        buffer = "";
        continue;
      }
      let idx: number;

      while ((idx = buffer.indexOf("\n")) >= 0) {
        const line = buffer.slice(0, idx).trim();
        buffer = buffer.slice(idx + 1);
        if (!line) continue;

        if (this.debug) console.debug("TrayKit <-", line);

        try {
          const res = JSON.parse(line) as JsonRpcResponse;
          if (res.id == null) {
            // Notifications or malformed replies; avoid log spam.
            if (this.unknownIdCount < 5 || this.unknownIdCount % 20 === 0) {
              console.warn("TrayKit: response with null id", res);
            }
            this.unknownIdCount += 1;
            continue;
          }

          const resolve = this.resolvers.get(res.id);
          if (resolve) {
            this.resolvers.delete(res.id);
            this.inflight.delete(res.id);
            resolve(res);
          } else if (
            this.unknownIdCount < 5 ||
            this.unknownIdCount % 20 === 0
          ) {
            this.unknownIdCount += 1;
            console.warn("TrayKit: response with unknown id", res.id, res);
          } else {
            this.unknownIdCount += 1;
          }
        } catch (err) {
          console.error("TrayKit parse error", err, line);
        }
      }
    }

    if (this.debug && this.inflight.size > 0) {
      console.debug("TrayKit: inflight after stream end", [...this.inflight]);
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
