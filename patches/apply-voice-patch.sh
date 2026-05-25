#!/bin/bash
# apply-voice-patch.sh
#
# Adds browser-native voice input (mic button) to every chat composer.
# Uses Web Speech API (SpeechRecognition) — no API keys, no extra deps.
# Works in Safari + Chrome on macOS.
#
# Run from inside the aegis project directory:
#   cd ~/projects/aegis && bash apply-voice-patch.sh

set -e

if [ ! -f package.json ] || [ ! -d components ]; then
  echo "❌ Run this from inside the aegis project directory."
  exit 1
fi

echo "📦 Backing up files to .pre-voice-backup/"
mkdir -p .pre-voice-backup/components
cp components/ChatView.tsx .pre-voice-backup/components/

echo "✏️  Creating lib/useVoiceInput.ts"
mkdir -p lib
cat > lib/useVoiceInput.ts <<'EOF'
"use client";
import { useState, useRef, useEffect, useCallback } from "react";

/**
 * Browser-native voice-to-text via the Web Speech API.
 * Works in Safari and Chrome on macOS, Chrome on Windows/Linux, Edge.
 * No API keys, no network — runs entirely in the browser.
 *
 * Usage:
 *   const { supported, listening, transcript, interim, start, stop, error } = useVoiceInput();
 *
 * - `start()` begins listening; permission prompt appears on first use.
 * - `stop()` ends listening.
 * - `transcript` is the cumulative finalized text since `start()`.
 * - `interim` is the live in-progress phrase (changes as you speak).
 */
export function useVoiceInput() {
  const [supported, setSupported] = useState(false);
  const [listening, setListening] = useState(false);
  const [transcript, setTranscript] = useState("");
  const [interim, setInterim] = useState("");
  const [error, setError] = useState<string | null>(null);
  const recognitionRef = useRef<any>(null);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const SR = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    setSupported(!!SR);
  }, []);

  const start = useCallback(() => {
    if (typeof window === "undefined") return;
    const SR = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    if (!SR) {
      setError("Voice input isn't supported in this browser. Try Safari or Chrome.");
      return;
    }

    setError(null);
    setTranscript("");
    setInterim("");

    const rec = new SR();
    rec.continuous = true;       // keep listening until stopped
    rec.interimResults = true;   // stream partial results as you speak
    rec.lang = navigator.language || "en-US";
    rec.maxAlternatives = 1;

    rec.onresult = (event: any) => {
      let finalText = "";
      let interimText = "";
      for (let i = event.resultIndex; i < event.results.length; i++) {
        const result = event.results[i];
        if (result.isFinal) {
          finalText += result[0].transcript;
        } else {
          interimText += result[0].transcript;
        }
      }
      if (finalText) {
        setTranscript(prev => (prev ? prev + " " : "") + finalText.trim());
      }
      setInterim(interimText);
    };

    rec.onerror = (event: any) => {
      const code: string = event.error;
      let msg = "Voice input error.";
      if (code === "not-allowed" || code === "service-not-allowed") {
        msg = "Microphone access denied. Allow it in your browser settings and try again.";
      } else if (code === "no-speech") {
        msg = "Didn't catch that — try speaking again.";
      } else if (code === "audio-capture") {
        msg = "No microphone found.";
      } else if (code === "network") {
        msg = "Network error during voice recognition.";
      } else if (code === "aborted") {
        msg = ""; // user-initiated stop; not an error to display
      }
      if (msg) setError(msg);
      setListening(false);
      setInterim("");
    };

    rec.onend = () => {
      setListening(false);
      setInterim("");
    };

    rec.onstart = () => {
      setListening(true);
    };

    try {
      rec.start();
      recognitionRef.current = rec;
    } catch (e: any) {
      setError(e?.message || "Could not start voice input.");
      setListening(false);
    }
  }, []);

  const stop = useCallback(() => {
    const rec = recognitionRef.current;
    if (rec) {
      try { rec.stop(); } catch {}
      recognitionRef.current = null;
    }
    setListening(false);
  }, []);

  // cleanup on unmount
  useEffect(() => () => {
    if (recognitionRef.current) {
      try { recognitionRef.current.stop(); } catch {}
      recognitionRef.current = null;
    }
  }, []);

  return { supported, listening, transcript, interim, start, stop, error, clearError: () => setError(null) };
}
EOF
echo "   ✓ hook created"

echo "✏️  Patching components/ChatView.tsx"
python3 - <<'PYEOF'
p = "components/ChatView.tsx"
src = open(p).read()

if "useVoiceInput" in src:
    print("   ⊙ already patched")
else:
    # 1. Add Mic + MicOff to lucide imports
    src = src.replace(
        'import { Send, Sparkles, Paperclip, MoreVertical, ChevronLeft, X, Smile } from "lucide-react";',
        'import { Send, Sparkles, Paperclip, MoreVertical, ChevronLeft, X, Smile, Mic } from "lucide-react";'
    )

    # 2. Add hook import after existing imports
    src = src.replace(
        'import AgentAvatar from "./AgentAvatar";',
        'import AgentAvatar from "./AgentAvatar";\nimport { useVoiceInput } from "@/lib/useVoiceInput";'
    )

    # 3. Inject voice hook call right after the `idCounter` ref (which is the last hook before useMemo)
    src = src.replace(
        "  const idCounter = useRef(2);\n",
        """  const idCounter = useRef(2);

  // voice input (browser Web Speech API)
  const voice = useVoiceInput();
  // when finalized speech arrives, append it into the textarea
  useEffect(() => {
    if (voice.transcript) {
      setText(prev => (prev ? prev.replace(/\\s+$/, "") + " " : "") + voice.transcript);
    }
  }, [voice.transcript]);
  // surface voice errors in the same error banner
  useEffect(() => {
    if (voice.error) setError(voice.error);
  }, [voice.error]);

"""
    )

    # 4. Add mic button right before the Smile button in the composer
    src = src.replace(
        '          <button className="h-8 w-8 grid place-items-center rounded-full hover:bg-white/5 text-white/40 hover:text-white shrink-0">\n            <Smile className="h-4 w-4" strokeWidth={1.5} />\n          </button>',
        """          {voice.supported && (
            <motion.button
              onClick={() => (voice.listening ? voice.stop() : voice.start())}
              whileTap={{ scale: 0.9 }}
              aria-label={voice.listening ? "Stop voice input" : "Start voice input"}
              title={voice.listening ? "Stop listening" : "Speak your message"}
              className="relative h-8 w-8 grid place-items-center rounded-full shrink-0 transition-colors"
              style={voice.listening
                ? { background: c.hex, color: "#000", boxShadow: `0 0 14px ${c.glow}` }
                : { background: "transparent", color: "rgba(255,255,255,0.4)" }}
            >
              {voice.listening
                ? <Mic className="h-4 w-4" strokeWidth={2} />
                : <Mic className="h-4 w-4" strokeWidth={1.5} />}
              {voice.listening && (
                <>
                  <motion.span
                    className="absolute inset-0 rounded-full pointer-events-none"
                    style={{ border: `2px solid ${c.hex}` }}
                    animate={{ scale: [1, 1.6, 1], opacity: [0.6, 0, 0.6] }}
                    transition={{ duration: 1.4, repeat: Infinity }}
                  />
                </>
              )}
            </motion.button>
          )}
          <button
            aria-label="Emoji"
            className="h-8 w-8 grid place-items-center rounded-full hover:bg-white/5 text-white/40 hover:text-white shrink-0">
            <Smile className="h-4 w-4" strokeWidth={1.5} />
          </button>"""
    )

    # 5. Update the placeholder to show interim transcription when listening
    src = src.replace(
        'placeholder={`Message ${agent.shortName}…`}',
        'placeholder={voice.listening ? (voice.interim || "Listening…") : `Message ${agent.shortName}…`}'
    )

    # 6. Update the helper line under the composer to mention mic when supported
    src = src.replace(
        '<span>↵ to send · ⇧↵ for newline</span>',
        '<span>{voice.supported ? "↵ to send · ⇧↵ for newline · 🎤 mic for voice" : "↵ to send · ⇧↵ for newline"}</span>'
    )

    open(p, "w").write(src)
    print("   ✓ ChatView patched with mic button + Web Speech hook")
PYEOF

echo ""
echo "✅ Voice input added to AEGIS."
echo ""
echo "Restart your dev server (Ctrl+C in the npm run dev tab, then npm run dev)."
echo ""
echo "📋 How to use:"
echo "   - Open any chat (e.g. Prime, Hermes)."
echo "   - You'll see a microphone icon between the textarea and emoji button."
echo "   - Click it. First time: browser asks for microphone permission. Allow it."
echo "   - Speak. Your words appear in the input as you talk."
echo "   - Click the mic again to stop. Press Enter to send."
echo ""
echo "💡 Works in Safari and Chrome on macOS. Firefox doesn't support Web Speech."
echo "    The mic button automatically hides on unsupported browsers."
echo ""
echo "Backups in .pre-voice-backup/ — to revert: cp -r .pre-voice-backup/* ."
