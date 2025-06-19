from django.db import models

class ProcessedPoint(models.Model):
    """
    Model for storing a processed point with geolocation and severity assessment.
    """
    timestamp = models.DateTimeField(auto_now_add=True, db_index=True)
    latitude = models.FloatField()
    longitude = models.FloatField()
    # normalised severity of the vibration in 0 - 100 range.
    severity = models.FloatField()

    def __str__(self):
        return f"Point at ({self.latitude}, {self.longitude}) with severity {self.severity}"
