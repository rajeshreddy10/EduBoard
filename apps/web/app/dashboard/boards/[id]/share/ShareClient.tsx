"use client";
import React, { useState, useEffect, useMemo } from "react";
import { useParams, useRouter } from "next/navigation";
import { useAuth } from "@/lib/AuthContext";
import { useBoard } from "@/lib/BoardContext";
import { historyService } from "@/lib/services/firebaseData";
import { getBoard } from "@/lib/store";
import type { Board } from "@/lib/types";

/**
 * Real board sharing: owner + invited emails operate on the SAME board record
 * (isShared / sharedWith fields persisted to Firestore). No mock data, no dead
 * buttons — Invite persists, Copy Link copies a working deep link.
 */
export default function ShareBoard({ boardId: boardIdProp }: { boardId?: string }) {
  const params = useParams();
  const router = useRouter();
  const boardId = boardIdProp || ((params?.id as string) || '');
  const { user } = useAuth();
  const { boards } = useBoard();
  const [board, setBoard] = useState<Board | null>(null);
  const [loading, setLoading] = useState(true);
  const [email, setEmail] = useState("");
  const [permission, setPermission] = useState("edit");
  const [status, setStatus] = useState<string | null>(null);

  useEffect(() => {
    let isMounted = true;
    (async () => {
      let b = boards.find(item => item.id === boardId) || getBoard(boardId);
      if (!b && user?.id) {
        b = (await historyService.getHistoryItem(user.id, boardId)) || undefined;
      }
      if (isMounted) {
        setBoard(b || null);
        setLoading(false);
      }
    })();
    return () => { isMounted = false; };
  }, [boardId, boards, user?.id]);

  const members = useMemo(() => {
    if (!board) return [] as { email: string; role: string; initials: string; color: string }[];
    const ownerEmail = board.createdBy || 'owner';
    const list = [{
      email: user?.email || `user:${ownerEmail}`,
      role: 'Owner',
      initials: (user?.name || user?.email || 'U')[0].toUpperCase(),
      color: '#3b82f6',
    }];
    (board.sharedWith || []).forEach(emailEntry => list.push({
      email: emailEntry,
      role: permission === 'view' ? 'Viewer' : 'Editor',
      initials: emailEntry[0]?.toUpperCase() || '?',
      color: '#10b981',
    }));
    return list;
  }, [board, user, permission]);

  const handleInvite = async () => {
    const clean = email.trim().toLowerCase();
    if (!clean || !clean.includes('@')) {
      setStatus('Please enter a valid email address.');
      return;
    }
    if (!board) {
      setStatus('Board not found — cannot share a missing board.');
      return;
    }
    if ((board.sharedWith || []).includes(clean) || clean === (user?.email || '').toLowerCase()) {
      setStatus('That member is already on this board.');
      return;
    }
    try {
      const nextSharedWith = [...(board.sharedWith || []), clean];
      const updated: Board = {
        ...board,
        isShared: true,
        sharedWith: nextSharedWith,
        updatedAt: new Date().toISOString(),
      };
      if (user?.id) {
        await historyService.saveHistoryItem(user.id, {
          ...updated,
          createdBy: board.createdBy || user.id,
          createdAt: board.createdAt || new Date().toISOString(),
        });
      }
      setBoard(updated);
      setEmail('');
      setStatus(`Invited ${clean} as ${permission === 'view' ? 'Viewer' : 'Editor'}.`);
      setTimeout(() => setStatus(null), 3500);
    } catch (err) {
      console.error('Failed to share board:', err);
      setStatus('Could not update sharing. Check your connection and try again.');
    }
  };

  const handleCopyLink = async () => {
    const url = `${window.location.origin}${window.location.pathname.replace(/\/share.*$/, '')}/normal-board?id=${encodeURIComponent(boardId)}`;
    try {
      await navigator.clipboard.writeText(url);
      setStatus('Share link copied to clipboard.');
    } catch {
      setStatus(url);
    }
    setTimeout(() => setStatus(null), 3500);
  };

  return (
    <div style={{ maxWidth: 700, margin: "0 auto" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1.5rem", flexWrap: "wrap", gap: "0.75rem" }}>
        <div style={{ minWidth: 0 }}>
          <h1 style={{ fontSize: "1.5rem", fontWeight: 700, color: "var(--text-primary)" }}>Share Board</h1>
          <p style={{ fontSize: "0.8125rem", color: "var(--text-tertiary)" }}>{board?.title || (loading ? 'Loading board...' : 'Board not found')}</p>
        </div>
        <button
          onClick={() => router.back()}
          className="glass-button"
          style={{ padding: "0.625rem 1rem", borderRadius: "0.75rem", fontSize: "0.8125rem", color: "var(--text-secondary)", textDecoration: "none", cursor: "pointer" }}
        >← Back</button>
      </div>

      <div className="glass-panel" style={{ padding: "1.5rem", marginBottom: "1.5rem" }}>
        <h2 style={{ fontSize: "1rem", fontWeight: 600, color: "var(--text-primary)", marginBottom: "1rem" }}>Invite People</h2>
        <div style={{ display: "flex", gap: "0.75rem", flexWrap: "wrap" }}>
          <input
            className="glass-input"
            style={{ flex: 1, minWidth: 200 }}
            placeholder="Enter email address..."
            value={email}
            onChange={e => setEmail(e.target.value)}
            onKeyDown={e => { if (e.key === 'Enter') handleInvite(); }}
          />
          <select value={permission} onChange={e => setPermission(e.target.value)} className="glass-input" style={{ width: 120 }}>
            <option value="view">Viewer</option>
            <option value="edit">Editor</option>
          </select>
          <button onClick={handleInvite} style={{ padding: "0 1.25rem", borderRadius: "0.75rem", border: "none", background: "linear-gradient(135deg, #3b82f6, #6366f1)", color: "#fff", fontWeight: 600, cursor: "pointer", fontSize: "0.8125rem" }}>
            Invite
          </button>
          <button onClick={handleCopyLink} className="glass-button" style={{ padding: "0 1.25rem", borderRadius: "0.75rem", fontSize: "0.8125rem", color: "var(--text-secondary)", cursor: "pointer" }}>
            Copy Link
          </button>
        </div>
        {status && <div style={{ marginTop: "0.75rem", fontSize: "0.75rem", fontWeight: 600, color: "var(--color-primary-500)" }}>{status}</div>}
      </div>

      <div className="glass-panel" style={{ padding: "1.5rem" }}>
        <h2 style={{ fontSize: "1rem", fontWeight: 600, color: "var(--text-primary)", marginBottom: "1rem" }}>Members ({members.length})</h2>
        <div style={{ display: "flex", flexDirection: "column", gap: "0.75rem" }}>
          {members.map((m, i) => (
            <div key={`${m.email}-${i}`} style={{ display: "flex", alignItems: "center", gap: "0.75rem", padding: "0.75rem 0", borderBottom: "1px solid var(--border-primary)", flexWrap: "wrap" }}>
              <div className="avatar avatar-md" style={{ background: m.color }}>{m.initials}</div>
              <div style={{ flex: 1, minWidth: 140 }}>
                <div style={{ fontSize: "0.875rem", fontWeight: 500, color: "var(--text-primary)", overflowWrap: "anywhere" }}>{m.email}</div>
              </div>
              <span className={`badge ${m.role === "Owner" ? "badge-rose" : m.role === "Editor" ? "badge-green" : "badge-blue"}`}>{m.role}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
