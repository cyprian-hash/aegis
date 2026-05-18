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
