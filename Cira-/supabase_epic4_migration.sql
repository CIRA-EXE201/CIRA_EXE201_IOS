-- ============================================
-- EPIC 4: SOCIAL FEATURES (Friends & Families)
-- Run this script to add new tables
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

-- Enable RLS
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.families ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;

-- FRIENDSHIPS RLS Policies
CREATE POLICY "Users can view own friendships" ON public.friendships FOR SELECT 
    USING (auth.uid() = requester_id OR auth.uid() = addressee_id);
CREATE POLICY "Users can send friend requests" ON public.friendships FOR INSERT 
    WITH CHECK (auth.uid() = requester_id);
CREATE POLICY "Users can update received requests" ON public.friendships FOR UPDATE 
    USING (auth.uid() = addressee_id OR auth.uid() = requester_id);
CREATE POLICY "Users can delete own requests" ON public.friendships FOR DELETE 
    USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

-- FAMILIES RLS Policies
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

-- FAMILY_MEMBERS RLS Policies
CREATE POLICY "Members can view family members" ON public.family_members FOR SELECT 
    USING (EXISTS (SELECT 1 FROM public.family_members fm WHERE fm.family_id = family_id AND fm.user_id = auth.uid()));
CREATE POLICY "Admins can add members" ON public.family_members FOR INSERT 
    WITH CHECK (
        auth.uid() = user_id OR
        EXISTS (SELECT 1 FROM public.family_members fm WHERE fm.family_id = family_id AND fm.user_id = auth.uid() AND fm.role = 'admin')
    );
CREATE POLICY "Admins can remove members" ON public.family_members FOR DELETE 
    USING (
        auth.uid() = user_id OR
        EXISTS (SELECT 1 FROM public.family_members fm WHERE fm.family_id = family_id AND fm.user_id = auth.uid() AND fm.role = 'admin')
    );
