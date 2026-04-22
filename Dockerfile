ARG PYTHON_VERSION=3.14
ARG UV_VERSION=0.11.7

FROM ghcr.io/astral-sh/uv:$UV_VERSION AS uv

FROM python:$PYTHON_VERSION-slim-bookworm AS base

# add uv binary
COPY --from=uv /uv /uvx /bin/

# non-root user, ids overridable at build time
ARG APP_USER=app
ARG APP_UID=10001
ARG APP_GID=10001

RUN groupadd --system --gid "${APP_GID}" "${APP_USER}" \
 && useradd  --system --uid "${APP_UID}" --gid "${APP_GID}" \
             --create-home --shell /usr/sbin/nologin "${APP_USER}"

ARG APP_DIR=/opt/project
ARG VIRTUAL_ENV=/opt/venv

# uv behaviour we want in images
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never \
    UV_PROJECT_ENVIRONMENT=$VIRTUAL_ENV \
    VIRTUAL_ENV=$VIRTUAL_ENV \
    PATH=$VIRTUAL_ENV/bin:$PATH \
    PYTHONPATH=$APP_DIR/src

WORKDIR $APP_DIR

# Install deps as root (simple cache mount), then hand $APP_DIR to the app user.
# Splitting lockfile install from project install keeps the dep layer cached.

#
# deps-prod: compile uwsgi and install prod deps (build tools present here, not in prod)
#
FROM base AS deps-prod

RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc \
        libpcre3-dev \
    && rm -rf /var/lib/apt/lists/*

RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    uv venv "$VIRTUAL_ENV" && \
    uv sync --locked --no-install-project --no-dev

#
# deps-test: runtime + test group
#
FROM base AS deps-test

RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    uv venv "$VIRTUAL_ENV" && \
    uv sync --locked --no-install-project --no-default-groups --group test

#
# deps-dev: everything (dev + test)
#
FROM base AS deps-dev

RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=submodules,target=submodules \
    uv venv "$VIRTUAL_ENV" && \
    uv sync --locked --no-install-project

#
# prod: final production image
#
FROM base AS prod

RUN apt-get update && apt-get install -y --no-install-recommends \
        libpcre3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=deps-prod $VIRTUAL_ENV $VIRTUAL_ENV

COPY . $APP_DIR
RUN chown -R "${APP_USER}:${APP_USER}" $APP_DIR
USER ${APP_USER}
RUN python manage.py collectstatic --no-input
CMD ["uwsgi", "--http", "0.0.0.0:8000", "--module", "project.wsgi", "--static-map", "/static/=/opt/project/staticfiles"]

#
# test: prod + test deps + source, runs pytest
#
FROM deps-test AS test

COPY . $APP_DIR
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-default-groups --group test
RUN chown -R "${APP_USER}:${APP_USER}" $APP_DIR
USER ${APP_USER}
CMD ["pytest", "-q"]

#
# dev: everything, source mounted at runtime
#
FROM deps-dev AS dev
# Note: no COPY of src and project here — source is bind-mounted by compose.
# We still need the project installed into the venv so imports work.
# Copy just the metadata, install the project, then compose mounts real $APP_DIR over it.
COPY --parents \
     uv.lock pyproject.toml \
     manage.py \
     submodules \
     $APP_DIR/
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked && \
    chown -R "${APP_USER}:${APP_USER}" $APP_DIR
USER ${APP_USER}
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
