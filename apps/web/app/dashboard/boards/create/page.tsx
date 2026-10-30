"use client";
import React, { useState } from "react";
import { useRouter } from "next/navigation";
import { useBoard } from "@/lib/BoardContext";
import { boardHref } from "@/lib/boardRouting";
import type { Board } from "@/lib/types";

const TEMPLATES = [
  { id: "blank", name: "Blank Canvas", icon: "📄", desc: "Start from scratch" },
  { id: "brainstorm", name: "Brainstorm", icon: "💡", desc: "Mind mapping layout" },
  { id: "wireframe", name: "Wireframe", icon: "🖼️", desc: "UI wireframing" },
  { id: "notes", name: "Meeting Notes", icon: "📝", desc: "Structured note-taking" },
  { id: "kanban", name: "Kanban Board", icon: "📋", desc: "Task management" },
  { id: "presentation", name: "Presentation", icon: "🎤", desc: "Slide deck" },
];

export default function CreateBoard() {
  const router = useRouter();
  const { createBoard } = useBoard();
  const [title, setTitle] = useState("");
  const [desc, setDesc] = useState("");
  const [template, setTemplate] = useState("blank");
  const [creating, setCreating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleCreate = async () => {
    setCreating(true);
    setError(null);
    try {
      // Local-first creation (BoardContext): a stable board record with a
      // reused id, persisted to localStorage + Firestore in one path.
      const board: Board = createBoard(
        title.trim() || 'Untitled Board',
        desc.trim() || undefined,
        template
      );
      router.push(boardHref(board));
    } catch (err) {
      console.error('Failed to create board:', err);
      setError('Board could not be created. Please retry.');
      setCreating(false);
    }
  };

  return (
    <div style={{ maxWidth: 800, margin: "0 auto" }}>
      <h1 style={{ fontSize: "1.5rem", fontWeight: 700, color: "var(--text-primary)", marginBottom: "0.25rem" }}>Create New Board</h1>
      <p style={{ fontSize: "0.8125rem", color: "var(--text-tertiary)", marginBottom: "2rem" }}>Choose a template and customize your workspace</p>

      <div className="glass-panel" style={{ padding: "2rem" }}>
        <div style={{ marginBottom: "1.5rem" }}>
          <label style={{ display: "block", fontSize: "0.75rem", fontWeight: 600, color: "var(--text-tertiary)", marginBottom: "0.5rem" }}>Board Title</label>
          <input
            className="glass-input"
            placeholder="My awesome board..."
            value={title}
            onChange={e => setTitle(e.target.value)}
            onKeyDown={e => { if (e.key === 'Enter' && !creating) handleCreate(); }}
            style={{ fontSize: "1rem" }}
          />
        </div>
        <div style={{ marginBottom: "1.5rem" }}>
          <label style={{ display: "block", fontSize: "0.75rem", fontWeight: 600, color: "var(--text-tertiary)", marginBottom: "0.5rem" }}>Description (optional)</label>
          <textarea className="glass-input" placeholder="What's this board about?" rows={3} value={desc} onChange={e => setDesc(e.target.value)} style={{ resize: "vertical" }} />
        </div>

        <label style={{ display: "block", fontSize: "0.75rem", fontWeight: 600, color: "var(--text-tertiary)", marginBottom: "0.75rem" }}>Choose Template</label>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(140px, 1fr))", gap: "0.75rem", marginBottom: "2rem" }}>
          {TEMPLATES.map(t => (
            <div key={t.id} onClick={() => setTemplate(t.id)} className="glass-panel-hover" style={{ padding: "1.25rem", textAlign: "center", cursor: "pointer", borderColor: template === t.id ? "rgba(59,130,246,0.5)" : undefined, boxShadow: template === t.id ? "0 0 0 2px rgba(59,130,246,0.2)" : undefined }}>
              <div style={{ fontSize: "2rem", marginBottom: "0.5rem" }}>{t.icon}</div>
              <div style={{ fontSize: "0.8125rem", fontWeight: 600, color: "var(--text-primary)" }}>{t.name}</div>
              <div style={{ fontSize: "0.6875rem", color: "var(--text-tertiary)", marginTop: "0.125rem" }}>{t.desc}</div>
            </div>
          ))}
        </div>

        {error && <div style={{ marginBottom: "1rem", fontSize: "0.8125rem", fontWeight: 600, color: "#ef4444" }}>{error}</div>}

        <div style={{ display: "flex", gap: "0.75rem", justifyContent: "flex-end", flexWrap: "wrap" }}>
          <button onClick={() => router.back()} className="glass-button" style={{ padding: "0.75rem 1.5rem", borderRadius: "0.75rem", color: "var(--text-secondary)", fontSize: "0.8125rem", cursor: "pointer" }}>Cancel</button>
          <button onClick={handleCreate} disabled={creating} style={{ padding: "0.75rem 1.5rem", borderRadius: "0.75rem", border: "none", background: "linear-gradient(135deg, #3b82f6, #6366f1)", color: "#fff", fontWeight: 600, cursor: "pointer", fontSize: "0.8125rem", opacity: creating ? 0.6 : 1 }}>
            {creating ? 'Creating...' : 'Create Board →'}
          </button>
        </div>
      </div>
    </div>
  );
}
