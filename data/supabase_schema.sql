-- ============================================================================
-- EduBoard Supabase PostgreSQL Schema & Security RLS Migration
-- ============================================================================

-- 1. Enable Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Create Public Users Table (Linked to Supabase Auth auth.users)
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  full_name TEXT,
  role TEXT DEFAULT 'teacher',
  username TEXT,
  avatar TEXT,
  institution TEXT,
  bio TEXT,
  phone TEXT,
  location TEXT,
  is_verified BOOLEAN DEFAULT TRUE,
  is_biometric_enabled BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_login_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for User Email Lookups
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);

-- 3. Boards / History Table
CREATE TABLE IF NOT EXISTS public.boards (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  owner_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  created_by UUID REFERENCES public.users(id),
  last_edited_by UUID REFERENCES public.users(id),
  title TEXT NOT NULL DEFAULT 'Untitled Board',
  description TEXT DEFAULT '',
  background_color TEXT DEFAULT '#ffffff',
  background_image TEXT DEFAULT '',
  width INTEGER DEFAULT 1920,
  height INTEGER DEFAULT 1080,
  is_public BOOLEAN DEFAULT FALSE,
  allow_comments BOOLEAN DEFAULT TRUE,
  allow_export BOOLEAN DEFAULT TRUE,
  share_link TEXT DEFAULT '',
  access_code TEXT DEFAULT '',
  shapes JSONB DEFAULT '[]'::jsonb,
  viewport JSONB DEFAULT '{}'::jsonb,
  total_shapes INTEGER DEFAULT 0,
  total_versions INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  last_edited_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_boards_user_id ON public.boards(user_id);
CREATE INDEX IF NOT EXISTS idx_boards_owner_id ON public.boards(owner_id);
CREATE INDEX IF NOT EXISTS idx_boards_created_by ON public.boards(created_by);
CREATE INDEX IF NOT EXISTS idx_boards_is_public ON public.boards(is_public);

-- 4. Board Versions Table
CREATE TABLE IF NOT EXISTS public.board_versions (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  board_id TEXT REFERENCES public.boards(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  created_by UUID REFERENCES public.users(id),
  version_number INTEGER DEFAULT 1,
  snapshot JSONB DEFAULT '[]'::jsonb,
  description TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_board_versions_board_id ON public.board_versions(board_id);

-- 5. Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  type TEXT DEFAULT 'info',
  title TEXT NOT NULL,
  message TEXT DEFAULT '',
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  read BOOLEAN DEFAULT FALSE,
  actionable BOOLEAN DEFAULT FALSE,
  action_url TEXT DEFAULT ''
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);

-- 6. User Settings & Preferences Table
CREATE TABLE IF NOT EXISTS public.user_settings (
  user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  preferences JSONB DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Whiteboard Shapes Table
CREATE TABLE IF NOT EXISTS public.shapes (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  whiteboard_id TEXT REFERENCES public.boards(id) ON DELETE CASCADE,
  created_by UUID REFERENCES public.users(id),
  type TEXT NOT NULL,
  data JSONB DEFAULT '{}'::jsonb,
  style JSONB DEFAULT '{}'::jsonb,
  z_index INTEGER DEFAULT 0,
  opacity NUMERIC DEFAULT 1.0,
  rotation NUMERIC DEFAULT 0,
  is_locked BOOLEAN DEFAULT FALSE,
  is_hidden BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_shapes_whiteboard_id ON public.shapes(whiteboard_id);

-- 8. Whiteboard Collaborators Table
CREATE TABLE IF NOT EXISTS public.whiteboard_collaborators (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  whiteboard_id TEXT REFERENCES public.boards(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'editor',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(whiteboard_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_collaborators_whiteboard_user ON public.whiteboard_collaborators(whiteboard_id, user_id);

-- ============================================================================
-- Row Level Security (RLS) Policies
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.boards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.board_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shapes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whiteboard_collaborators ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- Users RLS
-- ----------------------------------------------------------------------------
CREATE POLICY "Users can view their own profile"
  ON public.users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON public.users FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
  ON public.users FOR INSERT
  WITH CHECK (auth.uid() = id);

-- ----------------------------------------------------------------------------
-- Boards RLS
-- ----------------------------------------------------------------------------
CREATE POLICY "Users can view owned or shared or public boards"
  ON public.boards FOR SELECT
  USING (
    auth.uid() = user_id OR
    auth.uid() = owner_id OR
    auth.uid() = created_by OR
    is_public = TRUE OR
    EXISTS (
      SELECT 1 FROM public.whiteboard_collaborators wc
      WHERE wc.whiteboard_id = boards.id AND wc.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert their own boards"
  ON public.boards FOR INSERT
  WITH CHECK (
    auth.uid() = user_id OR
    auth.uid() = owner_id OR
    auth.uid() = created_by
  );

CREATE POLICY "Users can update their owned or collaborated boards"
  ON public.boards FOR UPDATE
  USING (
    auth.uid() = user_id OR
    auth.uid() = owner_id OR
    auth.uid() = created_by OR
    EXISTS (
      SELECT 1 FROM public.whiteboard_collaborators wc
      WHERE wc.whiteboard_id = boards.id AND wc.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete their owned boards"
  ON public.boards FOR DELETE
  USING (
    auth.uid() = user_id OR
    auth.uid() = owner_id OR
    auth.uid() = created_by
  );

-- ----------------------------------------------------------------------------
-- Board Versions RLS
-- ----------------------------------------------------------------------------
CREATE POLICY "Users can access versions of accessible boards"
  ON public.board_versions FOR ALL
  USING (
    auth.uid() = user_id OR
    auth.uid() = created_by OR
    EXISTS (
      SELECT 1 FROM public.boards b
      WHERE b.id = board_versions.board_id AND (
        b.user_id = auth.uid() OR b.owner_id = auth.uid() OR b.created_by = auth.uid()
      )
    )
  );

-- ----------------------------------------------------------------------------
-- Notifications RLS
-- ----------------------------------------------------------------------------
CREATE POLICY "Users can manage their own notifications"
  ON public.notifications FOR ALL
  USING (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- User Settings RLS
-- ----------------------------------------------------------------------------
CREATE POLICY "Users can manage their own settings"
  ON public.user_settings FOR ALL
  USING (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- Shapes RLS
-- ----------------------------------------------------------------------------
CREATE POLICY "Users can access shapes of accessible boards"
  ON public.shapes FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.boards b
      WHERE b.id = shapes.whiteboard_id AND (
        b.user_id = auth.uid() OR b.owner_id = auth.uid() OR b.created_by = auth.uid() OR b.is_public = TRUE OR
        EXISTS (
          SELECT 1 FROM public.whiteboard_collaborators wc
          WHERE wc.whiteboard_id = b.id AND wc.user_id = auth.uid()
        )
      )
    )
  );

-- ----------------------------------------------------------------------------
-- Whiteboard Collaborators RLS
-- ----------------------------------------------------------------------------
CREATE POLICY "Users can view collaborators"
  ON public.whiteboard_collaborators FOR SELECT
  USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM public.boards b
      WHERE b.id = whiteboard_collaborators.whiteboard_id AND (
        b.user_id = auth.uid() OR b.owner_id = auth.uid() OR b.created_by = auth.uid()
      )
    )
  );

-- ============================================================================
-- Automatic User Profile Creation Trigger on Auth Signup
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, name, full_name, avatar, created_at, updated_at)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', ''),
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger execution on auth.users insert
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- Supabase Storage Buckets & Policies Configuration
-- ============================================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Avatar images are publicly accessible"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

CREATE POLICY "Users can upload their own avatar image"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars' AND
    auth.role() = 'authenticated'
  );

CREATE POLICY "Users can update their own avatar image"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars' AND
    auth.role() = 'authenticated'
  );

CREATE POLICY "Users can delete their own avatar image"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'avatars' AND
    auth.role() = 'authenticated'
  );
