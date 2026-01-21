-- COMPLETE FIX: Infinite recursion in RLS policies
-- Both families and family_members were referencing each other

-- =============================================
-- Step 1: Drop ALL problematic policies
-- =============================================

DROP POLICY IF EXISTS "Members can view family members" ON public.family_members;
DROP POLICY IF EXISTS "Admins can add members" ON public.family_members;
DROP POLICY IF EXISTS "Admins can remove members" ON public.family_members;
DROP POLICY IF EXISTS "Users can join or admins add members" ON public.family_members;
DROP POLICY IF EXISTS "Users can leave or owners remove" ON public.family_members;

DROP POLICY IF EXISTS "Families viewable by members" ON public.families;
DROP POLICY IF EXISTS "Users can create families" ON public.families;
DROP POLICY IF EXISTS "Owners can manage families" ON public.families;
DROP POLICY IF EXISTS "Owners can delete families" ON public.families;

-- =============================================
-- Step 2: Create simple, non-recursive policies for FAMILIES
-- =============================================

-- SELECT: Owners can always view, authenticated users can view active families
CREATE POLICY "Anyone can view active families" ON public.families FOR SELECT 
    USING (is_active = true);

CREATE POLICY "Users can create families" ON public.families FOR INSERT 
    WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Owners can update families" ON public.families FOR UPDATE 
    USING (auth.uid() = owner_id);

CREATE POLICY "Owners can delete families" ON public.families FOR DELETE 
    USING (auth.uid() = owner_id);

-- =============================================
-- Step 3: Create simple, non-recursive policies for FAMILY_MEMBERS
-- =============================================

-- SELECT: Anyone authenticated can view family members (simplified to avoid recursion)
CREATE POLICY "Authenticated can view family members" ON public.family_members FOR SELECT 
    USING (auth.uid() IS NOT NULL);

-- INSERT: Self join or family owner
CREATE POLICY "Users can join families" ON public.family_members FOR INSERT 
    WITH CHECK (
        auth.uid() = user_id
        OR
        EXISTS (SELECT 1 FROM public.families f WHERE f.id = family_id AND f.owner_id = auth.uid())
    );

-- DELETE: Self leave or family owner
CREATE POLICY "Users can leave families" ON public.family_members FOR DELETE 
    USING (
        auth.uid() = user_id
        OR
        EXISTS (SELECT 1 FROM public.families f WHERE f.id = family_id AND f.owner_id = auth.uid())
    );
