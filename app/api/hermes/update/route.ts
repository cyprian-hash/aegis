import { spawn } from "child_process";
import { findHermesPath, augmentedPath } from "@/lib/hermes";

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
      proc.on("close", (code) => {
        if (code === 0) {
          send("done", { ok: true, msg: "Update complete" });
        } else {
          send("error", { message: `hermes update exited with code ${code}` });
        }
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
