# Dynaconf Integration Design

**Date:** 2026-04-22
**Project:** python-dockerfile-skill (Django/Docker blueprint)

## Goal

Replace the hardcoded `settings.py` values for `SECRET_KEY`, `DEBUG`, and `ALLOWED_HOSTS` with layered configuration via dynaconf: YAML defaults, per-environment YAML overrides, and environment variable overrides. Database config stays in `settings.py` as Python.

## File Layout

```
project/
  settings.py                  ← unchanged structure; removes hardcoded SECRET_KEY/DEBUG/ALLOWED_HOSTS; DjangoDynaconf hook at bottom
  settings.yaml                ← flat shared defaults (production-safe baseline)
  settings.development.yaml    ← DEBUG=true, ALLOWED_HOSTS=["*"]
  settings.testing.yaml        ← DEBUG=false (minimal)
  settings.production.yaml     ← DEBUG=false, ALLOWED_HOSTS placeholder
  .secrets.yaml                ← gitignored; SECRET_KEY for local dev
  .secrets.yaml.example        ← committed; documents what goes in .secrets.yaml
```

## settings.py Changes

Remove `SECRET_KEY`, `DEBUG`, `ALLOWED_HOSTS`. Keep everything else unchanged. Add at the bottom:

```python
import os
from dynaconf import DjangoDynaconf

_env = os.environ.get("ENV_FOR_DYNACONF", "development").lower()

DjangoDynaconf(
    django_settings_module=__name__,
    settings_files=[
        "project/settings.yaml",
        f"project/settings.{_env}.yaml",
        "project/.secrets.yaml",
    ],
    envvar_prefix="DJANGO",
    load_dotenv=False,
)
```

- `_env` is read before dynaconf initialises; the underscore keeps it out of Django's settings namespace.
- `load_dotenv=False`: the blueprint uses Docker env vars, not `.env` files.
- `envvar_prefix="DJANGO"`: `DJANGO_SECRET_KEY` env var overrides `secret_key` in yaml.

## YAML File Contents

### `project/settings.yaml` (flat, no environment sections)

```yaml
debug: false
secret_key: "insecure-placeholder-change-in-production"
allowed_hosts:
  - "localhost"
  - "127.0.0.1"
```

### `project/settings.development.yaml`

```yaml
debug: true
allowed_hosts:
  - "*"
```

### `project/settings.testing.yaml`

```yaml
debug: false
```

### `project/settings.production.yaml`

```yaml
debug: false
allowed_hosts:
  - "your-domain.com"  # replace with real hostname
```

### `project/.secrets.yaml` (gitignored)

```yaml
secret_key: "replace-with-output-of: python -c 'import secrets; print(secrets.token_hex())'"
```

### `project/.secrets.yaml.example` (committed)

```yaml
# Copy to .secrets.yaml and fill in real values
secret_key: "generate-with: python -c 'import secrets; print(secrets.token_hex())'"
```

## Docker Compose Changes

Each Compose file gets an `environment:` block.

**`docker-compose.yml` (dev):**
```yaml
environment:
  - ENV_FOR_DYNACONF=development
```

**`docker-compose.test.yml` (test):**
```yaml
environment:
  - ENV_FOR_DYNACONF=testing
```

**`docker-compose.prod.yml` (prod):**
```yaml
environment:
  - ENV_FOR_DYNACONF=production
  - DJANGO_SECRET_KEY=${DJANGO_SECRET_KEY}
```

`DJANGO_SECRET_KEY` is expected on the host shell (or secrets manager). Compose errors loudly if unset — correct behaviour for prod.

## `pyproject.toml` Changes

Add `dynaconf` to default `[project.dependencies]`:

```toml
dependencies = [
    "django<=6.0",
    "django-crud-views",
    "django-ordered-model",
    "dynaconf",
]
```

Dynaconf is needed in all three environments (dev, test, prod all import `settings.py`).

## `.gitignore` Changes

Add `project/.secrets.yaml` to `.gitignore`.

## Layering Order (lowest → highest priority)

1. `project/settings.yaml` (shared defaults)
2. `project/settings.{env}.yaml` (environment overrides)
3. `project/.secrets.yaml` (local secrets)
4. `DJANGO_*` environment variables (runtime overrides, highest priority)
