"use client";
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import AmbientGrid from "@/components/AmbientGrid";
import StatusBar from "@/components/StatusBar";
import Sidebar, { ViewId } from "@/components/Sidebar";
import OverviewView from "@/components/OverviewView";
import AgentsView from "@/components/AgentsView";
import AgentProfile from "@/components/AgentProfile";
import MessengerView from "@/components/MessengerView";
import TelemetryView from "@/components/TelemetryView";
import NetworkView from "@/components/NetworkView";
import MemoryView from "@/components/MemoryView";
import LogsView from "@/components/LogsView";
import MissionsView from "@/components/MissionsView";
import MCPView from "@/components/MCPView";
import { Agent } from "@/lib/agents";

export default function Page() {
  const [active, setActive] = useState<ViewId>("overview");
  const [profileAgent, setProfileAgent] = useState<Agent | null>(null);
  const [chatAgentId, setChatAgentId] = useState<string | null>(null);

  const handleProfile = (a: Agent) => {
    setProfileAgent(a);
    // also scroll up
    if (typeof window !== "undefined") window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const handleChat = (a: Agent) => {
    setChatAgentId(a.id);
    setProfileAgent(null);
    setActive("chat");
  };

  const switchView = (v: ViewId) => {
    setProfileAgent(null);
    setActive(v);
  };

  return (
    <div className="relative min-h-screen text-white overflow-x-hidden bg-[#070707]">
      <AmbientGrid />
      <div className="relative z-10 flex min-h-screen">
        <Sidebar active={active} setActive={switchView} />
        <div className="flex-1 flex flex-col min-w-0">
          <StatusBar />
          <main className="flex-1 px-6 md:px-10 py-8 max-w-[1600px] w-full mx-auto">
            <AnimatePresence mode="wait">
              <motion.div
                key={profileAgent?.id || active}
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -8 }}
                transition={{ duration: 0.35, ease: [0.22, 1, 0.36, 1] }}
              >
                {profileAgent ? (
                  <AgentProfile
                    agent={profileAgent}
                    onBack={() => setProfileAgent(null)}
                    onOpenChat={() => handleChat(profileAgent)}
                  />
                ) : (
                  <>
                    {active === "overview"  && <OverviewView
                                                  onProfileAgent={handleProfile}
                                                  onChatAgent={handleChat}
                                                  onGo={switchView}
                                                />}
                    {active === "agents"    && <AgentsView
                                                  onSelectProfile={handleProfile}
                                                  onSelectChat={handleChat}
                                                />}
                    {active === "chat"      && <MessengerView initialAgentId={chatAgentId || undefined} />}
                    {active === "missions"  && <MissionsView />}
                    {active === "logs"      && <LogsView />}
                    {active === "mcp"       && <MCPView />}
                    {active === "telemetry" && <TelemetryView />}
                    {active === "network"   && <NetworkView onSelect={handleProfile} />}
                    {active === "memory"    && <MemoryView />}
                  </>
                )}
              </motion.div>
            </AnimatePresence>
          </main>
          <footer className="border-t border-white/[0.06] px-6 py-4 text-[9px] tracking-[0.3em] text-white/30 font-mono flex justify-between flex-wrap gap-2">
            <span>AEGIS // BUILD 4.7.0-ORBITAL · LOCAL</span>
            <span>© COMMANDER · ALL FREQUENCIES</span>
          </footer>
        </div>
      </div>
    </div>
  );
}
