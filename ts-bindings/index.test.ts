import { test, expect } from "bun:test";
import TrayKit from "./index";

test("binary exists next to bindings", async () => {
  const binPath = `${import.meta.dir}/bin/zig-traykit`;
  const file = Bun.file(binPath);
  const exists = await file.exists();

  expect(exists).toBe(true);
});

test("TrayClient can start and list without error", async () => {
  const client = TrayKit.createClient({
    configJson: TrayKit.defaultConfigJson(),
  });

  const items = (await client.list()) as unknown;
  // list() should return something JSON-serializable, most likely an array.
  const isArray = Array.isArray(items);

  expect(isArray).toBe(true);

  // Best-effort: terminate the spawned binary so tests don't leak processes.
  const anyClient = client as any;
  if (anyClient.proc && typeof anyClient.proc.kill === "function") {
    anyClient.proc.kill();
  }
});

