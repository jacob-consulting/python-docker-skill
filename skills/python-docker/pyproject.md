# pyproject.toml Reference

## Complete Template

```toml
[project]
name = "my-project"
version = "0.1.0"
requires-python = ">=3.12"
# Core runtime dependencies – installed in every image target.
dependencies = [
    # add your core dependencies here
]

# ---------------------------------------------------------------------------
# Dependency groups (PEP 735)
#
# Each group maps to one Dockerfile stage:
#   prod  → deps-prod  (production server)
#   test  → deps-test  (pytest + plugins)
#   dev   → deps-dev   (linters, debugger; includes test group)
# ---------------------------------------------------------------------------

[dependency-groups]

prod = [
    # e.g. "gunicorn>=22.0", or "uvicorn>=0.30"
]

test = [
    "pytest>=8.0",
    "pytest-cov>=5.0",
    "factory-boy>=3.3",
]

dev = [
    { include-group = "test" },   # developers can also run tests
    "ipython>=8.0",
    "ruff>=0.5",
    "mypy>=1.10",
]

# ---------------------------------------------------------------------------
# uv configuration
# ---------------------------------------------------------------------------

[tool.uv]
# Uncomment to use a local checkout as an editable install (see submodules.md):
# [tool.uv.sources]
# my-lib = { path = "./submodules/my-lib", editable = true }

# ---------------------------------------------------------------------------
# pytest
# ---------------------------------------------------------------------------

[tool.pytest.ini_options]
# Restrict discovery to src/ to avoid recursing into submodules/
testpaths = ["src"]

# ---------------------------------------------------------------------------
# ruff
# ---------------------------------------------------------------------------

[tool.ruff]
line-length = 100
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "W", "I", "UP", "B"]
ignore = ["E501"]

# ---------------------------------------------------------------------------
# mypy
# ---------------------------------------------------------------------------

[tool.mypy]
python_version = "3.12"
strict = true
ignore_missing_imports = true
```

---

## Django additions

When adding Django, extend the template as follows:

```toml
[project]
dependencies = [
    "django>=5.0,<6.0",
    "dynaconf>=3.2",
]

[dependency-groups]
prod = [
    # uwsgi is compiled from source in deps-prod (gcc+libpcre3-dev available).
    # Only libpcre3 runtime lib is needed in the final prod image.
    "uwsgi>=2.0",
]

test = [
    "pytest>=8.0",
    "pytest-django>=4.8",
    "pytest-cov>=5.0",
    "factory-boy>=3.3",
]

dev = [
    { include-group = "test" },
    "django-debug-toolbar>=4.3",
    "ipython>=8.0",
    "ruff>=0.5",
    "mypy>=1.10",
    "django-stubs>=5.0",
]

[tool.pytest.ini_options]
DJANGO_SETTINGS_MODULE = "project.settings"
testpaths = ["src"]
pythonpath = ["src"]

[tool.mypy]
plugins = ["mypy_django_plugin.main"]
python_version = "3.12"
strict = true
ignore_missing_imports = true

[tool.django-stubs]
django_settings_module = "project.settings"
```

---

## Key Points

### dev group includes test group
`{ include-group = "test" }` in the dev group means developers get all test tools.
In the `deps-test` stage, `--no-default-groups --group test` installs only the test group (no dev tools).

### Django: uwsgi in prod group only
uwsgi requires gcc to compile. It belongs in the `prod` dependency group, which is installed
in the `deps-prod` stage where gcc and libpcre3-dev are available.
Adding uwsgi to `[project.dependencies]` would cause `deps-dev` and `deps-test` to try to
compile it without gcc — causing build failures.

### testpaths = ["src"]
Prevents pytest from recursing into `submodules/` (which may contain their own test suites)
or `project/` (Django project config — not app code).
