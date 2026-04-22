import pytest
from django.contrib.auth.models import Permission, User
from django.urls import reverse

from demo.models import Author


def test_author_str():
    author = Author(first_name="Jane", last_name="Doe")
    assert str(author) == "Jane Doe"


@pytest.mark.django_db
def test_author_list_view(client):
    user = User.objects.create_user(username="tester", password="secret")
    perm = Permission.objects.get(codename="view_author")
    user.user_permissions.add(perm)
    client.force_login(user)
    response = client.get(reverse("author-list"))
    assert response.status_code == 200
