# Supabase Docker (self-hosted)

This folder is populated by:

```bash
../../scripts/setup-supabase-docker.sh
```

It clones the official [Supabase Docker](https://github.com/supabase/supabase/tree/master/docker) template into this directory.

## Kong port

The root `.env` sets `KONG_HTTP_PORT=8003` so Kong does not conflict with ArSL Translator on **8000**.

Inside the Docker network, services still reach Kong at `http://kong:8000`.

## Do not commit

After setup, `volumes/` contains runtime data. It is listed in `.gitignore`.
