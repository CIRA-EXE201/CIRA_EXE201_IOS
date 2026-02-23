-- ============================================
-- EPIC 5: POST AGGREGATES
-- ============================================

-- Add aggregate columns to posts table
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS like_count INT DEFAULT 0;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS comment_count INT DEFAULT 0;
