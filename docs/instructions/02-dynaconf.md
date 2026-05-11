# Django + Dynaconf: Multiple Environments with YAML

The current implementation is suboptimal because:
- it mixes python settings with YAML files
- no clean separation of python and YAML files

According to that
- /superpowers:using-superpowers refactor the example project
  - as described later in this document
  - migrate settings from settings.py to YAML files
- /superpowers:writing-skills update the skill in this project skills/python-docker
  - always use YAML for settings
  - encourage the use of validator

## Project Structure

```
myproject/
├── project/
│   ├── settings/
│   │   ├── base.yaml
│   │   ├── development.yaml
│   │   ├── testing.yaml
│   │   ├── staging.yaml
│   │   ├── production.yaml
│   │   ├── .secrets.yaml        # git-ignored
│   │   └── .secrets.yaml.example
│   └── settings.py
├── manage.py
└── myapp/
```

---

## Installation

```bash
pip install dynaconf[yaml]
```

---

## YAML Configuration Files

### `base.yaml` — Shared Defaults

```yaml
DEBUG: false
ALLOWED_HOSTS: []
INSTALLED_APPS:
  - django.contrib.admin
  - django.contrib.auth
  - django.contrib.contenttypes
  - django.contrib.sessions
  - django.contrib.messages
  - django.contrib.staticfiles
DATABASES:
  default:
    ENGINE: django.db.backends.sqlite3
    NAME: db.sqlite3
STATIC_URL: /static/
LANGUAGE_CODE: en-us
TIME_ZONE: UTC
```

### `development.yaml`

```yaml
DEBUG: true
ALLOWED_HOSTS:
  - localhost
  - 127.0.0.1
EMAIL_BACKEND: django.core.mail.backends.console.EmailBackend
```

### `testing.yaml`

```yaml
DEBUG: true
DATABASES:
  default:
    ENGINE: django.db.backends.sqlite3
    NAME: ":memory:"
PASSWORD_HASHERS:
  - django.contrib.auth.hashers.MD5PasswordHasher
```

### `staging.yaml`

```yaml
DEBUG: false
ALLOWED_HOSTS:
  - staging.myapp.com
```

### `production.yaml`

```yaml
DEBUG: false
ALLOWED_HOSTS:
  - myapp.com
  - www.myapp.com
SECURE_SSL_REDIRECT: true
SESSION_COOKIE_SECURE: true
CSRF_COOKIE_SECURE: true
```

### `.secrets.yaml` — Never Commit This

```yaml
SECRET_KEY: "@format {env[SECRET_KEY]}"
DATABASE_URL: "@format {env[DATABASE_URL]}"
```

Add to `.gitignore`:

```
.secrets.yaml
```

Commit `.secrets.yaml.example` with placeholder values for onboarding:

```yaml
SECRET_KEY: "changeme"
DATABASE_URL: "postgres://user:pass@localhost/mydb"
```

---

## `settings.py` — Entry Point

```python
import os
from dynaconf import DjangoDynaconf, Validator

environment = os.environ.get("ENV_FOR_DYNACONF", "development")

settings = DjangoDynaconf(
    __name__,
    envvar_prefix="DJANGO",
    settings_file=[
        "project/settings/base.yaml",
        f"project/settings/{environment}.yaml",  # only load active env
    ],
    secrets="project/settings/.secrets.yaml",
    environments=False,  # no environment sections in files — files ARE the environment
    load_dotenv=True,
)

settings.validators.register(
    Validator("SECRET_KEY", must_exist=True),
    Validator("ALLOWED_HOSTS", must_exist=True, is_type_of=list),
    Validator("DATABASE_URL", must_exist=True),
)

settings.validators.validate_all()
```

---

## `.env` for Local Development

```bash
ENV_FOR_DYNACONF=development
SECRET_KEY=my-local-secret-key
DATABASE_URL=postgres://user:pass@localhost/devdb
```

---

## Switching Environments

```bash
# Local development
export ENV_FOR_DYNACONF=development
python manage.py runserver

# Run tests
ENV_FOR_DYNACONF=testing python manage.py test

# Docker Compose
environment:
  - ENV_FOR_DYNACONF=staging
  - SECRET_KEY=...
  - DATABASE_URL=...
```

---

## How It Works

| Concept | Detail |
|---|---|
| `environments=False` | Files are read as flat key-value YAML — no `default:` wrapper needed |
| File order matters | `base.yaml` loads first; the environment file merges on top, overriding only what it defines |
| The filename is the environment | No `[development]` / `[production]` sections — the file itself is the selector |
| Secrets via env vars | Use `@format {env[VAR]}` in `.secrets.yaml` to pull from the host environment |
| `Validator` | Fails fast at startup if required settings are missing or invalid |
| `envvar_prefix` | Override any setting at runtime: `DJANGO_DEBUG=true` |