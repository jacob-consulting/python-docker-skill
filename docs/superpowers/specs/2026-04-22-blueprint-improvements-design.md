# Blueprint Improvements Design

**Date:** 2026-04-22
**Scope:** Improve the Django/Docker blueprint with production compose, test compose, pytest tests, and coverage task.

---

## 1. Dockerfile — prod target changes

**Goal:** bake static files into the production image at build time so uwsgi can serve them with `--static-map`.

Changes:
- Add `uwsgi` to prod dependencies in `pyproject.toml`
- Add `STATIC_ROOT = BASE_DIR / "staticfiles"` to `project/settings.py`
- In the `prod` Dockerfile stage, after `chown`, switch to the app user and run `collectstatic`:
  ```dockerfile
  USER ${APP_USER}
  RUN python manage.py collectstatic --no-input
  CMD ["uwsgi", "--http", "0.0.0.0:8000", "--module", "project.wsgi", \
       "--static-map", "/static/=/opt/project/staticfiles"]
  ```

The `DJANGO_SETTINGS_MODULE` is already resolvable because `PYTHONPATH=$APP_DIR/src` is set in the `base` stage env.

---

## 2. docker-compose.prod.yml

A new file for production use alongside the existing dev `docker-compose.yml`.

```yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: prod
    ports:
      - "8000:8000"
    volumes:
      - ./db.sqlite3:/opt/project/db.sqlite3
```

- No UID/GID build args — the prod image uses the baked-in `app` user (UID 10001).
- Static files live inside the image; no volume needed.
- SQLite file is mounted so data persists across container restarts.

---

## 3. docker-compose.test.yml

A new file that builds the `test` Dockerfile target and runs pytest with coverage.

```yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: test
    command: pytest --cov=src --cov-report=term-missing -q
```

- No volumes — source is copied into the image at build time (existing `test` stage).
- Isolated from the dev environment.

---

## 4. Taskfile — test and production tasks

`tasks/docker_compose.yaml` gets three additional tasks:

```yaml
  test:
    desc: Run tests with coverage inside the test container
    cmd: docker compose -f docker-compose.test.yml run --rm app

  prod-up:
    desc: Start the application in production mode (detached)
    cmd: docker compose -f docker-compose.prod.yml up -d --remove-orphans

  prod-down:
    desc: Stop and remove production containers
    cmd: docker compose -f docker-compose.prod.yml down --volumes --remove-orphans
```

No new task file or `taskfile.yaml` include needed.

---

## 5. pytest configuration

Added to `pyproject.toml`:

```toml
[tool.pytest.ini_options]
DJANGO_SETTINGS_MODULE = "project.settings"
pythonpath = ["src"]
```

---

## 6. Demo tests

New file: `src/demo/tests/test_author.py`

Two tests:

1. **Model test** — creates an `Author` and asserts `str()` returns `"First Last"`.
2. **View test** — logs in with `client.force_login()`, then GETs the author list URL and asserts HTTP 200. Uses `pytest-django`'s built-in `client` fixture and `@pytest.mark.django_db`. Force-login avoids test fragility around auth configuration.

`src/demo/tests/__init__.py` is created (empty) to make it a package.

---

## Out of scope

- No nginx service — uwsgi serves static files directly via `--static-map`.
- No PostgreSQL — SQLite is sufficient for the blueprint.
- No CI/CD configuration — left for a follow-up.
- Completing `src/demo/views/author.py` — deferred (not part of this change set).
