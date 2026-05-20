"use client";
import { useState, useEffect, useCallback } from "react";
import { Project } from "./projects";

const ACTIVE_KEY = "aegis_active_project";

export function useProjects() {
  const [projects, setProjects] = useState<Project[]>([]);
  // CRITICAL: never read localStorage during render — that creates a server/client mismatch.
  // Start with null on both server AND first client render, then sync from localStorage in useEffect.
  const [activeId, setActiveIdState] = useState<string | null>(null);
  const [hydrated, setHydrated] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    try {
      const res = await fetch("/api/projects", { cache: "no-store" });
      const data = await res.json();
      if (!data.ok) {
        setError(data.error || "Failed to load projects");
        setProjects([]);
      } else {
        setProjects(data.projects || []);
        setError(null);
      }
    } catch (err: any) {
      setError(err?.message || "Network error");
    } finally {
      setLoading(false);
    }
  }, []);

  // Sync localStorage AFTER first paint (client only)
  useEffect(() => {
    try {
      const saved = window.localStorage.getItem(ACTIVE_KEY);
      if (saved) setActiveIdState(saved);
    } catch { /* ignore */ }
    setHydrated(true);
    refresh();
  }, [refresh]);

  const setActiveId = useCallback((id: string | null) => {
    setActiveIdState(id);
    try {
      if (id) window.localStorage.setItem(ACTIVE_KEY, id);
      else window.localStorage.removeItem(ACTIVE_KEY);
    } catch { /* ignore */ }
  }, []);

  // While not hydrated, pretend activeId is null so server and first client
  // render produce identical HTML. After hydration the real value flows in.
  const safeActiveId = hydrated ? activeId : null;
  const activeProject = safeActiveId ? projects.find(p => p.id === safeActiveId) || null : null;

  return {
    projects,
    activeId: safeActiveId,
    activeProject,
    setActiveId,
    loading,
    error,
    hydrated,
    refresh,
  };
}
