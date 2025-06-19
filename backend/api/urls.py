from django.urls import path
from.views import IngestDataView, HeatmapDataView, MapView

urlpatterns = [
    path('ingest/', IngestDataView.as_view(), name='ingest_data'),
    path('heatmap/', HeatmapDataView.as_view(), name='heatmap_data'),
    path('map/', MapView.as_view(), name='map_view'),
]