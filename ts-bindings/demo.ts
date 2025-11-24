import TrayKit from "./index";

async function main() {
  const client = TrayKit.createClient();
  await client.addText({
    title: "Text #1",
    sf_symbol_name: "square.and.arrow.up",
  });
  await client.addText({
    title: "Text #2",
    sf_symbol_name: "rectangle.portrait.and.arrow.right",
  });

  await client.addAction({
    title: "Say Hi",
    key_equivalent: "h",
    onClick: () => {
      console.log("[TrayKit] action clicked -> Hi there!");
    },
  });

  await client.addAction({ title: "Quit", key_equivalent: "q" });

  console.log("TrayKit demo ready.");
  console.log("Commands: 'h' hide, 's' show, 'l' list, 'c' clear, 'q' quit");

  process.stdin.setEncoding("utf8");
  process.stdin.resume();

  async function cleanup() {
    process.stdin.pause();
    try {
      await client.hide();
    } catch (err) {
      console.error("Failed to stop TrayKit", err);
    }
  }

  async function handleCommand(raw: string) {
    const cmd = raw.trim().toLowerCase();
    switch (cmd) {
      case "h":
        await client.hide();
        console.log("TrayKit hidden (process killed).");
        break;
      case "s":
        await client.show();
        console.log("TrayKit shown (process restarted).");
        break;
      case "l": {
        try {
          const items = await client.list();
          console.log("Current tray items:", items);
        } catch (err) {
          console.error("list() failed (maybe hidden?)", err);
        }
        break;
      }
      case "c":
        await client.clearItems();
        console.log("Tray menu cleared.");
        break;
      case "q":
        await cleanup();
        console.log("Bye!");
        process.exit(0);
        break;
      default:
        if (cmd) {
          console.log("Unknown command:", cmd);
        }
    }
  }

  process.stdin.on("data", (chunk: string | Buffer) => {
    const input = typeof chunk === "string" ? chunk : chunk.toString("utf8");
    void handleCommand(input);
  });
}

void main().catch((err) => {
  console.error("Tray demo failed", err);
  process.exitCode = 1;
});
