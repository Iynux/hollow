import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, "..");
const privateDir = path.join(root, "private");
const dest = path.join(privateDir, "hollow.lua");

const sources = [
  path.join(root, "..", "hollow.lua"),
  path.join(root, "hollow.lua"),
  dest,
];

fs.mkdirSync(privateDir, { recursive: true });

let copied = false;
for (const source of sources) {
  if (source === dest) {
    if (fs.existsSync(dest)) {
      copied = true;
      break;
    }
    continue;
  }
  if (fs.existsSync(source)) {
    fs.copyFileSync(source, dest);
    console.log(`Copied ${source} -> ${dest}`);
    copied = true;
    break;
  }
}

if (!copied) {
  console.warn("Warning: hollow.lua not found. Script endpoint will fail until private/hollow.lua exists.");
}
