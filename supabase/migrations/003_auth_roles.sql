-- Rased — user profiles + roles (admin / viewer)
-- Run after 001 and 002. Idempotent.

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    role TEXT NOT NULL DEFAULT 'viewer' CHECK (role IN ('admin', 'viewer')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- is_admin(): SECURITY DEFINER so it bypasses RLS (no recursion with policies below)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
    );
$$;

-- Read: own profile, or everything if admin.
DROP POLICY IF EXISTS "read profiles" ON public.profiles;
CREATE POLICY "read profiles"
    ON public.profiles FOR SELECT TO authenticated
    USING (id = auth.uid() OR public.is_admin());

-- Update: only admins (e.g. to change roles).
DROP POLICY IF EXISTS "admin update profiles" ON public.profiles;
CREATE POLICY "admin update profiles"
    ON public.profiles FOR UPDATE TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

GRANT SELECT, UPDATE ON public.profiles TO authenticated;

-- ensure_profile(): called by the app after login. Creates the caller's profile
-- if missing. The very first user becomes 'admin', everyone else 'viewer'.
-- Returns the caller's role. Avoids any trigger on auth.users (which the
-- limited Supabase `postgres` role may not be allowed to create).
CREATE OR REPLACE FUNCTION public.ensure_profile(p_email TEXT DEFAULT '')
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    existing_role TEXT;
    total INT;
    new_role TEXT;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT role INTO existing_role FROM public.profiles WHERE id = auth.uid();
    IF existing_role IS NOT NULL THEN
        RETURN existing_role;
    END IF;

    SELECT count(*) INTO total FROM public.profiles;
    new_role := CASE WHEN total = 0 THEN 'admin' ELSE 'viewer' END;

    INSERT INTO public.profiles (id, email, role)
    VALUES (auth.uid(), NULLIF(p_email, ''), new_role)
    ON CONFLICT (id) DO NOTHING;

    RETURN new_role;
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_profile(TEXT) TO authenticated;
