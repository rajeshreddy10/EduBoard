"use client";
import React, { useState } from "react";
import { X, Sparkles, Calculator, CheckCircle2, XCircle, ChevronRight, HelpCircle } from "lucide-react";
import { api } from "@/lib/api";
import 'katex/dist/katex.min.css';
import { InlineMath, BlockMath } from "react-katex";

interface Step {
  step: number;
  title: string;
  detail: string;
}

interface Question {
  question: string;
  options: string[];
  answer: number;
}

interface GraphPoint {
  x: number;
  y: number;
}

interface AIMathSolverModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function AIMathSolverModal({ isOpen, onClose }: AIMathSolverModalProps) {
  const [problemInput, setProblemInput] = useState("d/dx (x^3 + 4x - 5)");
  const [loading, setLoading] = useState(false);
  const [solution, setSolution] = useState<any>(null);
  const [selectedAnswers, setSelectedAnswers] = useState<{ [key: number]: number }>({});

  if (!isOpen) return null;

  const handleSolve = async () => {
    if (!problemInput.trim()) return;
    setLoading(true);
    try {
      const res = await api.solveMath(problemInput);
      setSolution(res);
      setSelectedAnswers({});
    } catch (err) {
      console.error("AI Solve error:", err);
    } finally {
      setLoading(false);
    }
  };

  const handleSelectOption = (qIdx: number, optIdx: number) => {
    setSelectedAnswers(prev => ({ ...prev, [qIdx]: optIdx }));
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
      <div className="w-full max-w-3xl bg-[var(--bg-secondary)] border border-[var(--border-primary)] rounded-3xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="px-6 py-4 border-b border-[var(--border-primary)] flex items-center justify-between bg-[var(--bg-tertiary)]">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-gradient-to-tr from-indigo-500 to-purple-600 flex items-center justify-center text-white shadow-lg">
              <Sparkles className="w-5 h-5 animate-pulse" />
            </div>
            <div>
              <h2 className="text-base font-black text-[var(--text-primary)]">AI Visual Math & Diagram Solver</h2>
              <p className="text-xs text-[var(--text-tertiary)] font-medium">Step-by-step LaTeX derivation, 2D graph plots & practice cards</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full bg-[var(--bg-secondary)] border border-[var(--border-primary)] flex items-center justify-center text-[var(--text-tertiary)] hover:text-[var(--text-primary)] transition-all"
          >
            <X size={16} />
          </button>
        </div>

        {/* Input Bar */}
        <div className="p-6 border-b border-[var(--border-primary)] bg-[var(--bg-primary)]">
          <div className="flex gap-3">
            <div className="relative flex-1">
              <Calculator className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-[var(--text-tertiary)]" />
              <input
                type="text"
                value={problemInput}
                onChange={(e) => setProblemInput(e.target.value)}
                placeholder="Enter math expression (e.g. d/dx (x^3 + 4x), ∫ sin(x) dx, x^2 - 4 = 0)"
                className="w-full pl-12 pr-4 py-3 rounded-2xl bg-[var(--bg-secondary)] border border-[var(--border-primary)] text-sm font-semibold text-[var(--text-primary)] focus:outline-none focus:border-[var(--color-primary-500)]"
              />
            </div>
            <button
              onClick={handleSolve}
              disabled={loading}
              className="px-6 py-3 rounded-2xl bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 text-white font-bold text-sm shadow-md transition-all flex items-center gap-2 disabled:opacity-50"
            >
              {loading ? <Sparkles className="w-4 h-4 animate-spin" /> : <Sparkles className="w-4 h-4" />}
              <span>{loading ? "Deriving..." : "Solve AI"}</span>
            </button>
          </div>
        </div>

        {/* Results Scroll Area */}
        <div className="p-6 overflow-y-auto space-y-6 flex-1">
          {!solution && !loading && (
            <div className="text-center py-12 space-y-3">
              <HelpCircle className="w-12 h-12 text-[var(--text-tertiary)] mx-auto opacity-40" />
              <p className="text-sm font-bold text-[var(--text-primary)]">Ready to solve any math or diagram problem</p>
              <p className="text-xs text-[var(--text-tertiary)] max-w-md mx-auto">
                Type an equation or calculus problem above and click <strong>Solve AI</strong> to generate step-by-step LaTeX derivations and graph curves.
              </p>
            </div>
          )}

          {solution && (
            <>
              {/* LaTeX Derived Formula Header */}
              <div className="p-5 rounded-2xl bg-indigo-500/10 border border-indigo-500/20 text-center space-y-2">
                <div className="text-xs font-bold uppercase tracking-wider text-indigo-400">Formula & Derivative</div>
                <div className="text-lg font-black text-indigo-300">
                  <BlockMath math={solution.latexFormula || "y = f(x)"} />
                </div>
                <p className="text-xs text-[var(--text-tertiary)] font-medium">{solution.explanation}</p>
              </div>

              {/* Step-by-Step Derivation */}
              {solution.steps && solution.steps.length > 0 && (
                <div className="space-y-3">
                  <h3 className="text-xs font-black uppercase text-[var(--text-tertiary)] tracking-wider">Step-by-Step Solution</h3>
                  <div className="space-y-2">
                    {solution.steps.map((st: Step) => (
                      <div key={st.step} className="p-4 rounded-xl bg-[var(--bg-tertiary)] border border-[var(--border-primary)] flex items-start gap-3">
                        <div className="w-6 h-6 rounded-full bg-[var(--color-primary-500)] text-white text-xs font-bold flex items-center justify-center shrink-0 mt-0.5">
                          {st.step}
                        </div>
                        <div>
                          <div className="text-xs font-bold text-[var(--text-primary)]">{st.title}</div>
                          <div className="text-xs text-[var(--text-tertiary)] mt-0.5 font-medium">{st.detail}</div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* 2D Interactive SVG Graph Plot */}
              {solution.graphData && solution.graphData.length > 0 && (
                <div className="space-y-3">
                  <h3 className="text-xs font-black uppercase text-[var(--text-tertiary)] tracking-wider">2D Graph Plot Visualization</h3>
                  <div className="p-4 rounded-2xl bg-[var(--bg-tertiary)] border border-[var(--border-primary)] flex flex-col items-center">
                    <svg width="400" height="180" viewBox="-100 -60 200 120" className="w-full max-w-md h-44 overflow-visible">
                      <line x1="-90" y1="0" x2="90" y2="0" stroke="currentColor" strokeWidth="1" className="text-[var(--border-primary)]" />
                      <line x1="0" y1="-50" x2="0" y2="50" stroke="currentColor" strokeWidth="1" className="text-[var(--border-primary)]" />
                      <path
                        d={solution.graphData.map((pt: GraphPoint, i: number) => `${i === 0 ? 'M' : 'L'} ${pt.x * 15} ${-pt.y * 1.5}`).join(" ")}
                        fill="none"
                        stroke="#6366f1"
                        strokeWidth="3"
                      />
                    </svg>
                  </div>
                </div>
              )}

              {/* Practice Questions */}
              {solution.practiceQuestions && solution.practiceQuestions.length > 0 && (
                <div className="space-y-3">
                  <h3 className="text-xs font-black uppercase text-[var(--text-tertiary)] tracking-wider">Self-Test Practice Cards</h3>
                  <div className="space-y-3">
                    {solution.practiceQuestions.map((q: Question, qIdx: number) => {
                      const selected = selectedAnswers[qIdx];
                      return (
                        <div key={qIdx} className="p-4 rounded-2xl bg-[var(--bg-tertiary)] border border-[var(--border-primary)] space-y-3">
                          <p className="text-xs font-bold text-[var(--text-primary)] flex items-center gap-2">
                            <ChevronRight className="w-4 h-4 text-indigo-400" />
                            <span>{q.question}</span>
                          </p>
                          <div className="grid grid-cols-2 gap-2">
                            {q.options.map((opt: string, optIdx: number) => {
                              const isPicked = selected === optIdx;
                              const isCorrect = optIdx === q.answer;
                              let btnStyle = "bg-[var(--bg-secondary)] border-[var(--border-primary)] text-[var(--text-primary)]";
                              if (selected !== undefined) {
                                if (isCorrect) btnStyle = "bg-emerald-500/10 border-emerald-500/40 text-emerald-400";
                                else if (isPicked) btnStyle = "bg-rose-500/10 border-rose-500/40 text-rose-400";
                              }
                              return (
                                <button
                                  key={optIdx}
                                  onClick={() => handleSelectOption(qIdx, optIdx)}
                                  className={`p-2.5 rounded-xl border text-xs font-semibold flex items-center justify-between transition-all ${btnStyle}`}
                                >
                                  <span>{opt}</span>
                                  {selected !== undefined && isCorrect && <CheckCircle2 className="w-4 h-4 text-emerald-400" />}
                                  {selected !== undefined && isPicked && !isCorrect && <XCircle className="w-4 h-4 text-rose-400" />}
                                </button>
                              );
                            })}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}
