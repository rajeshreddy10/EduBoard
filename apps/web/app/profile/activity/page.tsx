'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import { ArrowLeft, Clock, BookOpen, Pencil, Users, Award, Trash2, LogOut, Settings } from 'lucide-react';

type ActivityType = 'board_created' | 'board_edited' | 'board_shared' | 'export' | 'login' | 'settings_changed';

interface Activity {
  id: string; type: ActivityType; title: string; detail: string;
  time: string; icon: string;
}

const TYPE_COLORS: Record<ActivityType, string> = {
  board_created: '#6366f1', board_edited: '#8b5cf6', board_shared: '#10b981',
  export: '#06b6d4', login: '#6b7280', settings_changed: '#6b7280'
};

const DEMO: Activity[] = [
  { id: '1', type: 'board_created', title: 'Created new board', detail: '"Calculus Chapter 6 — Integration"', time: '10 min ago', icon: '📋' },
  { id: '2', type: 'board_shared', title: 'Board shared', detail: '"Advanced Mathematics" with 3 team members', time: '1 hour ago', icon: '👥' },
  { id: '3', type: 'board_edited', title: 'Board updated', detail: '"Physics Lab Diagrams" · Annotations added', time: '3 hours ago', icon: '✏️' },
  { id: '4', type: 'export', title: 'Exported board', detail: '"Math Chapter 5" as PDF', time: '5 hours ago', icon: '📤' },
  { id: '5', type: 'board_created', title: 'Created new board', detail: '"Statistics — Normal Distribution"', time: '1 day ago', icon: '📋' },
  { id: '6', type: 'login', title: 'Signed in', detail: 'EduBoard Web Client · Active session', time: '2 days ago', icon: '🔐' },
  { id: '7', type: 'settings_changed', title: 'Settings updated', detail: 'Switched to Dark theme', time: '3 days ago', icon: '⚙️' },
];

const FILTERS: { key: ActivityType | 'all'; label: string }[] = [
  { key: 'all', label: 'All' },
  { key: 'board_created', label: 'Boards' },
  { key: 'board_shared', label: 'Shared' },
  { key: 'export', label: 'Exports' },
  { key: 'settings_changed', label: 'Settings' },
];

export default function ActivityPage() {
  const router = useRouter();
  const [filter, setFilter] = useState<ActivityType | 'all'>('all');
  const activities = filter === 'all' ? DEMO : DEMO.filter(a => a.type === filter || (filter === 'board_created' && a.type === 'board_edited'));

  // Group by day
  const today = activities.filter(a => a.time.includes('min') || a.time.includes('hour'));
  const yesterday = activities.filter(a => a.time.includes('1 day'));
  const older = activities.filter(a => !a.time.includes('min') && !a.time.includes('hour') && !a.time.includes('1 day'));

  const renderGroup = (title: string, items: Activity[]) => {
    if (items.length === 0) return null;
    return (
      <div className="mb-6" key={title}>
        <h3 className="text-xs font-semibold text-[var(--text-tertiary)] uppercase tracking-wider mb-3">{title}</h3>
        <div className="space-y-2">
          {items.map(a => {
            const color = TYPE_COLORS[a.type];
            return (
              <div key={a.id} className="flex items-start gap-4 p-4 rounded-2xl bg-[var(--bg-secondary)] border border-[var(--border-primary)] hover:border-[var(--color-primary-500)]/30 transition-all">
                <div className="w-10 h-10 rounded-2xl flex items-center justify-center text-lg flex-shrink-0" style={{ background: `${color}22` }}>
                  {a.icon}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-[var(--text-primary)]">{a.title}</p>
                  <p className="text-sm text-[var(--text-tertiary)] truncate">{a.detail}</p>
                </div>
                <div className="flex items-center gap-1.5 flex-shrink-0">
                  <Clock className="w-3 h-3 text-[var(--text-tertiary)]" />
                  <span className="text-xs text-[var(--text-tertiary)]">{a.time}</span>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    );
  };

  return (
    <div className="min-h-screen bg-[var(--bg-primary)]">
      <header className="px-6 py-4 bg-[var(--bg-secondary)] border-b border-[var(--border-primary)] flex items-center justify-between">
        <div className="flex items-center gap-3">
          <button onClick={() => router.back()} className="p-2 rounded-xl hover:bg-[var(--bg-tertiary)]"><ArrowLeft className="w-5 h-5 text-[var(--text-secondary)]" /></button>
          <div><h1 className="font-bold text-[var(--text-primary)]">Activity Log</h1><p className="text-xs text-[var(--text-tertiary)]">Your recent actions</p></div>
        </div>
      </header>
      <main className="max-w-2xl mx-auto px-6 py-6">
        <div className="flex flex-wrap gap-2 mb-6">
          {FILTERS.map(f => (
            <button key={f.key} onClick={() => setFilter(f.key)}
              className={`px-4 py-2 rounded-full text-sm font-medium transition-all ${filter === f.key ? 'bg-[var(--color-primary-500)] text-white' : 'bg-[var(--bg-secondary)] border border-[var(--border-primary)] text-[var(--text-secondary)] hover:border-[var(--color-primary-500)]/40'}`}>
              {f.label}
            </button>
          ))}
        </div>
        {renderGroup('Today', today)}
        {renderGroup('Yesterday', yesterday)}
        {renderGroup('Earlier', older)}
      </main>
    </div>
  );
}
