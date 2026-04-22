# syntax=docker/dockerfile:1
# ---------------------------------------------------------------------------
# Multi-stage Django Dockerfile using uv for dependency management.
#
# Build targets
# -------------
#   base       – shared OS + uv binary, never used directly
#   deps-prod  – venv with production deps only (build tools available here)
#   deps-test  – venv with main + test deps
#   deps-dev   – venv with all deps (main + dev + test)
#   prod       – minimal runtime image; non-root user; runs uwsgi
#   test       – test image; runs pytest non-interactively
#   dev        – development image; source bind-mounted by compose
#
# Usage examples
# --------------
#   docker build --target dev  -t myapp:dev  .
#   docker build --target test -t myapp:test .
#   docker build --target prod -t myapp:prod .
# ---------------------------------------------------------------------------

ARG PYTHON_VERSION=3.12
ARG UV_VERSION=0.4.29

# ---------------------------------------------------------------------------
# Stage: uv binary carrier
# Pull the pinned uv binary from its own image so we don't embed curl/wget.
# ---------------------------------------------------------------------------
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv

# ---------------------------------------------------------------------------
# Stage: base
# OS packages, uv binary, shared environment variables, non-root user.
# ---------------------------------------------------------------------------
FROM python:${PYTHON_VERSION}-slim-bookworm AS base

# Copy just the uv (and uvx) binaries from the carrier stage
COPY --from=uv /uv /uvx /usr/local/bin/

# Non-root user – UID/GID are overridable at build time so they can match
# the host developer's UID when bind-mounting source in dev.
ARG APP_USER=app
ARG APP_UID=10001
ARG APP_GID=10001

RUN groupadd --system --gid "${APP_GID}" "${APP_USER}" \
 && useradd  --system --uid "${APP_UID}" --gid "${APP_GID}" \
             --create-home --shell /usr/sbin/nologin "${APP_USER}"

# Paths used across all stages – defined as ARGs so they can be overridden,
# but almost never need to be.
ARG APP_DIR=/opt/project
ARG VIRTUAL_ENV=/opt/venv

# UV_COMPILE_BYTECODE: pre-compile .pyc files at install time (faster startup)
# UV_LINK_MODE=copy:  required when the cache mount is on a different fs
# UV_PYTHON_DOWNLOADS=never: use the container Python, never download one
# UV_PROJECT_ENVIRONMENT: install into a dedicated venv, not site-packages
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never \
    UV_PROJECT_ENVIRONMENT=${VIRTUAL_ENV} \
    VIRTUAL_ENV=${VIRTUAL_ENV} \
    PATH=${VIRTUAL_ENV}/bin:$PATH \
    PYTHONPATH=${APP_DIR}:${APP_DIR}/src \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR ${APP_DIR}

# ---------------------------------------------------------------------------
# Stage: deps-prod
# Compile C extensions (uwsgi needs gcc + libpcre3) then install prod group.
# Build tools are in THIS stage only; they do NOT land in the final prod image.
# ---------------------------------------------------------------------------
FROM base AS deps-prod

RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc libpcre3-dev \
 && rm -rf /var/lib/apt/lists/*

# Bind-mount pyproject.toml and uv.lock so they don't become image layers.
# The uv cache mount speeds up rebuilds when only the application code changes.
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    uv venv "${VIRTUAL_ENV}" \
 && uv sync --locked --no-install-project --no-default-groups --group prod

# ---------------------------------------------------------------------------
# Stage: deps-test
# Install main + test dependency groups (no dev tooling, no prod server).
# ---------------------------------------------------------------------------
FROM base AS deps-test

RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    uv venv "${VIRTUAL_ENV}" \
 && uv sync --locked --no-install-project --no-default-groups --group test

# ---------------------------------------------------------------------------
# Stage: deps-dev
# Install every dependency group so developers can run any tool.
# Submodules are bind-mounted at this stage so editable path deps resolve.
# ---------------------------------------------------------------------------
FROM base AS deps-dev

RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=submodules,target=submodules \
    uv venv "${VIRTUAL_ENV}" \
 && uv sync --locked --no-install-project

# ---------------------------------------------------------------------------
# Stage: prod
# Final production image – minimal, non-root, static files pre-collected.
# ---------------------------------------------------------------------------
FROM base AS prod

# Only the shared C runtime library is needed at runtime; no compiler.
RUN apt-get update \
 && apt-get install -y --no-install-recommends libpcre3 \
 && rm -rf /var/lib/apt/lists/*

# Copy the pre-built venv from deps-prod (no compiler/headers included)
COPY --from=deps-prod ${VIRTUAL_ENV} ${VIRTUAL_ENV}

# Copy application source
COPY . ${APP_DIR}

# collectstatic runs as root so it can write to staticfiles/ before the
# ownership transfer below.  ENV_FOR_DYNACONF selects the production overlay.
RUN ENV_FOR_DYNACONF=production python manage.py collectstatic --no-input

RUN chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}"
USER ${APP_USER}

EXPOSE 8000

# GUNICORN_WORKERS / UWSGI_PROCESSES can be overridden in the compose file
# or via k8s env.  Defaults to 4 which suits most deployments.
CMD ["uwsgi", \
     "--http", "0.0.0.0:8000", \
     "--module", "project.wsgi", \
     "--processes", "4", \
     "--threads", "2", \
     "--static-map", "/static/=/opt/project/staticfiles"]

# ---------------------------------------------------------------------------
# Stage: test
# Copy all source in, run pytest.  Produces a non-zero exit code on failure
# so CI pipelines fail correctly.
# ---------------------------------------------------------------------------
FROM deps-test AS test

COPY . ${APP_DIR}

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-default-groups --group test

RUN chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}"
USER ${APP_USER}

# pytest discovers tests under src/ (configured in pyproject.toml).
# --tb=short keeps CI output readable.
CMD ["pytest", "src/", "-v", "--tb=short", "--cov=src", "--cov-report=term-missing"]

# ---------------------------------------------------------------------------
# Stage: dev
# Source is bind-mounted at runtime – only the project metadata is COPYed so
# the venv installation and project editable install resolve correctly.
# ---------------------------------------------------------------------------
FROM deps-dev AS dev

# Copy only the files needed for `uv sync --locked` to install the project
# package itself (editable).  The real src/ and project/ are mounted by compose.
COPY --parents uv.lock pyproject.toml manage.py submodules ${APP_DIR}/

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked \
 && chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}"

USER ${APP_USER}

EXPOSE 8000

CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
