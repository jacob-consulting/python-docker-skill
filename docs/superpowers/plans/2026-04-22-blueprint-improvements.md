# Blueprint Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add production docker-compose with uwsgi + collectstatic, a test docker-compose, pytest tests for the demo app, and taskfile tasks for all of the above.

**Architecture:** The prod Dockerfile target gains a `collectstatic` build step and a uwsgi CMD; a new `docker-compose.prod.yml` targets it with SQLite mounted. A separate `docker-compose.test.yml` targets the existing `test` Dockerfile stage. Two pytest tests cover the Author model and the author list view. All compose operations are exposed via tasks in `tasks/docker_compose.yaml`.

**Tech Stack:** Django 5.x, uv, pytest-django, uwsgi, Docker multi-stage builds, Taskfile v3

---

## File Map

| Action | Path | Responsibility |
|--------|------|---------------|
| Modify | `pyproject.toml` | add `uwsgi` prod dep, add `[tool.pytest.ini_options]` |
| Modify | `project/settings.py` | add `STATIC_ROOT` |
| Modify | `Dockerfile` | prod stage: run collectstatic, change CMD to uwsgi |
| Create | `docker-compose.prod.yml` | production compose targeting `prod` stage |
| Create | `docker-compose.test.yml` | test compose targeting `test` stage |
| Modify | `tasks/docker_compose.yaml` | add `test`, `prod-up`, `prod-down` tasks |
| Create | `src/demo/tests/__init__.py` | empty package marker |
| Create | `src/demo/tests/test_author.py` | model test + view test |

---

### Task 1: Add pytest configuration

**Files:**
- Modify: `pyproject.toml`

- [ ] **Step 1: Add pytest config block to `pyproject.toml`**

Append to `pyproject.toml` (after the existing `[tool.uv.sources]` block):

```toml
[tool.pytest.ini_options]
DJANGO_SETTINGS_MODULE = "project.settings"
pythonpath = ["src"]
```

- [ ] **Step 2: Commit**

```bash
git add pyproject.toml
git commit -m "chore: add pytest configuration"
```

---

### Task 2: Write demo tests

**Files:**
- Create: `src/demo/tests/__init__.py`
- Create: `src/demo/tests/test_author.py`

- [ ] **Step 1: Create the tests package**

Create `src/demo/tests/__init__.py` as an empty file.

- [ ] **Step 2: Write the two tests**

Create `src/demo/tests/test_author.py`:

```python
import pytest
from django.contrib.auth.models import User
from django.urls import reverse

from demo.models import Author


@pytest.mark.django_db
def test_author_str():
    author = Author(first_name="Jane", last_name="Doe")
    assert str(author) == "Jane Doe"


@pytest.mark.django_db
def test_author_list_view(client):
    user = User.objects.create_user(username="tester", password="secret")
    client.force_login(user)
    response = client.get(reverse("author-list"))
    assert response.status_code == 200
```

- [ ] **Step 3: Run tests inside the dev container to verify they pass**

```bash
docker compose run --rm app pytest src/demo/tests/ -v
```

Expected output:
```
PASSED src/demo/tests/test_author.py::test_author_str
PASSED src/demo/tests/test_author.py::test_author_list_view
2 passed
```

- [ ] **Step 4: Commit**

```bash
git add src/demo/tests/
git commit -m "test: add Author model and list view tests"
```

---

### Task 3: Add uwsgi and STATIC_ROOT

**Files:**
- Modify: `pyproject.toml`
- Modify: `project/settings.py`

- [ ] **Step 1: Add `uwsgi` to prod dependencies in `pyproject.toml`**

Change the `[project]` dependencies block:

```toml
dependencies = [
    "django<=6.0",
    "django-crud-views",
    "django-ordered-model",
    "uwsgi",
]
```

- [ ] **Step 2: Lock the new dependency**

```bash
uv lock
```

- [ ] **Step 3: Add `STATIC_ROOT` to `project/settings.py`**

After the existing `STATIC_URL = "static/"` line, add:

```python
STATIC_ROOT = BASE_DIR / "staticfiles"
```

- [ ] **Step 4: Commit**

```bash
git add pyproject.toml uv.lock project/settings.py
git commit -m "feat: add uwsgi dependency and STATIC_ROOT setting"
```

---

### Task 4: Update Dockerfile prod target

**Files:**
- Modify: `Dockerfile`

The current prod stage ends with:
```dockerfile
FROM deps-prod AS prod

COPY . $APP_DIR
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev && \
    chown -R "${APP_USER}:${APP_USER}" $APP_DIR
USER ${APP_USER}
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
```

- [ ] **Step 1: Replace the prod stage CMD and add collectstatic**

Replace the prod stage with:

```dockerfile
FROM deps-prod AS prod

COPY . $APP_DIR
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev && \
    chown -R "${APP_USER}:${APP_USER}" $APP_DIR
USER ${APP_USER}
RUN python manage.py collectstatic --no-input
CMD ["uwsgi", "--http", "0.0.0.0:8000", "--module", "project.wsgi", "--static-map", "/static/=/opt/project/staticfiles"]
```

- [ ] **Step 2: Build the prod target to verify it succeeds**

```bash
docker build --target prod -t blueprint-prod .
```

Expected: build completes, collectstatic output visible in the layer, no errors.

- [ ] **Step 3: Commit**

```bash
git add Dockerfile
git commit -m "feat: prod target runs collectstatic and serves with uwsgi"
```

---

### Task 5: Add docker-compose.prod.yml

**Files:**
- Create: `docker-compose.prod.yml`

- [ ] **Step 1: Create `docker-compose.prod.yml`**

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

- [ ] **Step 2: Commit**

```bash
git add docker-compose.prod.yml
git commit -m "feat: add production docker-compose"
```

---

### Task 6: Add docker-compose.test.yml

**Files:**
- Create: `docker-compose.test.yml`

- [ ] **Step 1: Create `docker-compose.test.yml`**

```yaml
services:

  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: test
    command: pytest --cov=src --cov-report=term-missing -q
```

- [ ] **Step 2: Build and run to verify tests pass**

```bash
docker compose -f docker-compose.test.yml run --rm app
```

Expected output:
```
2 passed
```
Coverage table printed to terminal.

- [ ] **Step 3: Commit**

```bash
git add docker-compose.test.yml
git commit -m "feat: add test docker-compose with coverage"
```

---

### Task 7: Add Taskfile tasks

**Files:**
- Modify: `tasks/docker_compose.yaml`

- [ ] **Step 1: Append three tasks to `tasks/docker_compose.yaml`**

Add after the existing `ps` task:

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

- [ ] **Step 2: Verify tasks are listed**

```bash
task dc:test --dry
task dc:prod-up --dry
task dc:prod-down --dry
```

Expected: each command prints the docker compose command it would run, no errors.

- [ ] **Step 3: Commit**

```bash
git add tasks/docker_compose.yaml
git commit -m "chore: add test, prod-up, prod-down taskfile tasks"
```
