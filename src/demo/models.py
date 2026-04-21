import uuid

from django.db import models
from ordered_model.models import OrderedModel


class Author(OrderedModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    first_name = models.CharField(max_length=100)
    last_name = models.CharField(max_length=100)

    class Meta(OrderedModel.Meta):
        pass

    def __str__(self):
        return f"{self.first_name} {self.last_name}"
