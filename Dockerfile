ARG PYTHON_VERSION=3.14
ARG UV_VERSION=0.11.7

FROM ghcr.io/astral-sh/uv:$UV_VERSION AS uv

FROM python:$PYTHON_VERSION-slim-bookworm

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
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=submodules,target=submodules \
    uv venv "$VIRTUAL_ENV" && \
    uv sync --locked --no-install-project --no-dev

COPY . $APP_DIR

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev && \
    chown -R "${APP_USER}:${APP_USER}" $APP_DIR

# switch to app user
USER ${APP_USER}
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
