import { spawn } from "child_process";
import { findHermesPath, augmentedPath, gatewayUp } from "@/lib/hermes";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST() {
  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    async start(controller) {
      const send = (event: string, data: any) => {
        controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));
      };

      const hermesPath = await findHermesPath();
      if (!hermesPath) {
        send("error", { message: "hermes binary not found (checked PATH, ~/.local/bin, /opt/homebrew/bin, /usr/local/bin, ~/.hermes/bin)" });
        controller.close();
        return;
      }

      const wasRunning = await gatewayUp();
      send("start", { msg: `Running ${hermesPath} update…` });

      const proc = spawn(hermesPath, ["update"], {
        shell: false,
        env: { ...process.env, PATH: augmentedPath() },
      });
      proc.stdout.on("data", (chunk) => {
        send("log", { line: chunk.toString() });
      });
      proc.stderr.on("data", (chunk) => {
        send("log", { line: chunk.toString() });
      });
      proc.on("error", (err) => {
        send("error", { message: err.message });
        controller.close();
      });
      proc.on("close", async (code) => {
        if (code !== 0) {
          send("error", { message: `hermes update exited with code ${code}` });
          controller.close();
          return;
        }
        // The update stops a running gateway; bring it back if it was up before.
        if (wasRunning && !(await gatewayUp())) {
          const startCmd = process.env.HERMES_START_CMD;
          if (!startCmd) {
            send("log", { line: "\nGateway stopped by the update. Set HERMES_START_CMD in .env.local to auto-restart it.\n" });
          } else {
            send("log", { line: `\nGateway stopped by the update — restarting: ${startCmd}\n` });
            try {
              const child = spawn("bash", ["-lc", startCmd], {
                detached: true,
                stdio: "ignore",
                env: { ...process.env, PATH: augmentedPath() },
              });
              child.unref();
              let up = false;
              for (let i = 0; i < 10; i++) {
                await new Promise(r => setTimeout(r, 2000));
                if (await gatewayUp()) { up = true; break; }
              }
              send("log", { line: up ? "✓ Gateway back online\n" : "✗ Gateway did not come back within 20s — start it manually\n" });
            } catch (e: any) {
              send("log", { line: `✗ Gateway restart failed: ${e?.message}\n` });
            }
          }
        }
        send("done", { ok: true, msg: "Update complete" });
        controller.close();
      });
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache, no-transform",
      "Connection": "keep-alive",
    },
  });
}
