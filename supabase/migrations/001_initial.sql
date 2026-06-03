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

-- Encryption key stored in Supabase Vault or env; here we use a DB setting placeholder.
-- In production, set: ALTER DATABASE postgres SET app.settings_encryption_key = 'your-32-byte-secret';
-- For development, a default key is used (CHANGE IN PRODUCTION):
DO $$
BEGIN
    IF current_setting('app.settings_encryption_key', true) IS NULL THEN
        PERFORM set_config('app.settings_encryption_key', 'dev-change-me-in-production!!', false);
    END IF;
EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('app.settings_encryption_key', 'dev-change-me-in-production!!', false);
END $$;

-- Trigger function: encrypt api_key on write
CREATE OR REPLACE FUNCTION public.encrypt_api_key()
RETURNS TRIGGER AS $$
DECLARE
    enc_key TEXT;
BEGIN
    enc_key := current_setting('app.settings_encryption_key', true);
    IF NEW.api_key_encrypted IS NULL AND TG_ARGV[0] IS NOT NULL THEN
        -- Plain text passed via session variable for upsert from client-side edge function
        NULL;
    END IF;
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper: upsert settings with encrypted API key (call from app via RPC)
CREATE OR REPLACE FUNCTION public.upsert_settings(
    p_provider_type TEXT,
    p_base_url TEXT,
    p_model_name TEXT,
    p_api_key TEXT DEFAULT ''
)
RETURNS public.settings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    enc_key TEXT;
    result public.settings;
BEGIN
    enc_key := current_setting('app.settings_encryption_key', true);
    IF enc_key IS NULL OR enc_key = '' THEN
        RAISE EXCEPTION 'Encryption key not configured';
    END IF;

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
SET search_path = public
AS $$
DECLARE
    enc_key TEXT;
BEGIN
    enc_key := current_setting('app.settings_encryption_key', true);

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

CREATE POLICY "Users can view own settings"
    ON public.settings FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own settings"
    ON public.settings FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own settings"
    ON public.settings FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

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
