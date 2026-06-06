-- Rased — Metrics history + alert log
-- Run this in the Supabase SQL Editor (after 001_initial.sql).
--
-- The backend agent writes here using the service_role key (which bypasses RLS).
-- Authenticated dashboard users get read-only access for historical charts.

-- ============================================================
-- Downsampled metric snapshots (for historical charts)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.metrics_history (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    host_id TEXT NOT NULL DEFAULT 'default',
    host_cpu DOUBLE PRECISION,
    host_mem DOUBLE PRECISION,
    host_disk_max DOUBLE PRECISION,
    containers_running INT,
    containers_total INT,
    ups_on_battery BOOLEAN,
    battery DOUBLE PRECISION,
    containers JSONB
);

CREATE INDEX IF NOT EXISTS idx_metrics_history_ts
    ON public.metrics_history (ts DESC);
CREATE INDEX IF NOT EXISTS idx_metrics_history_host
    ON public.metrics_history (host_id, ts DESC);

ALTER TABLE public.metrics_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "authenticated read metrics_history" ON public.metrics_history;
CREATE POLICY "authenticated read metrics_history"
    ON public.metrics_history FOR SELECT
    TO authenticated USING (true);

GRANT SELECT ON public.metrics_history TO authenticated;

-- ============================================================
-- Alert log (persistent history of fired alerts)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.alerts (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    host_id TEXT NOT NULL DEFAULT 'default',
    level TEXT NOT NULL DEFAULT 'warning',
    kind TEXT NOT NULL,
    target TEXT NOT NULL,
    message TEXT NOT NULL,
    value DOUBLE PRECISION
);

CREATE INDEX IF NOT EXISTS idx_alerts_ts ON public.alerts (ts DESC);

ALTER TABLE public.alerts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "authenticated read alerts" ON public.alerts;
CREATE POLICY "authenticated read alerts"
    ON public.alerts FOR SELECT
    TO authenticated USING (true);

GRANT SELECT ON public.alerts TO authenticated;

-- ============================================================
-- Retention: call periodically (e.g. via pg_cron or an n8n schedule)
--   SELECT public.prune_metrics_history(14);
-- ============================================================
CREATE OR REPLACE FUNCTION public.prune_metrics_history(retain_days INT DEFAULT 14)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    DELETE FROM public.metrics_history
        WHERE ts < NOW() - make_interval(days => retain_days);
    DELETE FROM public.alerts
        WHERE ts < NOW() - make_interval(days => retain_days);
END;
$$;

-- Optional: schedule daily pruning if pg_cron is available
-- SELECT cron.schedule('rased-prune', '0 3 * * *', $$SELECT public.prune_metrics_history(14)$$);
