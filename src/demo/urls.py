from django.urls import path

from demo.views.author import cv_author
from demo.views.index import IndexView

urlpatterns = [
    path("", IndexView.as_view(), name="index"),
] + cv_author.urlpatterns
