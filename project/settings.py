"""
Django settings for the project.

Dynaconf is used for environment-aware configuration.  The resolution order is:

  1. settings.yaml              – safe defaults shared across all environments
  2. settings.<ENV>.yaml        – environment-specific overrides
                                  (development | testing | production)
  3. .secrets.yaml              – secrets that must NOT be committed to VCS
  4. Environment variables      – DJANGO_* prefix overrides everything

The active environment is selected via the ENV_FOR_DYNACONF environment
variable (set in docker-compose.yml / docker-compose.test.yml / etc.).

Example:
    ENV_FOR_DYNACONF=production DJANGO_SECRET_KEY=... python manage.py ...
"""

import os
from pathlib import Path

from dynaconf import DjangoDynaconf  # noqa: F401 – imported for side effects

BASE_DIR = Path(__file__).resolve().parent.parent

# ---------------------------------------------------------------------------
# Security
# These values are placeholders; dynaconf overwrites them from YAML / env.
# ---------------------------------------------------------------------------

# SECRET_KEY must be overridden in production (settings.production.yaml or
# the DJANGO_SECRET_KEY environment variable).
SECRET_KEY = "django-insecure-placeholder-overridden-by-dynaconf"

# Never True in production – overridden by settings.development.yaml.
DEBUG = False

# Restrict to localhost by default; each environment overlay adds its own hosts.
ALLOWED_HOSTS: list[str] = ["localhost", "127.0.0.1"]

# ---------------------------------------------------------------------------
# Application definition
# ---------------------------------------------------------------------------

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "project.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "project.wsgi.application"

# ---------------------------------------------------------------------------
# Database
# Default is SQLite for simplicity; override DATABASE_URL in production.
# ---------------------------------------------------------------------------

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",
    }
}

# ---------------------------------------------------------------------------
# Password validation
# ---------------------------------------------------------------------------

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# ---------------------------------------------------------------------------
# Internationalisation
# ---------------------------------------------------------------------------

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

# ---------------------------------------------------------------------------
# Static files
# ---------------------------------------------------------------------------

STATIC_URL = "static/"
# collectstatic writes files here; must be served by uwsgi / nginx in prod.
STATIC_ROOT = BASE_DIR / "staticfiles"

# ---------------------------------------------------------------------------
# Miscellaneous
# ---------------------------------------------------------------------------

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

LOGIN_URL = "/accounts/login/"
LOGIN_REDIRECT_URL = "/"
LOGOUT_REDIRECT_URL = "/"

# ---------------------------------------------------------------------------
# Dynaconf hook
#
# This call MUST come last.  It mutates this module's globals in-place,
# overriding any setting whose name matches a key found in the YAML files or
# in DJANGO_* environment variables.
#
# environments=False disables dynaconf's legacy [envs] block syntax; we use
#   separate YAML files per environment instead (settings.<env>.yaml).
# load_dotenv=False prevents dynaconf from auto-loading a .env file; manage
#   env vars explicitly via docker-compose or the host shell.
# ---------------------------------------------------------------------------

_env = os.environ.get("ENV_FOR_DYNACONF", "development").lower()

DjangoDynaconf(
    django_settings_module=__name__,
    settings_files=[
        # 1. Shared defaults
        "settings.yaml",
        # 2. Environment-specific overrides
        f"settings.{_env}.yaml",
        # 3. Local secrets (must be in .gitignore)
        ".secrets.yaml",
    ],
    envvar_prefix="DJANGO",
    environments=False,
    load_dotenv=False,
)
