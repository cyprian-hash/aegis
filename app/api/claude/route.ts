import Anthropic from "@anthropic-ai/sdk";
import { buildContextBlock } from "@/lib/context";
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
  activeProjectId?: string | null;
  attachments?: Attachment[];
}

interface Attachment {
  name: string;
  mimeType: string;
  // For PDFs/images: base64 data (no data: prefix). For text/docx: already-extracted text.
  data?: string;
  text?: string;
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

  // Persistent operator/business/project context from the Obsidian vault.
  const contextBlock = await buildContextBlock(body.activeProjectId);
  const composedSystem = contextBlock
    ? `${contextBlock}\n\n---\n\n${agent.systemPrompt}`
    : agent.systemPrompt;

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

  // ---- Perplexity (ORACLE) branch -----------------------------------------
  const _model = body.model || agent.model;
  if (_model.startsWith("sonar")) {
    const pplxKey = process.env.PERPLEXITY_API_KEY;
    if (!pplxKey) {
      return new Response(
        JSON.stringify({ error: "PERPLEXITY_API_KEY not set in .env.local" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
    const model = process.env.PERPLEXITY_MODEL || _model;
    const encoder = new TextEncoder();
    const stream = new ReadableStream({
      async start(controller) {
        const send = (event: string, data: any) => {
          controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));
        };
        try {
          send("meta", { agent: agent.id, name: agent.name, model });
          const messages = [
            { role: "system", content: composedSystem },
            ...body.messages.map(m => ({ role: m.role, content: m.content })),
          ];
          const resp = await fetch("https://api.perplexity.ai/chat/completions", {
            method: "POST",
            headers: { "Authorization": `Bearer ${pplxKey}`, "Content-Type": "application/json" },
            body: JSON.stringify({ model, messages, stream: true }),
          });
          if (!resp.ok || !resp.body) {
            const errText = await resp.text().catch(() => "");
            send("error", { message: `Perplexity API ${resp.status}: ${errText.slice(0, 300)}` });
            controller.close(); return;
          }
          const reader = resp.body.getReader();
          const decoder = new TextDecoder();
          let buffer = "";
          let citations: string[] = [];
          while (true) {
            const { value, done } = await reader.read();
            if (done) break;
            buffer += decoder.decode(value, { stream: true });
            const lines = buffer.split("\n");
            buffer = lines.pop() || "";
            for (const line of lines) {
              const trimmed = line.trim();
              if (!trimmed.startsWith("data:")) continue;
              const payload = trimmed.slice(5).trim();
              if (payload === "[DONE]") continue;
              try {
                const json = JSON.parse(payload);
                if (Array.isArray(json.citations) && json.citations.length) citations = json.citations;
                const delta = json.choices?.[0]?.delta?.content;
                if (delta) send("delta", { text: delta });
              } catch { /* partial chunk */ }
            }
          }
          if (citations.length) {
            const list = citations.map((c, i) => `${i + 1}. ${c}`).join("\n");
            send("delta", { text: `\n\n**Sources:**\n${list}` });
          }
          send("done", { ok: true });
          controller.close();
        } catch (err: any) {
          send("error", { message: err?.message || "Perplexity request failed" });
          controller.close();
        }
      },
    });
    return new Response(stream, {
      headers: { "Content-Type": "text/event-stream", "Cache-Control": "no-cache, no-transform", "Connection": "keep-alive" },
    });
  }

  // ---- Gemini branch -------------------------------------------------------
  const effectiveModel = body.model || agent.model;
  if (effectiveModel.startsWith("gemini")) {
    const geminiKey = process.env.GEMINI_API_KEY;
    if (!geminiKey) {
      return new Response(
        JSON.stringify({ error: "GEMINI_API_KEY not set in .env.local" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
    const model = process.env.GEMINI_MODEL || effectiveModel;
    const encoder = new TextEncoder();
    const stream = new ReadableStream({
      async start(controller) {
        const send = (event: string, data: any) => {
          controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));
        };
        try {
          send("meta", { agent: agent.id, name: agent.name, model });

          // Build Gemini "contents" from the message history.
          const contents: any[] = body.messages.map(m => ({
            role: m.role === "assistant" ? "model" : "user",
            parts: [{ text: m.content }],
          }));
          // Attach files to the final user turn (if any).
          const atts = body.attachments || [];
          if (atts.length && contents.length) {
            const lastUser = [...contents].reverse().find(c => c.role === "user");
            if (lastUser) {
              for (const a of atts) {
                if (a.text) {
                  lastUser.parts.push({ text: `\n\n[Attached file: ${a.name}]\n${a.text}` });
                } else if (a.data) {
                  lastUser.parts.push({ inline_data: { mime_type: a.mimeType, data: a.data } });
                }
              }
            }
          }

          const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:streamGenerateContent?alt=sse`;
          const res = await fetch(url, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-goog-api-key": geminiKey,
            },
            body: JSON.stringify({
              systemInstruction: { parts: [{ text: composedSystem }] },
              contents,
              generationConfig: { maxOutputTokens: 2048 },
            }),
          });

          if (!res.ok || !res.body) {
            const errText = await res.text().catch(() => "");
            send("error", { message: `Gemini API ${res.status}: ${errText.slice(0, 300)}` });
            controller.close();
            return;
          }

          const reader = res.body.getReader();
          const decoder = new TextDecoder();
          let buf = "";
          while (true) {
            const { value, done } = await reader.read();
            if (done) break;
            buf += decoder.decode(value, { stream: true });
            const lines = buf.split("\n");
            buf = lines.pop() || "";
            for (const line of lines) {
              const trimmed = line.trim();
              if (!trimmed.startsWith("data:")) continue;
              const payload = trimmed.slice(5).trim();
              if (!payload || payload === "[DONE]") continue;
              try {
                const json = JSON.parse(payload);
                const parts = json?.candidates?.[0]?.content?.parts;
                if (Array.isArray(parts)) {
                  for (const part of parts) {
                    if (part?.text) send("delta", { text: part.text });
                  }
                }
              } catch { /* skip non-JSON keepalive lines */ }
            }
          }
          send("done", { ok: true });
        } catch (err: any) {
          send("error", { message: err?.message || "Gemini stream failed" });
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
  // ---- end Gemini branch ---------------------------------------------------

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
          system: composedSystem,
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
