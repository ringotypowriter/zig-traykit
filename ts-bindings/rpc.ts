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

type ActionHandler = (index: number) => void;

export class JsonRpcClient {
  private proc?: ReturnType<typeof spawn>;
  private stdout?: AsyncIterable<Uint8Array>;
  private stdin?: FileSink;
  private readonly resolvers = new Map<number, (response: JsonRpcResponse) => void>();
  private readonly inflight = new Set<number>();
  private nextId = 1;
  private unknownIdCount = 0;
  private shouldPoll = false;
  private actionHandler?: ActionHandler;
  private readLoopPromise: Promise<void> | null = null;
  private pollLoopPromise: Promise<void> | null = null;

  constructor(
    private readonly binaryPath: string,
    private readonly debug: boolean,
  ) {}

  setActionHandler(handler: ActionHandler) {
    this.actionHandler = handler;
  }

  isRunning(): boolean {
    return Boolean(this.proc);
  }

  async start(configJson: string): Promise<void> {
    if (this.proc) return;

    const args = ["--config-json", configJson];
    this.proc = spawn({
      cmd: [this.binaryPath, ...args],
      stdout: "pipe",
      stdin: "pipe",
      stderr: "inherit",
    });
    this.stdout = this.proc.stdout as AsyncIterable<Uint8Array> | undefined;
    this.stdin = this.proc.stdin as FileSink | undefined;

    this.shouldPoll = true;
    this.readLoopPromise = this.readLoop();
    this.pollLoopPromise = this.pollLoop();
  }

  async stop(): Promise<void> {
    if (!this.proc) return;
    this.shouldPoll = false;
    const proc = this.proc;
    this.proc = undefined;
    try {
      proc.kill();
    } catch {
      // ignore
    }
    try {
      await proc.exited;
    } catch {
      // ignore
    }
    this.stdin = undefined;
    this.stdout = undefined;
    this.rejectAllResolvers(new Error("TrayKit process stopped"));
  }

  async call<T = unknown>(
    method: string,
    params?: Record<string, unknown>,
  ): Promise<T> {
    if (!this.stdin) {
      throw new Error("TrayKit process not running");
    }
    const id = this.nextId++;
    const req: JsonRpcRequest = { jsonrpc: "2.0", method, params, id };
    const line = JSON.stringify(req);
    if (this.debug) console.debug("TrayKit ->", line);
    this.stdin.write(line + "\n");
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

  private rejectAllResolvers(err: Error) {
    for (const [id, resolver] of this.resolvers.entries()) {
      this.inflight.delete(id);
      resolver({ jsonrpc: "2.0", id, error: { code: -32000, message: err.message } });
    }
    this.resolvers.clear();
  }

  private async readLoop() {
    if (!this.stdout) return;
    let buffer = "";
    const decoder = new TextDecoder();

    for await (const chunk of this.stdout) {
      buffer += decoder.decode(chunk, { stream: true });
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
          const res = JSON.parse(line) as JsonRpcResponse & {
            method?: string;
            params?: Record<string, unknown>;
          };
          if (res.id == null) {
            if (res.method === "tray_action") {
              const index = Number(res.params?.index);
              if (Number.isInteger(index) && this.actionHandler) {
                try {
                  this.actionHandler(index);
                } catch (err) {
                  console.error("TrayKit action handler error", err);
                }
              }
              continue;
            }
            if (this.unknownIdCount < 5 || this.unknownIdCount % 20 === 0) {
              console.warn("TrayKit: response with null id", res);
            }
            this.unknownIdCount += 1;
            continue;
          }
          const resolver = this.resolvers.get(res.id);
          if (resolver) {
            this.resolvers.delete(res.id);
            this.inflight.delete(res.id);
            resolver(res);
          } else if (this.unknownIdCount < 5 || this.unknownIdCount % 20 === 0) {
            console.warn("TrayKit: response with unknown id", res.id, res);
            this.unknownIdCount += 1;
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

  private async pollLoop() {
    while (this.shouldPoll) {
      await new Promise((resolve) => setTimeout(resolve, 200));
      if (!this.shouldPoll) break;
      try {
        await this.call("pollActions");
      } catch (err) {
        if (this.debug) {
          console.error("TrayKit pollActions error", err);
        }
        break;
      }
    }
  }
}
