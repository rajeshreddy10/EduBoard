'use client';

import React, { useState, useEffect, useRef, useCallback } from 'react';
import { Mic, MicOff, X, Globe, AlertCircle, Volume2 } from 'lucide-react';

interface LiveSubtitlesButtonProps {
  enabled: boolean;
  onToggle: () => void;
  className?: string;
}

/**
 * YouTube-style CC Button (with signature red underline when active)
 */
export function LiveSubtitlesButton({
  enabled,
  onToggle,
  className = '',
}: LiveSubtitlesButtonProps) {
  // Support 'c' keyboard shortcut like YouTube
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement;
      if (
        target &&
        (target.tagName === 'INPUT' ||
          target.tagName === 'TEXTAREA' ||
          target.isContentEditable)
      ) {
        return;
      }

      if (e.key === 'c' || e.key === 'C') {
        if (!e.ctrlKey && !e.metaKey && !e.altKey) {
          e.preventDefault();
          onToggle();
        }
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [onToggle]);

  return (
    <button
      type="button"
      id="btn-subtitles-toggle"
      onClick={onToggle}
      aria-label={enabled ? 'Turn off subtitles (c)' : 'Turn on subtitles (c)'}
      title={
        enabled
          ? 'Subtitles are ON (Press C to turn off)'
          : 'Subtitles are OFF (Press C to turn on)'
      }
      className={`relative inline-flex items-center gap-1.5 px-2.5 sm:px-3 py-2 rounded-xl text-xs font-medium transition-all cursor-pointer select-none shrink-0 ${
        enabled
          ? 'bg-neutral-900 text-white border border-neutral-700 shadow-sm ring-1 ring-red-500/50'
          : 'bg-[var(--bg-tertiary)] border border-[var(--border-primary)] text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-[var(--bg-hover)]'
      } ${className}`}
    >
      {/* YouTube Style CC Box Badge */}
      <span
        className={`px-1.5 py-0.5 rounded text-[10px] font-black tracking-wider uppercase border leading-none transition-colors ${
          enabled
            ? 'border-white bg-white/20 text-white'
            : 'border-[var(--text-tertiary)] text-[var(--text-secondary)]'
        }`}
      >
        CC
      </span>

      <span className="hidden md:inline font-semibold text-xs">
        Subtitles
      </span>

      {/* YouTube signature red active bottom bar */}
      {enabled && (
        <span
          className="absolute -bottom-0.5 left-2 right-2 h-[3px] bg-red-600 rounded-full animate-pulse shadow-[0_0_8px_rgba(239,68,68,0.8)]"
          aria-hidden="true"
        />
      )}
    </button>
  );
}

interface LiveSubtitlesOverlayProps {
  enabled: boolean;
  onClose: () => void;
}

const SUPPORTED_LANGUAGES = [
  { code: 'en-US', label: 'English (US)' },
  { code: 'en-IN', label: 'English (India)' },
  { code: 'en-GB', label: 'English (UK)' },
];

/**
 * YouTube-style Transparent Live Subtitles Overlay
 * Real-time Speech-to-Text displaying actual user speech
 */
export function LiveSubtitlesOverlay({
  enabled,
  onClose,
}: LiveSubtitlesOverlayProps) {
  const [finalText, setFinalText] = useState<string>('');
  const [interimText, setInterimText] = useState<string>('');
  const [isListening, setIsListening] = useState<boolean>(false);
  const [micError, setMicError] = useState<string | null>(null);
  const [fontSize, setFontSize] = useState<'normal' | 'large'>('normal');
  const [transparencyMode, setTransparencyMode] = useState<'translucent' | 'clear'>('translucent');
  const [selectedLang, setSelectedLang] = useState<string>(() => {
    if (typeof navigator !== 'undefined' && navigator.language) {
      if (navigator.language.startsWith('en-IN')) return 'en-IN';
      if (navigator.language.startsWith('en-GB')) return 'en-GB';
    }
    return 'en-US';
  });

  const recognitionRef = useRef<any>(null);
  const enabledRef = useRef<boolean>(enabled);
  const selectedLangRef = useRef<string>(selectedLang);
  const restartTimerRef = useRef<any>(null);

  enabledRef.current = enabled;
  selectedLangRef.current = selectedLang;

  const startRecognition = useCallback(async () => {
    if (!enabledRef.current) return;

    // Check browser speech recognition support
    const SpeechRecognition =
      (window as any).SpeechRecognition ||
      (window as any).webkitSpeechRecognition;

    if (!SpeechRecognition) {
      setMicError('Speech recognition is not supported in this browser. Please use Google Chrome, Edge, or Safari.');
      return;
    }

    // Explicitly prompt for mic permission via getUserMedia first if available
    try {
      if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        // Close temporary stream immediately so recognition engine takes exclusive handle
        stream.getTracks().forEach(track => track.stop());
      }
    } catch (err: any) {
      console.warn('[EduBoard Live Subtitles] Mic permission check:', err);
      if (err.name === 'NotAllowedError' || err.name === 'PermissionDeniedError') {
        setMicError('Microphone permission denied. Please allow microphone access in your browser address bar.');
        setIsListening(false);
        return;
      }
    }

    // Stop existing instance before starting fresh
    if (recognitionRef.current) {
      try {
        recognitionRef.current.abort();
      } catch {}
      recognitionRef.current = null;
    }

    try {
      const recognition = new SpeechRecognition();
      recognition.continuous = true;
      recognition.interimResults = true;
      recognition.lang = selectedLangRef.current;
      recognition.maxAlternatives = 1;

      recognition.onstart = () => {
        setIsListening(true);
        setMicError(null);
      };

      recognition.onresult = (event: any) => {
        let currentFinal = '';
        let currentInterim = '';

        for (let i = 0; i < event.results.length; i++) {
          const result = event.results[i];
          const transcript = result[0]?.transcript || '';
          if (result.isFinal) {
            currentFinal += (currentFinal ? ' ' : '') + transcript.trim();
          } else {
            currentInterim += (currentInterim ? ' ' : '') + transcript.trim();
          }
        }

        // Keep a clean rolling window of recent words for the subtitles
        if (currentFinal) {
          const words = currentFinal.split(' ');
          const chunk = words.length > 20 ? words.slice(-20).join(' ') : currentFinal;
          setFinalText(chunk);
        }
        setInterimText(currentInterim);
      };

      recognition.onerror = (event: any) => {
        console.warn('[EduBoard Live Subtitles] recognition error:', event.error);
        if (event.error === 'not-allowed') {
          setMicError('Microphone blocked. Click the lock/tune icon in your browser URL bar to allow microphone.');
          setIsListening(false);
        } else if (event.error === 'no-speech') {
          // Normal when user is silent; no need to show error
        } else if (event.error !== 'aborted') {
          // Ignore aborted
        }
      };

      recognition.onend = () => {
        setIsListening(false);
        // Automatically restart speech recognition while subtitles remain enabled
        if (enabledRef.current) {
          if (restartTimerRef.current) clearTimeout(restartTimerRef.current);
          restartTimerRef.current = setTimeout(() => {
            if (enabledRef.current) {
              try {
                recognition.start();
              } catch (e) {
                // If start fails, re-initialize
                startRecognition();
              }
            }
          }, 250);
        }
      };

      recognition.start();
      recognitionRef.current = recognition;
    } catch (err: any) {
      console.error('[EduBoard Live Subtitles] start error:', err);
      setMicError('Unable to start speech recognition. Please check your microphone.');
    }
  }, []);

  useEffect(() => {
    if (enabled) {
      setFinalText('');
      setInterimText('');
      setMicError(null);
      startRecognition();
    } else {
      if (restartTimerRef.current) clearTimeout(restartTimerRef.current);
      if (recognitionRef.current) {
        try {
          recognitionRef.current.abort();
        } catch {}
        recognitionRef.current = null;
      }
      setIsListening(false);
      setFinalText('');
      setInterimText('');
    }

    return () => {
      if (restartTimerRef.current) clearTimeout(restartTimerRef.current);
      if (recognitionRef.current) {
        try {
          recognitionRef.current.abort();
        } catch {}
        recognitionRef.current = null;
      }
    };
  }, [enabled, startRecognition]);

  // Restart recognition if language changes
  const handleLanguageChange = (langCode: string) => {
    setSelectedLang(langCode);
    selectedLangRef.current = langCode;
    if (enabled) {
      startRecognition();
    }
  };

  if (!enabled) return null;

  const hasSpeech = Boolean(finalText || interimText);

  return (
    <div
      id="live-subtitles-overlay"
      className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 pointer-events-none w-[94%] max-w-2xl flex flex-col items-center animate-fade-in select-none"
      role="region"
      aria-label="Live Subtitles"
    >
      {/* Floating Transparent Subtitle Container */}
      <div className="pointer-events-auto flex flex-col items-center group max-w-full">
        
        {/* Subtle Top Indicator & Controls Strip */}
        <div className="flex items-center gap-2 mb-1.5 px-3 py-1 rounded-full bg-black/50 backdrop-blur-md text-[10px] text-white/80 border border-white/15 shadow-sm transition-all">
          <span className="flex items-center gap-1.5 font-bold tracking-wider text-red-500">
            <span
              className={`w-2 h-2 rounded-full ${
                isListening ? 'bg-red-500 animate-ping' : 'bg-red-400'
              } inline-block`}
            />
            LIVE CC
          </span>

          <span>&bull;</span>

          {/* Language Selector */}
          <select
            value={selectedLang}
            onChange={e => handleLanguageChange(e.target.value)}
            className="bg-transparent text-white/90 hover:text-white border-0 text-[10px] cursor-pointer focus:outline-none focus:ring-0 p-0 font-medium"
            title="Subtitle Recognition Language"
          >
            {SUPPORTED_LANGUAGES.map(lang => (
              <option key={lang.code} value={lang.code} className="bg-neutral-900 text-white">
                {lang.label}
              </option>
            ))}
          </select>

          <span className="text-white/30">|</span>

          {/* Toggle Transparency Mode (Translucent / Clear) */}
          <button
            type="button"
            onClick={() =>
              setTransparencyMode(m => (m === 'translucent' ? 'clear' : 'translucent'))
            }
            className="px-1.5 py-0.5 rounded hover:bg-white/15 text-white/80 hover:text-white transition-colors cursor-pointer text-[10px]"
            title={`Current: ${transparencyMode === 'translucent' ? 'Translucent (50%)' : 'Clear (Glass)'}. Click to switch.`}
          >
            {transparencyMode === 'translucent' ? 'Translucent' : 'Clear'}
          </button>

          {/* Font Size Toggle */}
          <button
            type="button"
            onClick={() =>
              setFontSize(f => (f === 'normal' ? 'large' : 'normal'))
            }
            className="px-1.5 py-0.5 rounded hover:bg-white/15 text-white/80 hover:text-white transition-colors cursor-pointer text-[10px] font-bold"
            title="Toggle caption text size"
          >
            {fontSize === 'normal' ? 'A+' : 'A-'}
          </button>

          {/* Close Subtitles */}
          <button
            type="button"
            onClick={onClose}
            className="p-0.5 rounded hover:bg-white/20 text-white/70 hover:text-white transition-colors cursor-pointer ml-1"
            title="Close subtitles (c)"
            aria-label="Close subtitles"
          >
            <X size={12} />
          </button>
        </div>

        {/* Microphone Error State */}
        {micError && (
          <div
            onClick={startRecognition}
            className="cursor-pointer mb-2 px-3 py-1.5 rounded-lg bg-amber-900/80 backdrop-blur-md border border-amber-500/40 text-amber-100 text-xs flex items-center gap-2 shadow-lg"
            title="Click to retry microphone permission"
          >
            <AlertCircle size={14} className="text-amber-400 shrink-0" />
            <span>{micError}</span>
            <span className="underline font-bold text-[11px] ml-1">Retry</span>
          </div>
        )}

        {/* YouTube-Style Transparent / Visible Caption Text Display */}
        <div
          className={`text-center font-sans font-semibold tracking-wide transition-all leading-relaxed px-2 ${
            fontSize === 'large'
              ? 'text-lg sm:text-xl'
              : 'text-sm sm:text-base'
          }`}
        >
          <span
            className={`inline-block rounded-lg px-3.5 py-1.5 transition-all ${
              transparencyMode === 'translucent'
                ? 'bg-black/50 backdrop-blur-[3px] border border-white/15 text-white'
                : 'bg-black/20 backdrop-blur-[1px] border border-white/10 text-white'
            }`}
            style={{
              textShadow:
                '0 0 3px #000, 0 1px 2px #000, 0 2px 4px rgba(0,0,0,0.95), -1px -1px 0 #000, 1px -1px 0 #000, -1px 1px 0 #000, 1px 1px 0 #000',
              WebkitFontSmoothing: 'antialiased',
            }}
          >
            {hasSpeech ? (
              <>
                <span>{finalText}</span>
                {interimText && (
                  <span className="text-white/80 italic ml-1.5 font-normal">
                    {interimText}
                  </span>
                )}
              </>
            ) : (
              <span className="text-white/70 font-normal italic flex items-center gap-1.5">
                <Mic size={14} className="text-red-400 animate-pulse" />
                <span>Listening... speak into your microphone</span>
              </span>
            )}
          </span>
        </div>
      </div>
    </div>
  );
}
