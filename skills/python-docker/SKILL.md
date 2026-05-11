---
name: python-docker
description: Use when creating a Python project from scratch with Docker, migrating an existing Python project to this multi-stage Docker blueprint, adding dynaconf for environment-specific settings, adding git submodule libraries as editable packages, or adding default Taskfile tasks. Supports optional Django integration.
---

# Python Docker Blueprint

## Overview

A multi-stage Python Dockerfile blueprint using `uv` for dependency management and optionally `dynaconf` for environment-specific settings. Produces minimal, reproducible images for dev, test, and prod. Django is supported as an optional addition — see `settings.md` for Django + dynaconf configuration.

## Reference Files

- `dockerfile.md` — complete Dockerfile (5 stages) + non-obvious decisions
- `compose.md` — docker-compose.yml (dev), docker-compose.test.yml, docker-compose.prod.yml
- `settings.md` — dynaconf integration with settings/ subdirectory, validators, and YAML-only config *(Django optional)*
- `pyproject.md` — pyproject.toml with PEP 735 dependency groups
- `taskfile.md` — taskfile.yaml + tasks/ directory
- `submodules.md` — git submodule as editable package

## Critical Non-Obvious Rules

**Always check these first — they cause silent failures:**

1. **Test compose needs an explicit `image:` tag** — without it, Docker auto-generates the same image name as dev compose and reuses the dev image for tests, causing "No module named ..." or stale code errors.

2. **`.secrets.yaml` in BOTH `.gitignore` AND `.dockerignore`** — gitignore prevents committing it; dockerignore prevents baking it into the image layer.

3. **`--no-install-project` in deps stages** — the project package itself isn't present during dependency installation; omitting this flag causes build failures.

4. **`--no-default-groups` in prod and test stages** — without this flag, uv installs all dependency groups including dev tools in prod/test images.

### Django + dynaconf rules (only when using Django)

5. **`ENV_FOR_DYNACONF`** is the environment selector (not `DJANGO_ENV`, `DJANGO_ENVIRONMENT`, or any other name). Set it in every Compose `environment:` block.

6. **dynaconf settings_file paths are relative to settings.py's directory** — `"settings/base.yaml"` not `"project/settings/base.yaml"`. DjangoDynaconf uses the calling `settings.py` file's directory as `root_path`.

7. **`environments=False`** in DjangoDynaconf — YAML files are flat (no `[default]`/`[production]` sections). One file per environment.

8. **`${DJANGO_SECRET_KEY:?message}`** in prod compose (not bare `${DJANGO_SECRET_KEY}`) — the `:?` syntax makes Compose fail fast with a clear error when the variable is unset.

9. **uwsgi goes in the `prod` dependency group only** — it requires gcc to compile; other stages don't install it and must not have gcc installed.
