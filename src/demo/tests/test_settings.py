from django.conf import settings


def test_allowed_hosts_does_not_contain_wildcard_in_testing():
    # pytest-django does not override ALLOWED_HOSTS — genuine signal that
    # settings.testing.yaml was loaded by dynaconf (which removes the "*" wildcard).
    assert "*" not in settings.ALLOWED_HOSTS


def test_debug_is_false_in_testing():
    assert settings.DEBUG is False


def test_secret_key_is_not_original_placeholder():
    assert settings.SECRET_KEY != "django-insecure-placeholder-replaced-by-dynaconf"
