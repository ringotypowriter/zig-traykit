import TrayKit from "./index";

async function main() {
  const client = TrayKit.createClient();
  await client.addText({ title: "Exusiai says hi" });
  await client.addText({ title: "Exusiai says hi #2" });

  await client.addAction({ title: "Quit", key_equivalent: "q" });

  const items = await client.list();
  console.log("Tray items:", items);
}

void main().catch((err) => {
  console.error("Tray demo failed", err);
});
