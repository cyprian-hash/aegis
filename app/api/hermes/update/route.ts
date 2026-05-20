import { spawn } from "child_process";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST() {
  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    async start(controller) {
      const send = (event: string, data: any) => {
        controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));
      };

      send("start", { msg: "Running hermes update…" });

      const proc = spawn("hermes", ["update"], { shell: false });
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
