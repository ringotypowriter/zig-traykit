import TrayKit from "./index";

async function main() {
  const client = TrayKit.createClient();
  await client.addText({ title: "Text #1" });
  await client.addText({ title: "Text #2" });

  await client.addAction({
    title: "Say Hi",
    key_equivalent: "h",
    onClick: () => {
      console.log("[TrayKit] action clicked -> Hi there!");
    },
  });

  await client.addAction({ title: "Quit", key_equivalent: "q" });

  const items = await client.list();
  console.log("Tray items:", items);
}

void main().catch((err) => {
  console.error("Tray demo failed", err);
});
