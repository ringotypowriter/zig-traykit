# TrayKit

Native macOS tray (menu bar) application written in Zig, with Bun/TypeScript bindings for driving the tray UI from JavaScript.

TrayKit lets you:
- Show a status icon in the macOS menu bar (text, SF Symbol, or base64 image).
- Build and update tray menus dynamically from a Bun/TypeScript process.
- Receive click callbacks on menu items via a lightweight JSON-RPC bridge.

> Status: early-stage, macOS-only, APIs may still change.

## Project layout

- `binary/` – Zig native tray app for macOS (links against Cocoa/AppKit/Foundation).
  - `binary/main.zig` – entry point.
  - `binary/tray_app.zig` – tray lifecycle, config parsing, and RPC loop wiring.
  - Builds to `binary/zig-out/bin/zig-traykit`.
- `ts-bindings/` – Bun/TypeScript bindings exposing a `TrayKit` client.
  - `ts-bindings/index.ts` – public API surface.
  - `ts-bindings/demo.ts` – minimal example tray menu.
  - `ts-bindings/README.md` – more details for the bindings.

## Prerequisites

- macOS with a visible menu bar (Cocoa/AppKit).
- [Zig](https://ziglang.org/) compiler installed and on your `PATH`.
- [Bun](https://bun.com/) runtime for the TypeScript bindings.

## Building the native tray binary

From the repository root:

```bash
cd binary
zig build
```

This produces the `zig-traykit` binary at:

```bash
binary/zig-out/bin/zig-traykit
```

You can run it directly to start a tray icon using the default configuration:

```bash
binary/zig-out/bin/zig-traykit
```

The binary also accepts a JSON config via `--config-json` (see “Configuration JSON” below), but most users will interact with it through the Bun/TypeScript client.

## Installing and using the Bun/TypeScript bindings

The bindings live in `ts-bindings/` and are intended to be used with Bun.

Install from npm in your Bun project:

```bash
bun add traykit-bindings
```

Create a minimal tray menu:

```ts
import TrayKit from "traykit-bindings";

const client = TrayKit.createClient({
  // By default this JSON matches the Zig default config.
  configJson: TrayKit.defaultConfigJson(),
  // Optional: binaryPath, debug, etc.
});

await client.addText({ title: "Hello from TrayKit" });
await client.addAction({ title: "Quit", key_equivalent: "q" });
```

By default the client will spawn the bundled native binary from the package’s `bin/` directory. If you want to point at your own build, override `binaryPath` in `TrayClientOptions`.

## Configuration JSON

The tray binary accepts a JSON configuration via:

```bash
binary/zig-out/bin/zig-traykit --config-json '<json>'
```

The JSON shape (simplified) is:

```jsonc
{
  "icon": {
    "type": "sf_symbol" | "text" | "base64_image",
    // when type === "text"
    "title": "TrayKit",
    // when type === "sf_symbol"
    "name": "checkmark.circle",
    "accessibility_description": "TrayKit status icon",
    // when type === "base64_image"
    "base64_data": "<base64-encoded image>"
  },
  "items": [
    {
      "type": "text",
      "title": "Label",
      "is_separator": false
    },
    {
      "type": "action",
      "title": "Quit",
      "key_equivalent": "q",
      // "quit" closes the app; "callback" sends events back over RPC.
      "kind": "quit" // or "callback"
    }
  ]
}
```

The TypeScript bindings expose `defaultConfigJson()` which returns a reasonable starter config with an SF Symbol icon and an empty menu; you can always generate your own JSON and pass it in via `TrayKit.createClient({ configJson })`.

## Development notes

- Zig:
  - Build with `cd binary && zig build`.
  - `tray_app.zig` contains the JSON parsing and maps it into the internal model types.
  - `tray_runtime.zig`, `objc_runtime.zig`, and related files wrap AppKit/Cocoa calls.
- TypeScript (Bun):
  - Use `cd ts-bindings && bun install` to install dependencies.
  - Use `bun run demo.ts` to experiment with the client.
  - Prefer Bun APIs (`bun:test`, `spawn`, etc.) instead of Node-only tooling.

## Status and contributions

TrayKit is still evolving; expect breaking changes to the JSON shape and binding APIs while things are being iterated on. Issues and pull requests are welcome once the public API settles a bit more—until then, feel free to experiment and file feedback.
