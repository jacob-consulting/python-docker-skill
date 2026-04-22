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
- because we use the Python base image we don'T need to use `uv run xyz.py`
- we can just use `python xyz.py` instead

# Docker

- this blueprint is for Docker projects
- don't rely on Astral's UV base images because of update delay in case of security findings
- Use slim python images instead
- use a cache mount for dependencies
- use targets for: 
  - development: dev and test libs
  - testing: test libs
  - production: only production libs
- keep layers as small as possible
- add an app user and group
- args can define user and group

# Docker Compose

## local development
- use system's uid/gid as args so mounted folders don't have files by weird container user
- mount:
  - `src`
  - `project`
  - `db.sqlite3` if using sqlite

## production
- use `uwsgi` if not async
- it is battle proven and it can serve static files
- use a separate `docker-compose` for production

# PyCharm
- use a docker-compose interpreter
- mark `src` as sources directory
- run configurations are stored in `.run`
  - there is a `.run/runserver.run.xml` which should be the default

# Taskfile
- `taskfile.dev` is used for development
- there are include tasks:
  - dc: docker-compose commands
  - m: django manage commands
  - uv: uv commands

# local development of Django packages
- this project also contains an example of how to develop an owned Django package locally
- in this case this is `django-crud-views`
- therefore, the package(s) are added as GIT submodules to `submodules/`
- see Dockerfile for details:
  - `dev` target (it copies also the submodules to the container)
- the trick to install packages in editable mode is:
  - in `pyproject.toml` the package is added to `[tool.uv.sources]` for development
  - it points to the local path of the package, in this case `submodules/django-crud-views`
  - and is defined as `editable = true `
- Important PyCharm configuration:
  - mark the source folders in `submodules/django-crud-views`
  - in our example these multiple folders:
    - `submodules/django-crud-views/crud_views`
    - `submodules/django-crud-views/crud_views_plain`
    - ...
  