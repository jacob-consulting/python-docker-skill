# Python-Docker-Blueprint

This project is the blueprint for a Python/Docker project skill for claude-code and other tools. It provides a solid foundation for any Python application running in Docker, with built-in optional support for Django.

# Core principles

- the project uses Astral's UV
- together with `pyproject.toml` and `uv.lock`
- keep the project structure clean
  - source code is located in `src/`
- because we use the Python base image we don't need to use `uv run xyz.py`
- we can just use `python xyz.py` instead

## Django (optional)
When using Django:
- apps are located in `src/`
- at root level there are:
  - `manage.py`
  - `project/` which contains the `settings.py` for Django
  - `dynaconf` is used for environment-specific settings

# Docker

- this blueprint is for Docker projects
- don't rely on Astral's UV base images because of update delay in case of security findings
- use slim python images instead
- use a cache mount for dependencies
- use targets for:
  - `deps-prod`: installs only prod deps
  - `deps-test`: installs only test group deps
  - `deps-dev`: installs all deps (dev + test)
  - `prod`: inherits from `base` — copies the compiled venv from `deps-prod`; runs any build steps at build time
  - `test`: copies source into the image and runs pytest
  - `dev`: source is bind-mounted at runtime
- keep layers as small as possible
- add an app user and group
- args can define user and group
- `PYTHONPATH` includes both `$APP_DIR` (project root) and `$APP_DIR/src`

## Django-specific Docker notes
- `deps-prod` installs build tools (`gcc`, `libpcre3-dev`) needed to compile `uwsgi` from source
- `prod` installs only the runtime library (`libpcre3`), keeping build tools out of the final image; runs `collectstatic` at build time
- `prod` runs `uwsgi` as the WSGI server

# Docker Compose

## local development (`docker-compose.yml`)
- use system's uid/gid as args so mounted folders don't have files by weird container user
- mount `src/` at minimum; also mount `project/` when using Django

## testing (`docker-compose.test.yml`)
- targets the `test` Dockerfile stage
- runs `pytest --cov=src --cov-report=term-missing -q`
- source is baked into the image at build time (no volumes)
- run via: `task dc:test`

## production (`docker-compose.prod.yml`)
- targets the `prod` Dockerfile stage
- includes `restart: unless-stopped` and a stable `image:` tag
- run via: `task dc:prod-up` / `task dc:prod-down`

# Testing

- pytest is configured in `pyproject.toml` under `[tool.pytest.ini_options]`
- `testpaths = ["src"]` scopes discovery to the app source, avoiding submodule scanning
- run tests with coverage: `task dc:test`

## Django-specific testing notes
- `DJANGO_SETTINGS_MODULE` and `pythonpath` are set in `pyproject.toml` — no separate `pytest.ini` needed
- the `demo` app contains example tests in `src/demo/tests/`

# PyCharm
- use a docker-compose interpreter
- mark `src` as sources directory
- run configurations are stored in `.run`

# Taskfile
- `taskfile.yaml` is used for development
- there are included tasks:
  - `dc`: docker-compose commands
    - `dc:up` / `dc:down` — dev environment
    - `dc:test` — run tests with coverage in the test container
    - `dc:prod-up` / `dc:prod-down` — production environment
    - `dc:build`, `dc:logs`, `dc:bash`, `dc:ps`, `dc:restart`
  - `uv`: uv commands (`uv:lock`, `uv:upgrade`)
  - `m` *(optional, Django only)*: django manage commands (`m:migrate`, `m:makemigrations`, `m:collectstatic`, `m:superuser`)

# local development of Python packages
- packages under active development can be added as GIT submodules to `submodules/`
- see Dockerfile for details:
  - `deps-dev` target (it bind-mounts submodules during the dep install step)
  - `dev` target (it copies the submodules metadata to the container)
- the trick to install packages in editable mode is:
  - in `pyproject.toml` the package is added to `[tool.uv.sources]` for development
  - it points to the local path of the package, e.g. `submodules/my-lib`
  - and is defined as `editable = true`
- Important PyCharm configuration:
  - mark the source folders inside `submodules/my-lib`
