export type UserRole = 'student' | 'teacher' | 'school_admin' | 'super_admin';
export type ThemeMode = 'light' | 'dark' | 'system';
export type Platform = 'windows' | 'web';

export interface User {
  id: string;
  email: string;
  name: string;
  username?: string;
  role: UserRole;
  avatar?: string;
  bio?: string;
  phone?: string;
  address?: string;
  organization?: string;
  institution?: string;
  grade?: string;
  subject?: string;
  location?: string;
  website?: string;
  dob?: string;
  gender?: string;
  teachingPhilosophy?: string;
  socialLinks?: {
    twitter?: string;
    linkedin?: string;
    github?: string;
  };
  languages?: string[];
  certifications?: string[];
  interests?: string[];
  isVerified: boolean;
  isBiometricEnabled: boolean;
  createdAt: string;
  lastLoginAt: string;
}

export interface AuthResponse {
  user: User;
  token: string;
  refreshToken: string;
  expiresIn: number;
  firebaseCustomToken?: string;
}

export interface LoginRequest {
  email: string;
  password: string;
  rememberMe?: boolean;
}

export interface SignupRequest {
  email: string;
  password: string;
  confirmPassword?: string;
  name: string;
  role: UserRole;
  institution?: string;
  uid?: string;
  firebaseUid?: string;
}

export interface OTPVerification {
  email: string;
  otp: string;
}

export type BoardStudioKind = 'drawspace' | 'voiceboard' | 'doccanvas';

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
  width: number;
  height: number;
  zoom: number;
  isInfiniteCanvas: boolean;
  tags?: string[];
  folder?: string;
  strokes?: any[];
  elements?: any[];
  bgFile?: { url: string; type: string };
  activeDocument?: any;
  /** Studio this board belongs to (routing + restore). Written on every save. */
  studio?: BoardStudioKind;
  /** Teaching notes attached by the teacher in DrawSpace. */
  teacherNotes?: any[];
  /** Alias kept for backend/mobile compatibility (owner. Mirrors createdBy.) */
  owner_id?: string;
}

export type HistoryRecord = Board;
export type HistoryItem = Board;

export interface DrawingStroke {
  points: { x: number; y: number; pressure?: number }[];
  color: string;
  width: number;
  opacity: number;
  tool: 'pen' | 'brush' | 'eraser' | 'area-eraser' | 'highlighter' | 'shape' | 'text' | 'marker' | 'select' | 'sticky' | 'laser' | 'image';
  shape?: 'circle' | 'rectangle' | 'triangle' | 'line' | 'arrow' | 'diamond' | 'star';
  timestamp: number;
  text?: string;
  font?: string;
  fontSize?: number;
  x?: number;
  y?: number;
  rotation?: number;
  isAiGenerated?: boolean;
  fillColor?: string;
  imageData?: string;
  imgWidth?: number;
  imgHeight?: number;
}

export interface VoiceCommand {
  id: string;
  command: string;
  action: string;
  language: string;
  isActive: boolean;
  feedback?: string;
}

export interface UserSettings {
  theme: ThemeMode;
  language: string;
  country?: string;
  timeZone?: string;
  voiceAssistance?: boolean;
  serverSTT?: boolean;
  autoCorrect?: boolean;
  spellCheck?: boolean;
  textSize: 'small' | 'medium' | 'large';
  soundEnabled?: boolean;
  hapticFeedback?: boolean;
  autoSave?: boolean;
  autoSync?: boolean;
  notificationsEnabled: boolean;
  emailNotifications: boolean;
  smartSuggestions?: boolean;
  reducedMotion: boolean;
  highContrast: boolean;
  fontSize?: number;
  boardWidth?: number;
  boardHeight?: number;
  defaultTool?: string;
  defaultColor?: string;
  defaultStrokeWidth?: number;
  [key: string]: any;
}

export interface UsageStats {
  totalBoards: number;
  totalWriteTime: number;
  averageAccuracy?: number;
  mostUsedTool?: string;
  totalCollaborations: number;
  storageUsed: number;
  lastUsed: string;
}

export interface UserProfile {
  id: string;
  email: string;
  name: string;
  username?: string;
  bio?: string;
  avatar?: string;
  phone?: string;
  role: UserRole;
  institution?: string;
  grade?: string;
  subject?: string;
  location?: string;
  website?: string;
  dob?: string;
  gender?: string;
  teachingPhilosophy?: string;
  socialLinks?: {
    twitter?: string;
    linkedin?: string;
    github?: string;
  };
  languages?: string[];
  certifications?: string[];
  interests?: string[];
  joinDate: string;
  settings: UserSettings;
  stats?: UsageStats;
  isVerified: boolean;
  createdAt: string;
}

export interface CollaborationSession {
  id: string;
  boardId: string;
  hostId: string;
  hostName: string;
  participants: CollaborationParticipant[];
  startedAt: string;
  isActive: boolean;
  tool: string;
  cursors: Record<string, { x: number; y: number }>;
}

export interface CollaborationParticipant {
  userId: string;
  name: string;
  avatar?: string;
  color: string;
  joinedAt: string;
  isOnline: boolean;
  cursor?: { x: number; y: number };
}

export interface SharedBoard {
  id: string;
  boardId: string;
  sharedWith: string[];
  permission: 'view' | 'edit' | 'admin';
}

export interface AnalyticsData {
  date: string;
  value: number;
  label?: string;
  metadata?: Record<string, any>;
}

export interface Notification {
  id: string;
  type: 'info' | 'success' | 'warning' | 'error' | 'alert';
  title: string;
  message: string;
  timestamp: string;
  read: boolean;
  actionable: boolean;
  actionUrl?: string;
  icon?: string;
  senderId?: string;
  senderName?: string;
}

export interface ActivityEntry {
  id: string;
  userId: string;
  type: 'board_created' | 'board_edited' | 'board_shared' | 'board_deleted' | 'export' | 'collaboration' | 'achievement' | 'login' | 'settings_change';
  description: string;
  timestamp: string;
  metadata?: Record<string, any>;
  icon?: string;
}

export interface BoardActivity {
  id: string;
  userId: string;
  action: string;
  timestamp: string;
}

export interface ErrorResponse {
  message: string;
  code?: string;
  details?: any;
  timestamp?: string;
}
