# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in this repository.

## What This Repo Is

A **dual-purpose project**: it is simultaneously a working Django application *and* the authoritative source for a Claude Code skill.

- `skills/python-docker/` — the skill reference files Claude uses when creating Python/Docker projects
- `Dockerfile`, `docker-compose*.yml`, `pyproject.toml` — the live example that implements the blueprint

When either changes, keep both in sync.

## Commands

All development runs inside Docker via [Task](https://taskfile.dev).

```bash
task dc:up           # start dev environment
task dc:down         # stop and clean up
task dc:test         # run full test suite in a fresh container
task dc:bash         # shell into the running app container
task dc:logs         # tail app logs

task uv:lock         # update uv.lock after editing pyproject.toml
task uv:upgrade      # upgrade all dependencies

# Django manage.py (requires m: include in taskfile.yaml):
task m:migrate
task m:makemigrations
task m:superuser     # creates admin / foobar4711
```

Run a single test file inside the container:
```bash
docker compose run --rm app pytest src/path/to/test_foo.py -v
```

## Architecture

### Dockerfile stages

```
uv          ← pinned binary carrier
base        ← OS + uv + non-root user + env vars
deps-prod   ← venv, prod group only (has gcc for uwsgi compilation)
deps-test   ← venv, test group only
deps-dev    ← venv, all groups (bind-mounts submodules/ so editable paths resolve)
prod        ← final image: copies venv from deps-prod, runs collectstatic, drops to app user
test        ← bakes source in, runs pytest
dev         ← copies only metadata; src/ is bind-mounted at runtime
```

### Dependency groups (PEP 735)

Each group maps to exactly one Dockerfile stage. `uwsgi` lives in `prod` only because it requires gcc to compile — adding it elsewhere breaks builds.

### Git submodules as editable packages

Co-developed packages live in `submodules/`. They are registered in `[tool.uv.sources]` as `{ path = "...", editable = true }`. The `deps-dev` stage bind-mounts `submodules/` during the build so uv can resolve the editable path without baking the source into the image. See `skills/python-docker/submodules.md` for the full setup pattern.

### Django + dynaconf

Settings live in YAML files under `project/settings/` (`base.yaml`, `development.yaml`, `testing.yaml`, `production.yaml`). `settings.py` contains only `BASE_DIR`, the `DjangoDynaconf()` hook, and validators — no Django settings in Python. `ENV_FOR_DYNACONF` selects the active overlay — set it in every Compose `environment:` block.

## Skill Files

The skill is the source of truth for patterns Claude should follow in *new* projects. When updating the blueprint, update the corresponding reference file:

| Topic | File |
|---|---|
| Dockerfile | `skills/python-docker/dockerfile.md` |
| Docker Compose | `skills/python-docker/compose.md` |
| pyproject.toml | `skills/python-docker/pyproject.md` |
| dynaconf / settings | `skills/python-docker/settings.md` |
| Taskfile | `skills/python-docker/taskfile.md` |
| Git submodules | `skills/python-docker/submodules.md` |

Critical non-obvious rules (silent failure causes) are listed in `skills/python-docker/SKILL.md` under "Critical Non-Obvious Rules" — read that section before modifying the blueprint.
