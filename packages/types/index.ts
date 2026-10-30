/**
 * EduBoard Shared Data Models & Core Types
 */

export type UserRole = 'student' | 'teacher' | 'admin';

export interface User {
  id: string;
  email: string;
  name: string;
  role: UserRole;
  avatar?: string;
  createdAt?: string;
}

export interface UserProfile extends User {
  bio?: string;
  schoolName?: string;
  gradeLevel?: string;
  preferredSubject?: string;
}

export interface UserSettings {
  theme: 'light' | 'dark' | 'system';
  enableGestures: boolean;
  enableVoice: boolean;
  autoSave: boolean;
  soundEffects: boolean;
  highContrast: boolean;
  gridLines: boolean;
}

export interface Board {
  id: string;
  title: string;
  description?: string;
  createdAt: string;
  updatedAt: string;
  createdBy: string;
  isShared: boolean;
  sharedWith?: string[];
  content?: string;
  thumbnail?: string;
  bgColor?: string;
  width?: number;
  height?: number;
  zoom?: number;
  isInfiniteCanvas?: boolean;
  tags?: string[];
  folder?: string;
}

export interface SharedBoard extends Board {
  permission: 'view' | 'edit' | 'admin';
  ownerEmail: string;
}

export interface BoardActivity {
  id: string;
  boardId: string;
  userId: string;
  userName: string;
  action: string;
  timestamp: string;
}
}

export interface AISolutionStep {
  step: number;
  title: string;
  detail: string;
}

export interface AIMathSolution {
  success: boolean;
  title: string;
  latexFormula: string;
  explanation: string;
  steps: AISolutionStep[];
  graphData?: Array<{ x: number; y: number }>;
  practiceQuestions?: Array<{
    question: string;
    options: string[];
    answer: number;
  }>;
}
