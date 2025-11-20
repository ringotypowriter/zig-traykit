## bindings

To install dependencies:

```bash
bun install
```

## 使用方式

安装依赖：

```bash
bun install
```

在代码里直接引入 `TrayKit` 包（需要类型可以额外导入 `TrayClientOptions`）：

```ts
import TrayKit from "./index";

const client = TrayKit.createClient({
  configJson: TrayKit.defaultConfigJson(),
});

await client.addText({ title: "Hello from TrayKit" });
await client.addAction({ title: "Quit", key_equivalent: "q" });
```

`TrayKit.defaultConfigJson()` 仅提供一个带 icon 的空菜单结构；如果想要默认多条项目，可以自己生成配置 JSON 再传入 `createClient`。

`addAction` 中的 `index` 参数是可选的（默认会追加到当前末尾），通常不需要显式传入。

如果需要细粒度控制，可以直接使用 `TrayKit.Client` 构造函数，并传入 `TrayClientOptions`。

## 运行示例

```bash
bun run demo.ts
```

This project was created using `bun init` in bun v1.2.23. [Bun](https://bun.com) is a fast all-in-one JavaScript runtime.
