#!/usr/bin/env bash
# apply-gemini-upload-patch.sh
#
# Adds document/image upload to GEMINI-08 chats.
#  - Attach button (Paperclip) becomes active for GEMINI-08
#  - Supports PDF, images (png/jpg/webp), markdown/txt, and .docx (converted to text)
#  - Files are sent to Gemini's multimodal API as inline_data (PDF/images)
#    or folded into the prompt text (markdown/txt/docx)
#
# Requires the Gemini agent patch already applied.
#
# Run from inside the aegis project directory:
#   bash apply-gemini-upload-patch.sh

set -e
if [ ! -f package.json ] || [ ! -d components ]; then
  echo "❌ Run from inside the aegis project directory."
  exit 1
fi
if ! grep -q "generativelanguage.googleapis.com" app/api/claude/route.ts 2>/dev/null; then
  echo "❌ Gemini patch not detected. Run apply-gemini-patch.sh first."
  exit 1
fi

echo "📦 Backing up to .pre-gemini-upload-backup/"
mkdir -p .pre-gemini-upload-backup/app/api/claude .pre-gemini-upload-backup/components
cp app/api/claude/route.ts  .pre-gemini-upload-backup/app/api/claude/
cp components/ChatView.tsx   .pre-gemini-upload-backup/components/

# ----------------------------------------------------------------------------
# 1. Install mammoth (for .docx -> text in the browser)
# ----------------------------------------------------------------------------
echo "📥 Installing mammoth (for .docx text extraction)…"
npm install mammoth --save >/dev/null 2>&1 && echo "   ✓ mammoth installed" || echo "   ⚠ mammoth install failed — .docx will be unsupported, others still work"

# ----------------------------------------------------------------------------
# 2. Extend the Gemini branch in the API route to accept attachments
# ----------------------------------------------------------------------------
echo "✏️  Extending Gemini API branch to accept file attachments"
python3 - <<'PYEOF'
p = "app/api/claude/route.ts"
src = open(p).read()

if "attachments" in src:
    print("   ⊙ already supports attachments")
else:
    # 2a. Add attachments to the request body interface
    src = src.replace(
        "  activeProjectId?: string | null;\n}",
        "  activeProjectId?: string | null;\n  attachments?: Attachment[];\n}\n\ninterface Attachment {\n  name: string;\n  mimeType: string;\n  // For PDFs/images: base64 data (no data: prefix). For text/docx: already-extracted text.\n  data?: string;\n  text?: string;\n}",
        1
    )

    # 2b. In the Gemini branch, build parts from the last user message + attachments.
    # Replace the simple contents mapping with one that appends file parts to the
    # final user turn.
    old_contents = '''          // Build Gemini "contents" from the message history.
          const contents = body.messages.map(m => ({
            role: m.role === "assistant" ? "model" : "user",
            parts: [{ text: m.content }],
          }));'''
    new_contents = '''          // Build Gemini "contents" from the message history.
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
                  lastUser.parts.push({ text: `\\n\\n[Attached file: ${a.name}]\\n${a.text}` });
                } else if (a.data) {
                  lastUser.parts.push({ inline_data: { mime_type: a.mimeType, data: a.data } });
                }
              }
            }
          }'''
    src = src.replace(old_contents, new_contents, 1)
    open(p, "w").write(src)
    print("   ✓ Gemini branch now accepts attachments (inline_data + text)")
PYEOF

# ----------------------------------------------------------------------------
# 3. Wire the composer's attach button + file handling in ChatView
# ----------------------------------------------------------------------------
echo "✏️  Wiring file upload into components/ChatView.tsx"
python3 - <<'PYEOF'
import re
p = "components/ChatView.tsx"
src = open(p).read()

if "pendingFiles" in src:
    print("   ⊙ already wired")
else:
    # 3a. Ensure imports we need (useRef already there; add mammoth dynamic import later)
    # Add state for pending files near the other useState calls.
    src = src.replace(
        '  const [text, setText] = useState("");',
        '  const [text, setText] = useState("");\n  const [pendingFiles, setPendingFiles] = useState<{ name: string; mimeType: string; data?: string; text?: string }[]>([]);\n  const fileInputRef = useRef<HTMLInputElement>(null);\n  const supportsFiles = agent.id === "gemini-08";',
        1
    )

    # 3b. Add a file-reading helper + handlers before `const dispatch =`
    helper = '''
  const readFileToAttachment = async (file: File) => {
    const name = file.name;
    const lower = name.toLowerCase();
    // Text-like: read as text
    if (file.type.startsWith("text/") || lower.endsWith(".md") || lower.endsWith(".txt") || lower.endsWith(".csv")) {
      const text = await file.text();
      return { name, mimeType: "text/plain", text };
    }
    // .docx: convert to text with mammoth
    if (lower.endsWith(".docx")) {
      try {
        const mammoth = (await import("mammoth")).default || (await import("mammoth"));
        const arrayBuffer = await file.arrayBuffer();
        const result = await (mammoth as any).extractRawText({ arrayBuffer });
        return { name, mimeType: "text/plain", text: result.value };
      } catch {
        return { name, mimeType: "text/plain", text: `[Could not read ${name}. Try exporting it as PDF.]` };
      }
    }
    // PDF + images: base64 inline_data
    if (file.type === "application/pdf" || file.type.startsWith("image/")) {
      const buf = await file.arrayBuffer();
      let binary = "";
      const bytes = new Uint8Array(buf);
      for (let i = 0; i < bytes.byteLength; i++) binary += String.fromCharCode(bytes[i]);
      const base64 = btoa(binary);
      return { name, mimeType: file.type, data: base64 };
    }
    // Fallback: try as text
    try {
      const text = await file.text();
      return { name, mimeType: "text/plain", text };
    } catch {
      return { name, mimeType: "application/octet-stream", text: `[Unsupported file type: ${name}]` };
    }
  };

  const onFilesPicked = async (files: FileList | null) => {
    if (!files || files.length === 0) return;
    const next: { name: string; mimeType: string; data?: string; text?: string }[] = [];
    for (const f of Array.from(files)) {
      next.push(await readFileToAttachment(f));
    }
    setPendingFiles(prev => [...prev, ...next]);
  };
'''
    src = src.replace("  const dispatch = async (q: string) => {", helper + "\n  const dispatch = async (q: string) => {", 1)

    # 3c. Allow sending when there are files even if text is empty; clear files after.
    src = src.replace(
        "  const dispatch = async (q: string) => {\n    if (!q.trim() || busy) return;",
        "  const dispatch = async (q: string) => {\n    if ((!q.trim() && pendingFiles.length === 0) || busy) return;",
        1
    )

    # 3d. Include attachments in the POST body and clear after sending
    src = src.replace(
        "        body: JSON.stringify({ agentId: agent.id, messages: apiMessages, activeProjectId }),",
        "        body: JSON.stringify({ agentId: agent.id, messages: apiMessages, activeProjectId, attachments: pendingFiles }),",
        1
    )
    # clear pending files right after we capture them into the request (after setText(""))
    src = src.replace(
        '    setText("");\n    setBusy(true);',
        '    setText("");\n    const sentFiles = pendingFiles;\n    setPendingFiles([]);\n    setBusy(true);',
        1
    )
    # use sentFiles in the body instead of pendingFiles (avoid race with setState)
    src = src.replace(
        "activeProjectId, attachments: pendingFiles }),",
        "activeProjectId, attachments: sentFiles }),",
        1
    )
    # reflect attachment names in the user message bubble
    src = src.replace(
        '    const userMsg: Msg = { id: idCounter.current++, role: "user", text: q, ts: new Date() };',
        '    const fileNote = pendingFiles.length ? (q.trim() ? "\\n\\n" : "") + pendingFiles.map(f => `📎 ${f.name}`).join("\\n") : "";\n    const userMsg: Msg = { id: idCounter.current++, role: "user", text: q + fileNote, ts: new Date() };',
        1
    )

    # 3e. Replace the inert Paperclip button with a working one (GEMINI-08 only) + hidden input + chips
    old_btn = '''          <button className="h-8 w-8 grid place-items-center rounded-full hover:bg-white/5 text-white/40 hover:text-white shrink-0">
            <Paperclip className="h-4 w-4" strokeWidth={1.5} />
          </button>'''
    new_btn = '''          <button
            onClick={() => supportsFiles && fileInputRef.current?.click()}
            disabled={!supportsFiles}
            title={supportsFiles ? "Attach PDF, image, markdown, or Word doc" : "File upload is available on GEMINI-08 (Vision Core)"}
            className={`h-8 w-8 grid place-items-center rounded-full shrink-0 ${supportsFiles ? "hover:bg-white/5 text-white/40 hover:text-white" : "text-white/15 cursor-not-allowed"}`}>
            <Paperclip className="h-4 w-4" strokeWidth={1.5} />
          </button>
          <input
            ref={fileInputRef}
            type="file"
            multiple
            accept=".pdf,.png,.jpg,.jpeg,.webp,.gif,.md,.txt,.csv,.docx,application/pdf,image/*,text/*"
            className="hidden"
            onChange={(e) => { onFilesPicked(e.target.files); if (e.target) e.target.value = ""; }}
          />'''
    src = src.replace(old_btn, new_btn, 1)

    # 3f. Render attachment chips above the composer row when files are pending
    src = src.replace(
        '''      {/* COMPOSER */}
      <div className="border-t border-white/[0.06] bg-black/30 px-3 md:px-5 py-3">''',
        '''      {/* COMPOSER */}
      <div className="border-t border-white/[0.06] bg-black/30 px-3 md:px-5 py-3">
        {pendingFiles.length > 0 && (
          <div className="flex flex-wrap gap-1.5 mb-2">
            {pendingFiles.map((f, i) => (
              <span key={i} className="flex items-center gap-1.5 rounded-lg bg-white/[0.05] border border-white/10 px-2 py-1 text-[11px] text-white/70">
                <Paperclip className="h-3 w-3" strokeWidth={1.5} />
                {f.name}
                <button onClick={() => setPendingFiles(prev => prev.filter((_, j) => j !== i))}
                  className="ml-1 text-white/40 hover:text-white">
                  <X className="h-3 w-3" strokeWidth={2} />
                </button>
              </span>
            ))}
          </div>
        )}''',
        1
    )

    # 3g. Send button should also enable when files are attached
    src = src.replace(
        "            disabled={!text.trim() || busy}",
        "            disabled={(!text.trim() && pendingFiles.length === 0) || busy}",
        1
    )
    src = src.replace(
        'style={{ background: c.hex, color: "#000", boxShadow: text.trim() && !busy ? `0 0 14px ${c.glow}` : "none" }}',
        'style={{ background: c.hex, color: "#000", boxShadow: (text.trim() || pendingFiles.length) && !busy ? `0 0 14px ${c.glow}` : "none" }}',
        1
    )

    open(p, "w").write(src)
    print("   ✓ ChatView wired: attach button, file reading, chips, send-with-files")
PYEOF

echo ""
echo "✅ GEMINI-08 document upload installed."
echo ""
echo "Restart:  aegis-control restart"
echo ""
echo "How to use:"
echo "   1. Open Chat → GEMINI-08 (the paperclip is active only for Gemini)"
echo "   2. Click the paperclip, pick PDF / image / .md / .txt / .docx files"
echo "   3. They appear as chips above the composer"
echo "   4. Type an instruction like: 'Read these Jetpedia docs and write a tight"
echo "      project brief: audience, positioning, site structure, goals, competitors.'"
echo "   5. Send. GEMINI reads them and replies. Paste the brief into"
echo "      AEGIS/Projects/jetpedia.md under ## Notes."
echo ""
echo "Format notes:"
echo "   - PDF + images  → read natively by Gemini"
echo "   - .md / .txt / .csv → folded in as text"
echo "   - .docx → converted to text via mammoth (if it looks garbled, export as PDF)"
echo ""
echo "Backups in .pre-gemini-upload-backup/ — to revert: cp -r .pre-gemini-upload-backup/* ."
