import django_tables2 as tables

from demo.models import Author
from crud_views.lib.table import Table, UUIDLinkDetailColumn
from crud_views.lib.table.attrs import ColAttr
from crud_views.lib.views import (
    DetailViewPermissionRequired,
    UpdateViewPermissionRequired,
    CreateViewPermissionRequired,
    MessageMixin,
    ListViewTableMixin,
    ListViewPermissionRequired,
    OrderedUpViewPermissionRequired,
    OrderedUpDownPermissionRequired,
    DeleteViewPermissionRequired,
)
from crud_views.lib.viewset import ViewSet

cv_author = ViewSet(model=Author, name="author")


class AuthorTable(Table):
    id = UUIDLinkDetailColumn(attrs=ColAttr.ID)
    first_name = tables.Column(attrs=ColAttr.w30)
    last_name = tables.Column(attrs=ColAttr.w30)


class AuthorListView(ListViewTableMixin, ListViewPermissionRequired):
    cv_viewset = cv_author
    cv_list_actions = ["detail", "update", "delete", "up", "down"]
    table_class = AuthorTable


class AuthorDetailView(DetailViewPermissionRequired):
    cv_viewset = cv_author
    cv_property_display = [
        {
            "title": "Attributes",
            "properties": ["first_name", "last_name"],
        }
    ]


class AuthorCreateView(MessageMixin, CreateViewPermissionRequired):
    fields = ["first_name", "last_name"]
    cv_viewset = cv_author
    cv_message = "Created author »{object}«"


class AuthorUpdateView(MessageMixin, UpdateViewPermissionRequired):
    fields = ["first_name", "last_name"]
    cv_viewset = cv_author
    cv_message = "Updated author »{object}«"


class AuthorDeleteView(MessageMixin, DeleteViewPermissionRequired):
    cv_viewset = cv_author
    cv_message = "Deleted author »{object}«"


class AuthorUpView(MessageMixin, OrderedUpViewPermissionRequired):
    cv_viewset = cv_author
    cv_message = "Moved »{object}« up"


class AuthorDownView(MessageMixin, OrderedUpDownPermissionRequired):
    cv_viewset = cv_author
    cv_message = "Moved »{object}« down"
