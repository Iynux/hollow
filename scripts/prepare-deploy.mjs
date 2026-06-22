import { spawnSync } from "child_process";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const syncScript = path.join(__dirname, "sync-deploy.mjs");
const result = spawnSync(process.execPath, [syncScript], { stdio: "inherit" });
process.exit(result.status ?? 1);
