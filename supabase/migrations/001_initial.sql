-- AI Server Dashboard - Supabase Schema
-- Run this in the Supabase SQL Editor

-- Enable pgcrypto for API key encryption
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- Settings table (AI provider configuration per user)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    provider_type TEXT NOT NULL CHECK (provider_type IN ('ollama', 'lm_studio', 'cloud', 'custom')),
    base_url TEXT NOT NULL DEFAULT '',
    model_name TEXT NOT NULL,
    -- api_key stored encrypted with pgcrypto (encrypt on insert/update via trigger)
    api_key_encrypted BYTEA,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id)
);

-- Allow any provider_type (OpenAI-compatible, Anthropic/Claude, or custom gateways).
ALTER TABLE public.settings DROP CONSTRAINT IF EXISTS settings_provider_type_check;

-- Encryption key for the stored AI api_key.
-- NOTE: Supabase's `postgres` role is NOT a superuser, so it cannot
-- `ALTER DATABASE ... SET app.*` to persist a custom GUC (it errors with
-- "permission denied to set parameter"). Instead, the RPCs below resolve the
-- key from current_setting() with a hardcoded fallback.
-- CHANGE THE FALLBACK in production (keep it constant, or saved keys can't be
-- decrypted). To override at the DB level, run as a superuser (supabase_admin):
--   ALTER DATABASE postgres SET app.settings_encryption_key = 'your-secret';

-- Helper: upsert settings with encrypted API key (call from app via RPC)
-- (updated_at is maintained directly inside the RPC below.)
CREATE OR REPLACE FUNCTION public.upsert_settings(
    p_provider_type TEXT,
    p_base_url TEXT,
    p_model_name TEXT,
    p_api_key TEXT DEFAULT ''
)
RETURNS public.settings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    enc_key TEXT;
    result public.settings;
BEGIN
    enc_key := coalesce(
        nullif(current_setting('app.settings_encryption_key', true), ''),
        'dev-change-me-in-production'
    );

    INSERT INTO public.settings (user_id, provider_type, base_url, model_name, api_key_encrypted)
    VALUES (
        auth.uid(),
        p_provider_type,
        p_base_url,
        p_model_name,
        CASE
            WHEN p_api_key IS NOT NULL AND p_api_key <> '' THEN
                pgp_sym_encrypt(p_api_key, enc_key)
            ELSE NULL
        END
    )
    ON CONFLICT (user_id) DO UPDATE SET
        provider_type = EXCLUDED.provider_type,
        base_url = EXCLUDED.base_url,
        model_name = EXCLUDED.model_name,
        api_key_encrypted = CASE
            WHEN p_api_key IS NOT NULL AND p_api_key <> '' THEN
                pgp_sym_encrypt(p_api_key, enc_key)
            ELSE public.settings.api_key_encrypted
        END,
        updated_at = NOW()
    RETURNING * INTO result;

    RETURN result;
END;
$$;

-- Helper: read decrypted settings for authenticated user
CREATE OR REPLACE FUNCTION public.get_settings_decrypted()
RETURNS TABLE (
    id UUID,
    provider_type TEXT,
    base_url TEXT,
    model_name TEXT,
    api_key TEXT,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    enc_key TEXT;
BEGIN
    enc_key := coalesce(
        nullif(current_setting('app.settings_encryption_key', true), ''),
        'dev-change-me-in-production'
    );

    RETURN QUERY
    SELECT
        s.id,
        s.provider_type,
        s.base_url,
        s.model_name,
        CASE
            WHEN s.api_key_encrypted IS NOT NULL THEN
                pgp_sym_decrypt(s.api_key_encrypted, enc_key)::TEXT
            ELSE ''
        END AS api_key,
        s.updated_at
    FROM public.settings s
    WHERE s.user_id = auth.uid();
END;
$$;

-- Public view without api_key (safe for listing)
CREATE OR REPLACE VIEW public.settings_safe AS
SELECT
    id,
    user_id,
    provider_type,
    base_url,
    model_name,
    (api_key_encrypted IS NOT NULL) AS has_api_key,
    updated_at
FROM public.settings;

-- ============================================================
-- Row Level Security
-- ============================================================
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own settings" ON public.settings;
CREATE POLICY "Users can view own settings"
    ON public.settings FOR SELECT
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own settings" ON public.settings;
CREATE POLICY "Users can insert own settings"
    ON public.settings FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own settings" ON public.settings;
CREATE POLICY "Users can update own settings"
    ON public.settings FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own settings" ON public.settings;
CREATE POLICY "Users can delete own settings"
    ON public.settings FOR DELETE
    USING (auth.uid() = user_id);

-- Grant execute on RPC functions to authenticated users
GRANT EXECUTE ON FUNCTION public.upsert_settings(TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_settings_decrypted() TO authenticated;
GRANT SELECT ON public.settings_safe TO authenticated;

-- ============================================================
-- Realtime Broadcast
-- Enable Realtime for broadcast channel in Supabase Dashboard:
--   Project Settings > API > Realtime > Enable Broadcast
-- Channel name used by backend: server-metrics
-- Event: metrics
-- ============================================================
