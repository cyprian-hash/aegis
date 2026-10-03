#!/usr/bin/env bash
# apply-new-project-patch.sh
# Enables the "+ NEW PROJECT" button in the Projects view. It was a disabled
# stub; the backend POST /api/projects already creates vault files with correct
# frontmatter. This adds a create modal (name, description, status, color,
# website, tags), posts to that API, and refreshes the grid. The new project
# also gets the standard folder structure via the API-written .md file.
# Built/verified against the real repo.
set -e
if [ ! -f components/ProjectsView.tsx ]; then
  echo "❌ Run from inside the aegis project directory."; exit 1
fi

echo "📦 Backing up to .pre-newproject-backup/"
mkdir -p .pre-newproject-backup/components
cp components/ProjectsView.tsx .pre-newproject-backup/components/

echo "✏️  Wiring the NEW PROJECT button + create modal (ProjectsView.tsx)"
python3 - <<'PYEOF'
p = "components/ProjectsView.tsx"; src = open(p).read()
changed = []

# 1. Import slugify alongside existing lib/projects imports.
old_imp = 'import { Project, colorTokens, STATUS_COLOR, ProjectStatus } from "@/lib/projects";'
new_imp = 'import { Project, colorTokens, STATUS_COLOR, ProjectStatus, slugify } from "@/lib/projects";'
if old_imp in src:
    src = src.replace(old_imp, new_imp, 1); changed.append("slugify imported")
elif "slugify" in src:
    changed.append("slugify already imported (skipped)")

# 2. Add showNew state.
old_state = '  const [discoveryReport, setDiscoveryReport] = useState<string | null>(null);'
new_state = old_state + '\n  const [showNew, setShowNew] = useState(false);'
if old_state in src and "showNew" not in src:
    src = src.replace(old_state, new_state, 1); changed.append("showNew state added")

# 3. Enable the button.
old_btn = '''          <button disabled
            className="flex items-center gap-2 px-4 py-2 rounded-full border border-white/[0.08] text-white/30 cursor-not-allowed font-mono text-[11px] tracking-[0.18em]">
            <Plus className="h-3 w-3" strokeWidth={2} /> NEW PROJECT
          </button>'''
new_btn = '''          <button onClick={() => setShowNew(true)}
            className="flex items-center gap-2 px-4 py-2 rounded-full border border-amber-400/30 bg-amber-400/[0.06] hover:bg-amber-400/[0.12] hover:border-amber-400/60 font-mono text-[11px] tracking-[0.18em] text-amber-300 transition-colors">
            <Plus className="h-3 w-3" strokeWidth={2} /> NEW PROJECT
          </button>'''
if old_btn in src:
    src = src.replace(old_btn, new_btn, 1); changed.append("NEW PROJECT button enabled")
elif "setShowNew(true)" in src:
    changed.append("button already enabled (skipped)")

# 4. Render the modal next to the detail modal.
old_modal = '''      <AnimatePresence>
        {selected && ('''
new_modal = '''      <AnimatePresence>
        {showNew && (
          <NewProjectModal
            existingIds={projects.map(p => p.id)}
            onClose={() => setShowNew(false)}
            onCreated={() => { setShowNew(false); onRefresh(); }}
          />
        )}
        {selected && ('''
if old_modal in src and "NewProjectModal" not in src:
    src = src.replace(old_modal, new_modal, 1); changed.append("modal mounted in AnimatePresence")

# 5. Append the NewProjectModal component.
if "function NewProjectModal" not in src:
    src += '''

// --- New Project modal -------------------------------------------------------
const PRESET_COLORS = ["#F5B400", "#3B82F6", "#10B981", "#A855F7", "#E11D48", "#00E888", "#F59E0B", "#14B8A6", "#285ED2", "#94A3B8"];

function NewProjectModal({ existingIds, onClose, onCreated }: {
  existingIds: string[]; onClose: () => void; onCreated: () => void;
}) {
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [status, setStatus] = useState<ProjectStatus>("idea");
  const [color, setColor] = useState(PRESET_COLORS[0]);
  const [website, setWebsite] = useState("");
  const [tags, setTags] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const id = slugify(name);
  const duplicate = !!id && existingIds.includes(id);

  const submit = async () => {
    if (!name.trim() || !id || duplicate || saving) return;
    setSaving(true); setError(null);
    try {
      const res = await fetch("/api/projects", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          id, name: name.trim(),
          description: description.trim(),
          status, color,
          website: website.trim() || undefined,
          tags: tags.split(",").map(t => t.trim()).filter(Boolean),
          repos: [], hosting: [],
        }),
      });
      const data = await res.json();
      if (data.ok) onCreated();
      else setError(data.error || "Create failed");
    } catch (err: any) {
      setError(err?.message || "Network error");
    } finally { setSaving(false); }
  };

  const field = "w-full rounded-xl border border-white/10 bg-black/40 px-3.5 py-2.5 text-[13px] text-white placeholder-white/25 outline-none focus:border-amber-400/50";
  const label = "block font-mono text-[9px] tracking-[0.25em] text-white/45 mb-1.5";

  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
      className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4" onClick={onClose}>
      <motion.div initial={{ opacity: 0, scale: 0.96, y: 10 }} animate={{ opacity: 1, scale: 1, y: 0 }} exit={{ opacity: 0, scale: 0.96, y: 10 }}
        className="w-full max-w-md rounded-2xl border border-white/[0.09] bg-[#0b0b0b] p-6 max-h-[85vh] overflow-y-auto"
        onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-5">
          <div>
            <div className="font-mono text-[10px] tracking-[0.28em] text-amber-300/80 mb-1">PORTFOLIO</div>
            <div className="text-[18px] text-white font-medium">New Project</div>
          </div>
          <button onClick={onClose} className="h-7 w-7 grid place-items-center rounded-full hover:bg-white/5 text-white/40 hover:text-white">
            <X className="h-4 w-4" strokeWidth={1.5} />
          </button>
        </div>

        <div className="space-y-4">
          <div>
            <label className={label}>NAME *</label>
            <input autoFocus value={name} onChange={e => setName(e.target.value)} placeholder="e.g. Loc8ID" className={field} />
            {id && (
              <div className="mt-1 font-mono text-[10px] text-white/30">
                id: {id}{duplicate && <span className="text-rose-400 ml-2">already exists</span>}
              </div>
            )}
          </div>
          <div>
            <label className={label}>DESCRIPTION</label>
            <input value={description} onChange={e => setDescription(e.target.value)} placeholder="One sharp sentence" className={field} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className={label}>STATUS</label>
              <select value={status} onChange={e => setStatus(e.target.value as ProjectStatus)}
                className={field + " appearance-none"}>
                <option value="idea">Concept</option>
                <option value="building">In development</option>
                <option value="live">Live</option>
                <option value="archived">Archived</option>
              </select>
            </div>
            <div>
              <label className={label}>WEBSITE</label>
              <input value={website} onChange={e => setWebsite(e.target.value)} placeholder="https://…" className={field} />
            </div>
          </div>
          <div>
            <label className={label}>COLOR</label>
            <div className="flex items-center gap-2 flex-wrap">
              {PRESET_COLORS.map(c => (
                <button key={c} onClick={() => setColor(c)}
                  className={`h-6 w-6 rounded-full border-2 transition-transform ${color === c ? "border-white scale-110" : "border-transparent hover:scale-105"}`}
                  style={{ background: c, boxShadow: color === c ? `0 0 10px ${c}aa` : "none" }} />
              ))}
              <input value={color} onChange={e => setColor(e.target.value)}
                className="w-24 rounded-lg border border-white/10 bg-black/40 px-2 py-1 font-mono text-[11px] text-white/70 outline-none focus:border-amber-400/50" />
            </div>
          </div>
          <div>
            <label className={label}>TAGS (COMMA-SEPARATED)</label>
            <input value={tags} onChange={e => setTags(e.target.value)} placeholder="saas, web3, ios" className={field} />
          </div>

          {error && <div className="rounded-xl border border-rose-500/25 bg-rose-500/[0.06] px-3.5 py-2.5 text-[12px] text-rose-300/90">{error}</div>}

          <button onClick={submit} disabled={!name.trim() || !id || duplicate || saving}
            className="w-full mt-1 rounded-full bg-amber-400 hover:bg-amber-300 disabled:opacity-40 disabled:cursor-not-allowed text-black font-mono text-[12px] tracking-[0.2em] font-medium py-3 transition-colors">
            {saving ? "CREATING…" : "CREATE PROJECT"}
          </button>
          <div className="text-[10px] text-white/30 leading-relaxed">
            Creates AEGIS/Projects/{id || "<id>"}.md in your vault with proper frontmatter. Add the brief later under ## Notes.
          </div>
        </div>
      </motion.div>
    </motion.div>
  );
}
'''
    changed.append("NewProjectModal component appended")

open(p, "w").write(src)
for c in changed: print(f"   ✓ {c}")
if len(changed) < 5: print(f"   ⚠ only {len(changed)}/5 changes applied — check anchors")
PYEOF

echo ""
echo "✅ New Project creation enabled."
echo ""
echo "Restart:  aegis-control restart"
echo ""
echo "The + NEW PROJECT button (Projects view, top right) now opens a create"
echo "form: name, description, status, color, website, tags. It posts to the"
echo "existing /api/projects endpoint, which writes the vault .md with correct"
echo "frontmatter — no hand-editing, no frontmatter breakage. The new project"
echo "appears in the grid and the switcher immediately."
echo ""
echo "Backups in .pre-newproject-backup/ — revert: cp -r .pre-newproject-backup/* ."
