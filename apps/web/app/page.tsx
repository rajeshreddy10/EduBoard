'use client';

import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Logo } from '@/components/branding/Logo';
import { useAuth } from '@/lib/AuthContext';
import { useTheme } from '@/lib/ThemeContext';
import { Sun, Moon, ArrowRight } from 'lucide-react';

export default function SplashScreen() {
  const router = useRouter();
  const { user, loading: authLoading } = useAuth();
  const { theme, toggleTheme, isDark } = useTheme();
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    const timer = setInterval(() => {
      setProgress((prev) => {
        if (prev >= 100) {
          clearInterval(timer);
          return 100;
        }
        return prev + 5;
      });
    }, 40);

    return () => clearInterval(timer);
  }, []);

  const proceed = () => {
    if (user) {
      router.replace('/dashboard');
    } else {
      router.replace('/login');
    }
  };

  useEffect(() => {
    if (progress === 100 && !authLoading) {
      const timeout = setTimeout(() => {
        proceed();
      }, 350);

      return () => clearTimeout(timeout);
    }
  }, [progress, authLoading, user, router]);

  return (
    <div className="min-h-screen bg-[var(--bg-primary)] text-[var(--text-primary)] flex flex-col justify-between items-center p-6 select-none">
      {/* Top Header with Theme Switcher */}
      <header className="w-full max-w-md flex justify-end items-center">
        <button
          onClick={toggleTheme}
          aria-label="Toggle theme"
          className="p-2 rounded-xl bg-[var(--bg-secondary)] hover:bg-[var(--bg-hover)] border border-[var(--border-primary)] text-[var(--text-secondary)] hover:text-[var(--text-primary)] transition-all cursor-pointer"
          title={`Switch theme (current: ${theme})`}
        >
          {isDark ? <Sun size={15} className="text-amber-400" /> : <Moon size={15} className="text-slate-600" />}
        </button>
      </header>

      {/* Main Center */}
      <div className="w-full max-w-sm flex flex-col items-center text-center space-y-6 my-auto">
        <div className="p-3.5 rounded-2xl bg-[var(--bg-secondary)] border border-[var(--border-primary)] shadow-sm">
          <Logo size="lg" showText={false} />
        </div>

        <div className="space-y-1.5">
          <h1 className="text-2xl font-bold tracking-tight text-[var(--text-primary)]">
            EduBoard
          </h1>
          <p className="text-xs text-[var(--text-secondary)]">
            {progress < 100 ? 'Initializing presentation & whiteboard studio...' : 'Ready for screen sharing!'}
          </p>
        </div>

        <div className="w-56 space-y-2 pt-1">
          <div className="h-1.5 w-full bg-[var(--bg-tertiary)] rounded-full overflow-hidden border border-[var(--border-primary)]">
            <div
              className="h-full bg-[var(--color-primary-500)] rounded-full transition-all duration-150 ease-out"
              style={{ width: `${progress}%` }}
            />
          </div>
          <div className="flex justify-between items-center text-[11px] text-[var(--text-tertiary)] font-mono">
            <span>{progress < 100 ? 'Loading' : 'Ready'}</span>
            <span>{progress}%</span>
          </div>
        </div>

        {/* Quick Skip Button */}
        <button
          onClick={proceed}
          className="inline-flex items-center gap-1.5 text-xs font-medium text-[var(--text-tertiary)] hover:text-[var(--color-primary-500)] transition-colors cursor-pointer pt-2"
        >
          <span>Enter now</span>
          <ArrowRight size={13} />
        </button>
      </div>

      {/* Footer */}
      <footer className="text-[11px] text-[var(--text-tertiary)]">
        EduBoard &bull; Smart Whiteboard for Online Presentations &amp; Screen Sharing
      </footer>
    </div>
  );
}
