// Restore the last-used model for fresh sessions. State: ~/.pi/agent/last-model.json.
// Resumed sessions keep their own model; --model/--provider always win.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

const STATE_FILE = join(homedir(), ".pi", "agent", "last-model.json");

async function loadLast(): Promise<{ provider: string; id: string } | null> {
  try {
    const parsed = JSON.parse(await readFile(STATE_FILE, "utf8"));
    if (typeof parsed?.provider === "string" && typeof parsed?.id === "string") {
      return { provider: parsed.provider, id: parsed.id };
    }
  } catch {
    // Missing or corrupt — fall back to the configured startup default.
  }
  return null;
}

async function saveLast(provider: string, id: string): Promise<void> {
  try {
    await mkdir(join(homedir(), ".pi", "agent"), { recursive: true });
    await writeFile(STATE_FILE, JSON.stringify({ provider, id }));
  } catch (err) {
    console.error("[last-model] failed to save last model: " + (err as Error).message);
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("model_select", async (event) => {
    await saveLast(event.model.provider, event.model.id);
  });

  pi.on("session_start", async (event, ctx) => {
    if (event.reason !== "startup" && event.reason !== "new") return;
    if (ctx.sessionManager.getEntries().length > 0) return;
    if (process.argv.includes("--model") || process.argv.includes("--provider")) return;
    const last = await loadLast();
    if (!last) return;
    const current = ctx.model;
    if (current?.provider === last.provider && current?.id === last.id) return;
    const model = ctx.modelRegistry.find(last.provider, last.id);
    if (model) await pi.setModel(model);
  });
}
