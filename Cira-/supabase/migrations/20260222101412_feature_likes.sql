-- ============================================
-- EPIC 5: POST INTERACTIONS (Likes & Comments)
-- ============================================

-- 11. POST_LIKES (User engagement)
CREATE TABLE IF NOT EXISTS public.post_likes (
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_post_likes_user ON public.post_likes(user_id);

-- Enable RLS
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;

-- POST_LIKES RLS Policies
CREATE POLICY "Users can view likes on visible posts" ON public.post_likes FOR SELECT 
    USING (EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_id AND p.is_active = true));
CREATE POLICY "Users can like posts" ON public.post_likes FOR INSERT 
    WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unlike their own likes" ON public.post_likes FOR DELETE 
    USING (auth.uid() = user_id);

-- Database Function to increment/decrement like_count on posts efficiently
CREATE OR REPLACE FUNCTION public.handle_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE public.posts SET like_count = like_count + 1 WHERE id = NEW.post_id;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE public.posts SET like_count = like_count - 1 WHERE id = OLD.post_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to execute the like_count function
DROP TRIGGER IF EXISTS trg_post_likes ON public.post_likes;
CREATE TRIGGER trg_post_likes
AFTER INSERT OR DELETE ON public.post_likes
FOR EACH ROW EXECUTE FUNCTION handle_like_count();

