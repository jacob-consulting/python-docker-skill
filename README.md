# Django-Project-Skill

This project is the blueprint for a Django/Docker project skill for claude-code and other tools.

# Core principles

## UV

- the project is based on UV
- the uv image is not used as base-image. TODO: is this a good idea?
  - uv can be installed via COPY from the original uv image
  - or uv it can be installed as binary 


## pyproject.toml


## Dockerfile

- a project user and group are created

- apps are located at 

https://www.reddit.com/r/Python/comments/1o3p4bf/best_practices_for_using_python_uv_inside_docker/