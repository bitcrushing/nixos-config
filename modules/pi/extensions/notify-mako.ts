// Desktop notification when pi settles and waits for input. `agent_settled`
// (not `agent_end`) fires only once pi will not retry/compact/continue itself.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFile } from "node:child_process";

export default function (pi: ExtensionAPI) {
  pi.on("agent_settled", async (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    execFile("notify-send", ["-a", "pi", "Pi request completed"], (err) => {
      if (err) console.error("[notify-mako] notify-send failed: " + err.message);
    });
  });
}
