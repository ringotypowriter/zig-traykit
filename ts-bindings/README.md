## TrayKit Bun Bindings (Bun only)

> This package is **Bun-only**. It targets the [Bun](https://bun.com) runtime and is not designed to run on plain Node.js.

These bindings expose a small TypeScript client that controls the TrayKit native macOS menu bar app from a Bun process (add/remove menu items, handle clicks, etc.).  
Published npm package name: **`traykit-bindings`**.

---

## Installation (Bun project)

In your Bun project:

```bash
bun add traykit-bindings
```

Requirements:
- macOS (menu bar / status item)
- Bun runtime (uses `bun spawn`, `bun:test`, etc.)

---

## Quick start

Create a script in your Bun + TypeScript project, for example `tray.ts`:

```ts
import TrayKit from "traykit-bindings";

const client = TrayKit.createClient({
  // Optional: default config JSON; if omitted, a built-in default is used.
  configJson: TrayKit.defaultConfigJson(),
  // Optional: binaryPath, debug, etc.
});

await client.addText({ title: "Hello from TrayKit" });
await client.addAction({ title: "Quit", key_equivalent: "q" });
```

Run with Bun:

```bash
bun tray.ts
```

By default the client starts the bundled native binary from the package’s `bin/zig-traykit`.  
If you have your own custom build, override `binaryPath`:

```ts
const client = TrayKit.createClient({
  binaryPath: "/your/custom/path/zig-traykit",
});
```

---

## API overview

The client is fully typed for Bun + TypeScript. Core entry points:

- `TrayKit.createClient(opts?: TrayClientOptions): TrayClient`
- `TrayKit.defaultConfigJson(): string`
- `TrayKit.Client` constructor (lower-level usage)

### `TrayClientOptions`

```ts
type TrayClientOptions = {
  binaryPath?: string;  // Custom path to the Zig binary
  configJson?: string;  // Initial configuration JSON
  debug?: boolean;      // Enable debug logging
};
```

### Main instance methods

- `addText({ title, is_separator?, index? })`
- `addAction({ title, key_equivalent?, index?, onClick? })`
- `removeItem(index)`
- `clearItems()`
- `list()`
- `setIcon(params)`
Example:

```ts
await client.addText({ title: "Title", is_separator: false });

await client.addAction({
  title: "Click me",
  key_equivalent: "c",
  onClick: () => {
    console.log("tray item clicked");
  },
});
```

`TrayKit.defaultConfigJson()` returns a minimal config with an icon and no menu items.  
If you want a richer default menu, build your own JSON config and pass it into `createClient`.

---

## Local development in this repo

If you are working inside the TrayKit repo on the bindings, you can use the built-in demo:

```bash
cd ts-bindings
bun install
bun run demo.ts
```

Before publishing to npm, the `prepublishOnly` script will automatically:

1. Build the macOS native binary with Zig (using `ReleaseSmall` optimize mode).
2. Copy the binary into `ts-bindings/bin/zig-traykit`.
3. Run `bun test` to perform basic integration checks and ensure the binary can be found and started.
