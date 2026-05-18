import Anthropic from "@anthropic-ai/sdk";
import { AGENTS, getAgent, isHermesAgent } from "@/lib/agents";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

interface ChatMessage {
  role: "user" | "assistant";
  content: string;
}

interface RequestBody {
  agentId?: string;
  messages: ChatMessage[];
  model?: string;
}

export async function POST(req: Request) {
  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), { status: 400 });
  }

  const agent = body.agentId ? getAgent(body.agentId) : AGENTS[0];
  if (!agent) return new Response(JSON.stringify({ error: "Unknown agent" }), { status: 404 });

  if (isHermesAgent(agent)) {
    return streamFromHermes(agent, body);
  }

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    return new Response(
      JSON.stringify({ error: "ANTHROPIC_API_KEY not set in .env.local" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  const client = new Anthropic({ apiKey });
  const encoder = new TextEncoder();
  const stream = new ReadableStream({
    async start(controller) {
      const send = (event: string, data: any) => {
        controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));
      };
      try {
        send("meta", { agent: agent.id, name: agent.name, model: agent.model });
        const response = await client.messages.stream({
          model: body.model || agent.model,
          max_tokens: 2048,
          system: agent.systemPrompt,
          messages: body.messages.map(m => ({ role: m.role, content: m.content })),
        });
        for await (const event of response) {
          if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
            send("delta", { text: event.delta.text });
          } else if (event.type === "message_stop") {
            send("done", { ok: true });
          }
        }
      } catch (err: any) {
        send("error", { message: err?.message || "Stream failed" });
      } finally {
        controller.close();
      }
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

/**
 * Stream from Hermes Agent's OpenAI-compatible endpoint.
 * Default: http://localhost:8642/v1/chat/completions
 */
async function streamFromHermes(agent: any, body: RequestBody) {
  const baseUrl = process.env.HERMES_BASE_URL || "http://localhost:8642/v1";
  const apiKey  = process.env.HERMES_API_KEY  || "local-dev";
  const model   = process.env.HERMES_MODEL    || body.model || "hermes-agent";

  const encoder = new TextEncoder();
  const stream = new ReadableStream({
    async start(controller) {
      const send = (event: string, data: any) => {
        controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));
      };
      try {
        send("meta", { agent: agent.id, name: agent.name, model });

        const upstream = await fetch(`${baseUrl}/chat/completions`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${apiKey}`,
          },
          body: JSON.stringify({
            model,
            stream: true,
            messages: [
              { role: "system", content: agent.systemPrompt },
              ...body.messages.map(m => ({ role: m.role, content: m.content })),
            ],
          }),
        });

        if (!upstream.ok || !upstream.body) {
          const text = await upstream.text().catch(() => "");
          throw new Error(
            `Hermes gateway returned ${upstream.status}. ` +
            `Is it running? Start with: hermes gateway. ${text.slice(0, 200)}`
          );
        }

        const reader = upstream.body.getReader();
        const decoder = new TextDecoder();
        let buffer = "";
        while (true) {
          const { value, done } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split("\n");
          buffer = lines.pop() || "";
          for (const line of lines) {
            const trimmed = line.trim();
            if (!trimmed || !trimmed.startsWith("data:")) continue;
            const payload = trimmed.slice(5).trim();
            if (payload === "[DONE]") {
              send("done", { ok: true });
              continue;
            }
            try {
              const json = JSON.parse(payload);
              const delta = json?.choices?.[0]?.delta?.content;
              if (delta) send("delta", { text: delta });
            } catch {
              // ignore non-JSON chunks
            }
          }
        }
      } catch (err: any) {
        send("error", {
          message: err?.message ||
            "Could not reach Hermes gateway. Run `hermes gateway` in another terminal."
        });
      } finally {
        controller.close();
      }
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
