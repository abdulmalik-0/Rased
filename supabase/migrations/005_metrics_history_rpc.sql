-- Rased — time-bucketed metrics history (for day/week/month charts).
-- Returns ~p_buckets averaged points over the last p_hours, so weekly/monthly
-- views stay light regardless of how many raw snapshots exist.

CREATE OR REPLACE FUNCTION public.get_metrics_history(
    p_hours INT DEFAULT 24,
    p_buckets INT DEFAULT 200
)
RETURNS TABLE (
    ts TIMESTAMPTZ,
    host_cpu DOUBLE PRECISION,
    host_mem DOUBLE PRECISION,
    host_disk_max DOUBLE PRECISION,
    containers_running INT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    WITH params AS (
        SELECT
            greatest(1, (p_hours * 3600) / greatest(1, p_buckets)) AS bucket_secs,
            now() - make_interval(hours => p_hours) AS start_ts
    )
    SELECT
        to_timestamp(
            floor(extract(epoch FROM m.ts) / p.bucket_secs) * p.bucket_secs
        ) AS ts,
        avg(m.host_cpu) AS host_cpu,
        avg(m.host_mem) AS host_mem,
        max(m.host_disk_max) AS host_disk_max,
        max(m.containers_running)::int AS containers_running
    FROM public.metrics_history m, params p
    WHERE m.ts >= p.start_ts
    GROUP BY 1
    ORDER BY 1;
$$;

GRANT EXECUTE ON FUNCTION public.get_metrics_history(INT, INT) TO authenticated;
