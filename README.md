# Django-Project-Skill

This project is the blueprint for a Django/Docker project skill for claude-code and other tools.

# Core principles

- the project uses Astral's UV
- together with `pyproject.toml` and `uv.lock`
- keep the project structure clean
  - apps are located in `src/`
  - at root level there are:
    - `manage.py`
    - `project/` which contains the `settings.py` for Django
- because we use the Python base image we don't need to use `uv run xyz.py`
- we can just use `python xyz.py` instead

# Docker

- this blueprint is for Docker projects
- don't rely on Astral's UV base images because of update delay in case of security findings
- use slim python images instead
- use a cache mount for dependencies
- use targets for:
  - `deps-prod`: installs only prod deps; also installs build tools (`gcc`, `libpcre3-dev`) needed to compile `uwsgi` from source
  - `deps-test`: installs only test group deps
  - `deps-dev`: installs all deps (dev + test)
  - `prod`: inherits from `base` (not `deps-prod`) — copies the compiled venv from `deps-prod` and installs only the runtime library (`libpcre3`), keeping build tools out of the final image; runs `collectstatic` at build time
  - `test`: copies source into the image and runs pytest
  - `dev`: source is bind-mounted at runtime
- keep layers as small as possible
- add an app user and group
- args can define user and group
- `PYTHONPATH` includes both `$APP_DIR` (project root) and `$APP_DIR/src` (apps)

# Docker Compose

## local development (`docker-compose.yml`)
- use system's uid/gid as args so mounted folders don't have files by weird container user
- mount:
  - `src`
  - `project`
  - `db.sqlite3` if using sqlite

## testing (`docker-compose.test.yml`)
- targets the `test` Dockerfile stage
- runs `pytest --cov=src --cov-report=term-missing -q`
- source is baked into the image at build time (no volumes)
- run via: `task dc:test`

## production (`docker-compose.prod.yml`)
- targets the `prod` Dockerfile stage
- serves with `uwsgi` via `--http` and `--static-map` for static files
- static files are baked into the image at build time via `collectstatic`
- SQLite is bind-mounted for data persistence
- includes `restart: unless-stopped` and a stable `image:` tag
- run via: `task dc:prod-up` / `task dc:prod-down`

# Testing

- pytest is configured in `pyproject.toml` under `[tool.pytest.ini_options]`
- `DJANGO_SETTINGS_MODULE` and `pythonpath` are set there — no separate `pytest.ini` needed
- `testpaths = ["src"]` scopes discovery to the app source, avoiding submodule scanning
- the `demo` app contains example tests in `src/demo/tests/`
- run tests with coverage: `task dc:test`

# PyCharm
- use a docker-compose interpreter
- mark `src` as sources directory
- run configurations are stored in `.run`
  - there is a `.run/runserver.run.xml` which should be the default

# Taskfile
- `taskfile.yaml` is used for development
- there are included tasks:
  - `dc`: docker-compose commands
    - `dc:up` / `dc:down` — dev environment
    - `dc:test` — run tests with coverage in the test container
    - `dc:prod-up` / `dc:prod-down` — production environment
    - `dc:build`, `dc:logs`, `dc:bash`, `dc:ps`, `dc:restart`
  - `m`: django manage commands (`m:migrate`, `m:makemigrations`, `m:collectstatic`, `m:superuser`)
  - `uv`: uv commands (`uv:lock`, `uv:upgrade`)

# local development of Django packages
- this project also contains an example of how to develop an owned Django package locally
- in this case this is `django-crud-views`
- therefore, the package(s) are added as GIT submodules to `submodules/`
- see Dockerfile for details:
  - `deps-dev` target (it bind-mounts submodules during the dep install step)
  - `dev` target (it copies the submodules metadata to the container)
- the trick to install packages in editable mode is:
  - in `pyproject.toml` the package is added to `[tool.uv.sources]` for development
  - it points to the local path of the package, in this case `submodules/django-crud-views`
  - and is defined as `editable = true`
- Important PyCharm configuration:
  - mark the source folders in `submodules/django-crud-views`
  - in our example these multiple folders:
    - `submodules/django-crud-views/crud_views`
    - `submodules/django-crud-views/crud_views_plain`
    - ...
