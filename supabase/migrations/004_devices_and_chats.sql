-- Rased — multi-device registry + saved AI conversations
-- Run after 001, 002, 003. Idempotent.

-- ============================================================
-- Devices: each agent self-registers (host_id, name, reachable API url).
-- The dashboard reads this to render one tab per machine.
-- Agents write via the service_role key (bypasses RLS).
-- ============================================================
CREATE TABLE IF NOT EXISTS public.devices (
    host_id TEXT PRIMARY KEY,
    host_name TEXT NOT NULL DEFAULT '',
    api_url TEXT NOT NULL DEFAULT '',
    last_seen TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "authenticated read devices" ON public.devices;
CREATE POLICY "authenticated read devices"
    ON public.devices FOR SELECT TO authenticated USING (true);

GRANT SELECT ON public.devices TO authenticated;

-- ============================================================
-- AI chats: saved conversations per user (resume / review later).
-- ============================================================
CREATE TABLE IF NOT EXISTS public.ai_chats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    host_id TEXT NOT NULL DEFAULT 'default',
    title TEXT NOT NULL DEFAULT 'Chat',
    messages JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_chats_user
    ON public.ai_chats (user_id, updated_at DESC);

ALTER TABLE public.ai_chats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "own chats select" ON public.ai_chats;
CREATE POLICY "own chats select" ON public.ai_chats FOR SELECT
    TO authenticated USING (user_id = auth.uid());

DROP POLICY IF EXISTS "own chats insert" ON public.ai_chats;
CREATE POLICY "own chats insert" ON public.ai_chats FOR INSERT
    TO authenticated WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "own chats update" ON public.ai_chats;
CREATE POLICY "own chats update" ON public.ai_chats FOR UPDATE
    TO authenticated USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "own chats delete" ON public.ai_chats;
CREATE POLICY "own chats delete" ON public.ai_chats FOR DELETE
    TO authenticated USING (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.ai_chats TO authenticated;
