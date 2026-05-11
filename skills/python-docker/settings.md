# Django + Dynaconf Settings Reference *(optional — Django projects only)*

## File Layout

```
project/
  settings.py                ← DjangoDynaconf hook + validators (no Django settings)
  settings/
    base.yaml                ← shared defaults (committed, no secrets)
    development.yaml
    testing.yaml
    production.yaml
    .secrets.yaml            ← GITIGNORED + DOCKERIGNORED (never committed)
    .secrets.yaml.example    ← template (committed, no real secrets)
```

## settings.py

```python
import os
from pathlib import Path

from dynaconf import DjangoDynaconf, Validator

BASE_DIR = Path(__file__).resolve().parent.parent

_env = os.environ.get("ENV_FOR_DYNACONF", "development").lower()

settings = DjangoDynaconf(
    __name__,
    settings_file=[
        "settings/base.yaml",
        f"settings/{_env}.yaml",
        "settings/.secrets.yaml",
    ],
    envvar_prefix="DJANGO",
    environments=False,
    load_dotenv=True,
)

settings.validators.register(
    Validator("SECRET_KEY", must_exist=True),
    Validator("ALLOWED_HOSTS", must_exist=True, is_type_of=list),
    Validator("DEBUG", must_exist=True, is_type_of=bool),
)
settings.validators.validate()
```

### Critical: SHORT settings_file paths

DjangoDynaconf uses the **calling file's directory** as `root_path`.
Since `settings.py` lives in `project/`, write `"settings/base.yaml"` — not `"project/settings/base.yaml"`.
Using the longer path causes FileNotFoundError silently (dynaconf may ignore missing files).

### `environments=False`

The YAML files are flat — no `[default]` / `[production]` section headers.
`environments=False` tells dynaconf to read the file as a flat key-value store.
Without it, dynaconf expects sectioned TOML-style blocks and silently loads nothing.

### Validators

Register validators after `DjangoDynaconf()` and call `validate()` to fail fast at startup when required settings are missing or have the wrong type.  Common validators:

```python
Validator("SECRET_KEY", must_exist=True)
Validator("ALLOWED_HOSTS", must_exist=True, is_type_of=list)
Validator("DEBUG", must_exist=True, is_type_of=bool)
Validator("DATABASES", must_exist=True, is_type_of=dict)
```

## base.yaml (shared defaults)

All Django settings live here — `settings.py` contains only `BASE_DIR` and the dynaconf hook.
Use uppercase keys to match Django convention.

```yaml
DEBUG: false
SECRET_KEY: "django-insecure-change-me-in-production"
ALLOWED_HOSTS:
  - "localhost"
  - "127.0.0.1"

INSTALLED_APPS:
  - django.contrib.admin
  - django.contrib.auth
  - django.contrib.contenttypes
  - django.contrib.sessions
  - django.contrib.messages
  - django.contrib.staticfiles

MIDDLEWARE:
  - django.middleware.security.SecurityMiddleware
  - django.contrib.sessions.middleware.SessionMiddleware
  - django.middleware.common.CommonMiddleware
  - django.middleware.csrf.CsrfViewMiddleware
  - django.contrib.auth.middleware.AuthenticationMiddleware
  - django.contrib.messages.middleware.MessageMiddleware
  - django.middleware.clickjacking.XFrameOptionsMiddleware

ROOT_URLCONF: project.urls

TEMPLATES:
  - BACKEND: django.template.backends.django.DjangoTemplates
    DIRS:
      - "@format {this.BASE_DIR}/templates"
    APP_DIRS: true
    OPTIONS:
      context_processors:
        - django.template.context_processors.debug
        - django.template.context_processors.request
        - django.contrib.auth.context_processors.auth
        - django.contrib.messages.context_processors.messages

WSGI_APPLICATION: project.wsgi.application

DATABASES:
  default:
    ENGINE: django.db.backends.sqlite3
    NAME: "@format {this.BASE_DIR}/db.sqlite3"

AUTH_PASSWORD_VALIDATORS:
  - NAME: django.contrib.auth.password_validation.UserAttributeSimilarityValidator
  - NAME: django.contrib.auth.password_validation.MinimumLengthValidator
  - NAME: django.contrib.auth.password_validation.CommonPasswordValidator
  - NAME: django.contrib.auth.password_validation.NumericPasswordValidator

LANGUAGE_CODE: en-us
TIME_ZONE: UTC
USE_I18N: true
USE_TZ: true

STATIC_URL: static/
STATIC_ROOT: "@format {this.BASE_DIR}/staticfiles"

DEFAULT_AUTO_FIELD: django.db.models.BigAutoField

EMAIL_BACKEND: django.core.mail.backends.console.EmailBackend

CACHES:
  default:
    BACKEND: django.core.cache.backends.locmem.LocMemCache
```

## development.yaml

```yaml
DEBUG: true
SECRET_KEY: "django-insecure-dev-only-do-not-use-in-production"
ALLOWED_HOSTS:
  - "*"
LOGGING:
  version: 1
  disable_existing_loggers: false
  handlers:
    console:
      class: "logging.StreamHandler"
  root:
    handlers: ["console"]
    level: "DEBUG"
  loggers:
    django.db.backends:
      handlers: ["console"]
      level: "DEBUG"
      propagate: false
```

## testing.yaml

```yaml
DEBUG: false
SECRET_KEY: "django-insecure-test-fixed-key-do-not-use-elsewhere"
ALLOWED_HOSTS:
  - "localhost"
  - "127.0.0.1"
  - "testserver"
DATABASES:
  default:
    ENGINE: "django.db.backends.sqlite3"
    NAME: ":memory:"
CACHES:
  default:
    BACKEND: "django.core.cache.backends.dummy.DummyCache"
EMAIL_BACKEND: "django.core.mail.backends.locmem.EmailBackend"
PASSWORD_HASHERS:
  - "django.contrib.auth.hashers.MD5PasswordHasher"
```

## production.yaml

```yaml
DEBUG: false
ALLOWED_HOSTS:
  - "your-domain.com"
  - "www.your-domain.com"
SECURE_SSL_REDIRECT: true
SECURE_HSTS_SECONDS: 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS: true
SECURE_HSTS_PRELOAD: true
SESSION_COOKIE_SECURE: true
CSRF_COOKIE_SECURE: true
SECURE_PROXY_SSL_HEADER:
  - "HTTP_X_FORWARDED_PROTO"
  - "https"
```

## .secrets.yaml (gitignored)

```yaml
SECRET_KEY: "actual-long-random-hex-token-here"
```

Generate a key: `python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"`

## .secrets.yaml.example (committed)

```yaml
# Copy this file to .secrets.yaml and fill in real values.
# .secrets.yaml is git-ignored and docker-ignored — never commit it.
SECRET_KEY: "replace-with-output-of: python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())'"
```

## .dockerignore entry (required)

```
project/settings/.secrets.yaml
```

Without this entry, `COPY . ${APP_DIR}` in the prod and test stages bakes the secrets file
into the image layer, where it can be read by anyone with image access.

## .gitignore entry (required)

```
project/settings/.secrets.yaml
```

## Testing dynaconf settings

```python
from django.conf import settings

def test_allowed_hosts_does_not_contain_wildcard_in_testing():
    assert "*" not in settings.ALLOWED_HOSTS

def test_debug_is_false_in_testing():
    assert settings.DEBUG is False

def test_secret_key_is_not_placeholder():
    assert settings.SECRET_KEY != "django-insecure-change-me-in-production"
```

Note: `pytest-django` unconditionally forces `DEBUG=False`, so testing DEBUG is a vacuous assertion.
`ALLOWED_HOSTS` is the meaningful signal that dynaconf loaded the testing overlay.

## Environment variable overrides

Any setting in the YAML files can be overridden at runtime with a `DJANGO_`-prefixed env var:

```bash
DJANGO_SECRET_KEY=abc123 docker compose up
DJANGO_ALLOWED_HOSTS=mysite.com docker compose up
DJANGO_DEBUG=true docker compose up
```

Keys are case-insensitive in dynaconf; `DJANGO_SECRET_KEY` sets `SECRET_KEY`.
