# Repository Guidelines

## Project Structure & Module Organization

- `binary/` — Zig native tray application for macOS. Main entry is `binary/main.zig`; supporting modules such as `tray_app.zig` and `tray_runtime.zig` live here. The compiled binary is written to `binary/zig-out/bin/zig-traykit` via `zig build`.
- `bindings/` — Bun/TypeScript bindings exposing the `TrayKit` client. Public API lives in `bindings/index.ts`, examples and usage notes are in `bindings/README.md`, and `bindings/demo.ts` shows a minimal tray menu.

## Build, Test, and Development Commands

- Build native binary: `cd binary && zig build` — compiles the tray application into `zig-out/bin/zig-traykit`.
- Install JS deps: `cd bindings && bun install` — installs Bun/TypeScript dependencies.
- Run demo client: `cd bindings && bun run demo.ts` — starts a demo that talks to the local tray binary.
- (Future) Run TS tests: `cd bindings && bun test` once tests are added.

## Coding Style & Naming Conventions

- Zig: 4-space indentation; prefer `snake_case` for functions and variables, `UpperCamelCase` for types. Keep `pub fn main` only in `binary/main.zig` and move logic into modules.
- TypeScript: 2-space indentation, ES modules, and explicit types where practical. Use `camelCase` for variables/functions, `PascalCase` for classes and type aliases, and expose the public surface from `bindings/index.ts`. Prefer Bun APIs (`bun:test`, `spawn`) over Node-only libraries.

## Testing Guidelines

- TypeScript tests should live next to the code (e.g. `index.test.ts`) or under `bindings/__tests__/`, and be runnable via `bun test`.
- Zig tests should use `std.testing` in the same file as the code under test and be run with `zig test path/to/file.zig`.
- New features should include at least one happy-path test where feasible.

## Commit & Pull Request Guidelines

- Follow the existing conventional-commit style used in this repo, e.g. `feat: add bindings client`, `fix: rpc polling`, `chore: cleanup debug log`.
- Keep commit subjects concise (≤ 72 chars) and imperative. Scope changes when helpful, e.g. `feat(bindings): add tray client`.
- Pull requests should include a short summary of the change, any relevant design notes, how you tested it (exact commands), and links to related issues. Add screenshots or GIFs when behavior is user-visible.

