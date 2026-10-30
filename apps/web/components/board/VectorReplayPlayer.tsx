"use client";
import React, { useState, useEffect } from "react";
import { Play, Pause, RotateCcw, FastForward, Film, X } from "lucide-react";

interface VectorReplayPlayerProps {
  isOpen: boolean;
  onClose: () => void;
  shapes: any[];
  onApplyShapeSnapshot: (shapes: any[]) => void;
}

export default function VectorReplayPlayer({
  isOpen,
  onClose,
  shapes = [],
  onApplyShapeSnapshot,
}: VectorReplayPlayerProps) {
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [speed, setSpeed] = useState<number>(1);

  const total = shapes.length;

  useEffect(() => {
    if (!isOpen) {
      setIsPlaying(false);
      return;
    }
    setCurrentIndex(shapes.length);
  }, [isOpen, shapes.length]);

  useEffect(() => {
    let timer: any;
    if (isPlaying && currentIndex < total) {
      timer = setTimeout(() => {
        const nextIdx = currentIndex + 1;
        setCurrentIndex(nextIdx);
        onApplyShapeSnapshot(shapes.slice(0, nextIdx));
        if (nextIdx >= total) {
          setIsPlaying(false);
        }
      }, 600 / speed);
    }
    return () => clearTimeout(timer);
  }, [isPlaying, currentIndex, total, speed, shapes, onApplyShapeSnapshot]);

  if (!isOpen) return null;

  const handleTogglePlay = () => {
    if (currentIndex >= total) {
      setCurrentIndex(0);
      onApplyShapeSnapshot([]);
    }
    setIsPlaying(prev => !prev);
  };

  const handleReset = () => {
    setIsPlaying(false);
    setCurrentIndex(0);
    onApplyShapeSnapshot([]);
  };

  const handleSliderChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const val = parseInt(e.target.value, 10);
    setCurrentIndex(val);
    onApplyShapeSnapshot(shapes.slice(0, val));
  };

  return (
    <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 bg-[var(--bg-secondary)] border border-[var(--border-primary)] p-4 rounded-3xl shadow-2xl flex items-center gap-4 min-w-[480px]">
      <div className="flex items-center gap-2 pr-3 border-r border-[var(--border-primary)]">
        <Film className="w-5 h-5 text-[var(--color-primary-500)]" />
        <span className="text-xs font-black text-[var(--text-primary)]">Session Replay</span>
      </div>

      {/* Controls */}
      <div className="flex items-center gap-2">
        <button
          onClick={handleReset}
          className="p-2 rounded-xl bg-[var(--bg-tertiary)] border border-[var(--border-primary)] text-[var(--text-tertiary)] hover:text-[var(--text-primary)] transition-all"
        >
          <RotateCcw size={14} />
        </button>
        <button
          onClick={handleTogglePlay}
          className="p-2.5 rounded-xl bg-[var(--color-primary-500)] text-white shadow-md hover:bg-indigo-600 transition-all flex items-center justify-center"
        >
          {isPlaying ? <Pause size={16} /> : <Play size={16} />}
        </button>
      </div>

      {/* Progress Bar & Slider */}
      <div className="flex-1 space-y-1">
        <div className="flex justify-between text-[10px] font-bold text-[var(--text-tertiary)]">
          <span>{currentIndex} / {total} Strokes</span>
          <span>{Math.round((currentIndex / (total || 1)) * 100)}%</span>
        </div>
        <input
          type="range"
          min={0}
          max={total}
          value={currentIndex}
          onChange={handleSliderChange}
          className="w-full h-1.5 rounded-lg appearance-none bg-[var(--bg-tertiary)] accent-[var(--color-primary-500)] cursor-pointer"
        />
      </div>

      {/* Speed Selector */}
      <button
        onClick={() => setSpeed(prev => (prev === 1 ? 1.5 : prev === 1.5 ? 2 : 1))}
        className="px-2.5 py-1.5 rounded-xl bg-[var(--bg-tertiary)] border border-[var(--border-primary)] text-xs font-bold text-[var(--text-primary)] flex items-center gap-1 hover:border-[var(--color-primary-500)] transition-all"
      >
        <FastForward size={12} />
        <span>{speed}x</span>
      </button>

      {/* Close button */}
      <button
        onClick={onClose}
        className="p-1.5 rounded-full text-[var(--text-tertiary)] hover:text-[var(--text-primary)] transition-all"
      >
        <X size={14} />
      </button>
    </div>
  );
}
