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
