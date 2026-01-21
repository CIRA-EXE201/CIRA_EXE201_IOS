-- ============================================
-- CIRA Supabase Migration Script
-- Epic 1: Database Schema & Storage Setup
-- ============================================

-- 1. ROLES (RBAC)
CREATE TABLE IF NOT EXISTS public.roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Seed default roles
INSERT INTO public.roles (name, description) VALUES
    ('admin', 'Full system access'),
    ('user', 'Standard user'),
    ('premium', 'Premium subscriber')
ON CONFLICT (name) DO NOTHING;

-- 2. PROFILES (1:1 with auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE,
    avatar_data BYTEA,
    bio TEXT,
    is_active BOOLEAN DEFAULT true,
    last_seen_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Trigger: Auto-create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username)
    VALUES (NEW.id, NEW.raw_user_meta_data->>'username');
    
    -- Assign default 'user' role
    INSERT INTO public.user_roles (user_id, role_id)
    SELECT NEW.id, r.id FROM public.roles r WHERE r.name = 'user';
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. USER_ROLES (Many-to-Many)
CREATE TABLE IF NOT EXISTS public.user_roles (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    role_id UUID REFERENCES public.roles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, role_id)
);

-- 4. AUTH_TOKENS
CREATE TABLE IF NOT EXISTS public.auth_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    access_token TEXT NOT NULL,
    refresh_token TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    device_fingerprint TEXT,
    revoked BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. CHAPTERS
CREATE TABLE IF NOT EXISTS public.chapters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    cover_data BYTEA,
    is_active BOOLEAN DEFAULT true,
    view_count BIGINT DEFAULT 0,
    item_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 6. POSTS
CREATE TABLE IF NOT EXISTS public.posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    chapter_id UUID REFERENCES public.chapters(id) ON DELETE SET NULL,
    image_data BYTEA,
    live_photo_data BYTEA,
    message TEXT,
    voice_url TEXT,
    voice_duration FLOAT8,
    voice_waveform JSONB,
    sync_status TEXT DEFAULT 'synced',
    is_active BOOLEAN DEFAULT true,
    view_count BIGINT DEFAULT 0,
    like_count BIGINT DEFAULT 0,
    share_count BIGINT DEFAULT 0,
    device_info JSONB,
    location_metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 7. USER_EVENTS (Analytics)
CREATE TABLE IF NOT EXISTS public.user_events (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id UUID REFERENCES public.profiles(id),
    event_name TEXT NOT NULL,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_posts_owner ON public.posts(owner_id);
CREATE INDEX IF NOT EXISTS idx_posts_chapter ON public.posts(chapter_id);
CREATE INDEX IF NOT EXISTS idx_posts_created ON public.posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chapters_owner ON public.chapters(owner_id);
CREATE INDEX IF NOT EXISTS idx_user_events_name ON public.user_events(event_name);
CREATE INDEX IF NOT EXISTS idx_user_events_user ON public.user_events(user_id);

-- ============================================
-- EPIC 4: SOCIAL FEATURES (Friends & Families)
-- ============================================

-- 8. FRIENDSHIPS (User Connections)
CREATE TABLE IF NOT EXISTS public.friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    addressee_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'blocked')),
    created_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT unique_friendship UNIQUE (requester_id, addressee_id),
    CONSTRAINT no_self_friend CHECK (requester_id != addressee_id)
);

CREATE INDEX IF NOT EXISTS idx_friendships_requester ON public.friendships(requester_id);
CREATE INDEX IF NOT EXISTS idx_friendships_addressee ON public.friendships(addressee_id);
CREATE INDEX IF NOT EXISTS idx_friendships_status ON public.friendships(status);

-- 9. FAMILIES (Group Entity)
CREATE TABLE IF NOT EXISTS public.families (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    cover_data BYTEA,
    owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    invite_code TEXT UNIQUE DEFAULT substring(md5(random()::text) from 1 for 8),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_families_owner ON public.families(owner_id);
CREATE INDEX IF NOT EXISTS idx_families_invite_code ON public.families(invite_code);

-- 10. FAMILY_MEMBERS (Group Membership)
CREATE TABLE IF NOT EXISTS public.family_members (
    family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT DEFAULT 'member' CHECK (role IN ('admin', 'member')),
    joined_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (family_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_family_members_user ON public.family_members(user_id);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auth_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.families ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;

-- PROFILES: Users can read all, update own
CREATE POLICY "Profiles are viewable by everyone" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- CHAPTERS: Owner full access, others read if active
CREATE POLICY "Chapters are viewable if active" ON public.chapters FOR SELECT USING (is_active = true);
CREATE POLICY "Users can manage own chapters" ON public.chapters FOR ALL USING (auth.uid() = owner_id);

-- POSTS: Owner full access, others read if active
CREATE POLICY "Posts are viewable if active" ON public.posts FOR SELECT USING (is_active = true);
CREATE POLICY "Users can manage own posts" ON public.posts FOR ALL USING (auth.uid() = owner_id);

-- AUTH_TOKENS: Owner only
CREATE POLICY "Users can view own tokens" ON public.auth_tokens FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own tokens" ON public.auth_tokens FOR ALL USING (auth.uid() = user_id);

-- USER_EVENTS: Insert only for authenticated, Admin read all
CREATE POLICY "Users can insert own events" ON public.user_events FOR INSERT WITH CHECK (auth.uid() = user_id);

-- FRIENDSHIPS: Users can view their own friendships, manage requests they sent
CREATE POLICY "Users can view own friendships" ON public.friendships FOR SELECT 
    USING (auth.uid() = requester_id OR auth.uid() = addressee_id);
CREATE POLICY "Users can send friend requests" ON public.friendships FOR INSERT 
    WITH CHECK (auth.uid() = requester_id);
CREATE POLICY "Users can update received requests" ON public.friendships FOR UPDATE 
    USING (auth.uid() = addressee_id OR auth.uid() = requester_id);
CREATE POLICY "Users can delete own requests" ON public.friendships FOR DELETE 
    USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

-- FAMILIES: Owner full access, members can view active families
CREATE POLICY "Families viewable by members" ON public.families FOR SELECT 
    USING (is_active = true AND (
        auth.uid() = owner_id OR 
        EXISTS (SELECT 1 FROM public.family_members fm WHERE fm.family_id = id AND fm.user_id = auth.uid())
    ));
CREATE POLICY "Users can create families" ON public.families FOR INSERT 
    WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Owners can manage families" ON public.families FOR UPDATE 
    USING (auth.uid() = owner_id);
CREATE POLICY "Owners can delete families" ON public.families FOR DELETE 
    USING (auth.uid() = owner_id);

-- FAMILY_MEMBERS: Members can view, admins can manage
CREATE POLICY "Members can view family members" ON public.family_members FOR SELECT 
    USING (EXISTS (SELECT 1 FROM public.family_members fm WHERE fm.family_id = family_id AND fm.user_id = auth.uid()));
CREATE POLICY "Admins can add members" ON public.family_members FOR INSERT 
    WITH CHECK (
        auth.uid() = user_id OR  -- Self join via invite code
        EXISTS (SELECT 1 FROM public.family_members fm WHERE fm.family_id = family_id AND fm.user_id = auth.uid() AND fm.role = 'admin')
    );
CREATE POLICY "Admins can remove members" ON public.family_members FOR DELETE 
    USING (
        auth.uid() = user_id OR  -- Self leave
        EXISTS (SELECT 1 FROM public.family_members fm WHERE fm.family_id = family_id AND fm.user_id = auth.uid() AND fm.role = 'admin')
    );

-- ============================================
-- STORAGE BUCKET: audios
-- ============================================
-- Run this in Supabase Dashboard > Storage > Create new bucket
-- Name: audios
-- Public: false
-- RLS: Enable

-- Storage RLS Policy (apply via Dashboard or SQL):
-- INSERT: authenticated users can upload to their folder
-- SELECT: public read
-- DELETE: owner only
