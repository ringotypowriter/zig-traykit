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
  await client.hide();
});

test("hide + show restores items", async () => {
  const client = TrayKit.createClient({
    configJson: TrayKit.defaultConfigJson(),
  });

  await client.addText({ title: "Alpha" });
  await client.addAction({ title: "Beta", key_equivalent: "b" });

  const before = (await client.list()) as unknown;
  expect(Array.isArray(before)).toBe(true);

  await client.hide();
  await client.show();

  const after = (await client.list()) as unknown;
  expect(after).toEqual(before);

  await client.hide();
});

test("hide + show preserves removals", async () => {
  const client = TrayKit.createClient({
    configJson: TrayKit.defaultConfigJson(),
  });

  await client.addText({ title: "Item A" });
  await client.addText({ title: "Item B" });
  await client.addText({ title: "Item C" });
  await client.removeItem(1);

  const expected = (await client.list()) as unknown;
  expect(Array.isArray(expected)).toBe(true);

  await client.hide();
  await client.show();

  const after = (await client.list()) as unknown;
  expect(after).toEqual(expected);

  await client.hide();
});

test("hide/show are idempotent", async () => {
  const client = TrayKit.createClient({
    configJson: TrayKit.defaultConfigJson(),
  });

  await client.hide();
  await client.hide();
  await client.show();
  await client.show();

  const items = await client.list();
  expect(Array.isArray(items)).toBe(true);

  await client.hide();
});

test("clearItems removes all items and persists", async () => {
  const client = TrayKit.createClient({
    configJson: TrayKit.defaultConfigJson(),
  });

  await client.addText({ title: "Keep" });
  await client.addAction({ title: "Click" });

  const before = (await client.list()) as unknown[];
  expect(before.length).toBeGreaterThan(0);

  await client.clearItems();
  const cleared = (await client.list()) as unknown[];
  expect(cleared).toEqual([]);

  await client.hide();
  await client.show();

  const after = (await client.list()) as unknown[];
  expect(after).toEqual([]);

  await client.hide();
});
