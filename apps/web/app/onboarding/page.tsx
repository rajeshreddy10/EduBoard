'use client';

import React from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Logo } from '@/components/branding/Logo';
import { Sparkles, ArrowRight, CheckCircle2, UserPlus, LogIn } from 'lucide-react';

export default function SimpleOnboardingPage() {
  const router = useRouter();

  return (
    <div className="min-h-screen bg-[var(--bg-primary)] text-[var(--text-primary)] flex flex-col justify-between p-6 sm:p-10">
      {/* Header */}
      <header className="max-w-xl mx-auto w-full flex justify-between items-center py-2">
        <Logo size="md" />
        <div className="flex items-center gap-2">
          <Link
            href="/login"
            className="text-xs font-bold px-3.5 py-2 rounded-xl bg-[var(--bg-secondary)] hover:bg-[var(--bg-tertiary)] border border-[var(--border-primary)] text-[var(--text-primary)] transition-all"
          >
            Sign In
          </Link>
          <Link
            href="/signup"
            className="text-xs font-bold px-3.5 py-2 rounded-xl bg-[var(--color-primary-500)] text-white hover:bg-[var(--color-primary-600)] transition-all shadow-xs"
          >
            Sign Up
          </Link>
        </div>
      </header>

      {/* Main Single Card */}
      <main className="max-w-md mx-auto my-auto w-full">
        <div className="p-8 sm:p-10 rounded-3xl bg-[var(--bg-secondary)] border border-[var(--border-primary)] shadow-xl space-y-6 text-center animate-fade-in relative overflow-hidden">
          
          {/* Badge */}
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[var(--color-primary-500)]/10 text-[var(--color-primary-500)] text-xs font-bold">
            <Sparkles size={14} />
            Smart Digital Whiteboard
          </div>

          {/* Title & Description */}
          <div className="space-y-2">
            <h1 className="text-2xl sm:text-3xl font-extrabold text-[var(--text-primary)] tracking-tight">
              Welcome to EduBoard
            </h1>
            <p className="text-xs sm:text-sm text-[var(--text-secondary)] font-medium leading-relaxed">
              An intelligent teaching workspace uniting smart whiteboards, AI voice transcription, and document annotation.
            </p>
          </div>

          {/* Highlights for screen sharing & presentations */}
          <div className="bg-[var(--bg-primary)]/50 p-4 rounded-2xl border border-[var(--border-primary)]/50 text-left space-y-3">
            <div className="flex items-center gap-2.5 text-xs font-semibold text-[var(--text-primary)]">
              <CheckCircle2 size={16} className="text-purple-500 shrink-0" />
              <span>Laser Pointer & Spotlight for Online Presentations</span>
            </div>
            <div className="flex items-center gap-2.5 text-xs font-semibold text-[var(--text-primary)]">
              <CheckCircle2 size={16} className="text-amber-500 shrink-0" />
              <span>Live Voice AI & Speech-to-Notes while Lecturing</span>
            </div>
            <div className="flex items-center gap-2.5 text-xs font-semibold text-[var(--text-primary)]">
              <CheckCircle2 size={16} className="text-blue-500 shrink-0" />
              <span>Markup PDFs, Slides & Documents live on screen</span>
            </div>
          </div>

          {/* Action Buttons at Bottom */}
          <div className="grid grid-cols-2 gap-3 pt-2">
            <button
              onClick={() => router.push('/login')}
              className="py-3 px-4 rounded-2xl bg-[var(--color-primary-500)] text-white text-xs font-extrabold hover:bg-[var(--color-primary-600)] transition-all shadow-md cursor-pointer flex items-center justify-center gap-2"
            >
              <LogIn size={15} /> Sign In
            </button>
            <button
              onClick={() => router.push('/signup')}
              className="py-3 px-4 rounded-2xl bg-[var(--bg-primary)] text-[var(--text-primary)] border border-[var(--border-primary)] hover:bg-[var(--bg-tertiary)] text-xs font-extrabold transition-all cursor-pointer flex items-center justify-center gap-2"
            >
              <UserPlus size={15} /> Sign Up
            </button>
          </div>

          <div className="pt-2 flex items-center justify-center text-xs text-[var(--text-tertiary)]">
            <Link
              href="/normal-board?mode=presentation"
              className="text-[var(--color-primary-500)] hover:underline font-semibold flex items-center gap-1.5"
            >
              <span>⚡ Start Screen Share Board (No Sign-In Required)</span>
              <ArrowRight size={13} />
            </Link>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="max-w-xl mx-auto w-full text-center py-2 text-[11px] text-[var(--text-tertiary)] font-medium">
        EduBoard v3.1 — Simple & Intelligent Workspace
      </footer>
    </div>
  );
}
