-- ============================================================================
-- FULL SUPABASE SCHEMA & CONFIGURATION SCRIPT FOR SOCIAL APP
-- Run this complete script in the Supabase SQL Editor.
-- It configures tables, constraints, foreign keys, triggers, RLS policies,
-- storage buckets, storage policies, and realtime publication.
-- ============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. PUBLIC TABLES

-- PROFILES TABLE
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE DEFAULT auth.uid(),
    full_name VARCHAR NOT NULL,
    bio TEXT,
    image_url VARCHAR,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- POSTS TABLE
CREATE TABLE IF NOT EXISTS public.posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content TEXT NOT NULL,
    image_url VARCHAR,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE DEFAULT auth.uid(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- LIKES TABLE
CREATE TABLE IF NOT EXISTS public.likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE DEFAULT auth.uid(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT likes_post_user_unique UNIQUE (post_id, user_id)
);

-- COMMENTS TABLE
CREATE TABLE IF NOT EXISTS public.comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE DEFAULT auth.uid(),
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- 3. AUTOMATIC PROFILE CREATION TRIGGER ON USER SIGNUP
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name)
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data ->> 'full_name', 'Anonymous User')
    )
    ON CONFLICT (id) DO UPDATE
    SET full_name = EXCLUDED.full_name;

    RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. ROW LEVEL SECURITY (RLS) ACTIVATION
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

-- 5. RLS POLICIES

-- PROFILES POLICIES
DROP POLICY IF EXISTS "Enable read access for all users" ON public.profiles;
CREATE POLICY "Enable read access for all users"
    ON public.profiles FOR SELECT
    TO public
    USING (true);

DROP POLICY IF EXISTS "Enable insert for users based on user_id" ON public.profiles;
CREATE POLICY "Enable insert for users based on user_id"
    ON public.profiles FOR INSERT
    TO public
    WITH CHECK ((SELECT auth.uid()) = id);

DROP POLICY IF EXISTS "Enable update for users based on user_id" ON public.profiles;
CREATE POLICY "Enable update for users based on user_id"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING ((SELECT auth.uid()) = id)
    WITH CHECK ((SELECT auth.uid()) = id);

-- POSTS POLICIES
DROP POLICY IF EXISTS "Enable read access for all users" ON public.posts;
CREATE POLICY "Enable read access for all users"
    ON public.posts FOR SELECT
    TO public
    USING (true);

DROP POLICY IF EXISTS "Enable insert for users based on user_id" ON public.posts;
CREATE POLICY "Enable insert for users based on user_id"
    ON public.posts FOR INSERT
    TO public
    WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Enable update for users based on user_id" ON public.posts;
CREATE POLICY "Enable update for users based on user_id"
    ON public.posts FOR UPDATE
    TO authenticated
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Enable delete for users based on user_id" ON public.posts;
CREATE POLICY "Enable delete for users based on user_id"
    ON public.posts FOR DELETE
    TO authenticated
    USING ((SELECT auth.uid()) = user_id);

-- LIKES POLICIES
DROP POLICY IF EXISTS "Enable read access for all users" ON public.likes;
CREATE POLICY "Enable read access for all users"
    ON public.likes FOR SELECT
    TO public
    USING (true);

DROP POLICY IF EXISTS "Enable insert for users based on user_id" ON public.likes;
CREATE POLICY "Enable insert for users based on user_id"
    ON public.likes FOR INSERT
    TO public
    WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Enable delete for users based on user_id" ON public.likes;
CREATE POLICY "Enable delete for users based on user_id"
    ON public.likes FOR DELETE
    TO public
    USING ((SELECT auth.uid()) = user_id);

-- COMMENTS POLICIES
DROP POLICY IF EXISTS "Enable read access for all users" ON public.comments;
CREATE POLICY "Enable read access for all users"
    ON public.comments FOR SELECT
    TO public
    USING (true);

DROP POLICY IF EXISTS "Enable insert for users based on user_id" ON public.comments;
CREATE POLICY "Enable insert for users based on user_id"
    ON public.comments FOR INSERT
    TO public
    WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Enable delete for users based on user_id" ON public.comments;
CREATE POLICY "Enable delete for users based on user_id"
    ON public.comments FOR DELETE
    TO public
    USING ((SELECT auth.uid()) = user_id);

-- 6. STORAGE BUCKET CONFIGURATION
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'social_files',
    'social_files',
    true,
    52428800, -- 50 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 52428800,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

-- 7. STORAGE POLICIES
DROP POLICY IF EXISTS "Public can view social_files" ON storage.objects;
CREATE POLICY "Public can view social_files"
    ON storage.objects FOR SELECT
    TO public
    USING (bucket_id = 'social_files');

DROP POLICY IF EXISTS "authenticated user can do anything 18w6ucl_0" ON storage.objects;
DROP POLICY IF EXISTS "authenticated user can do anything 18w6ucl_1" ON storage.objects;
DROP POLICY IF EXISTS "authenticated user can do anything 18w6ucl_2" ON storage.objects;
DROP POLICY IF EXISTS "authenticated user can do anything 18w6ucl_3" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated can insert social_files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated can update social_files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated can delete social_files" ON storage.objects;

CREATE POLICY "Authenticated can insert social_files"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'social_files');

CREATE POLICY "Authenticated can update social_files"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (bucket_id = 'social_files');

CREATE POLICY "Authenticated can delete social_files"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (bucket_id = 'social_files');

-- 8. REALTIME REPLICATION SETUP
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'posts'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.posts;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'likes'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.likes;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'comments'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.comments;
    END IF;
END $$;
