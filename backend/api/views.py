from django.shortcuts import render
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from.tasks import process_data_packet
from.models import ProcessedPoint
from django.views.generic import TemplateView

class IngestDataView(APIView):
    """
    Taking data-packages from Mobile (Flutter, natively) and sending them to Celery for processing.
    """
    def post(self, request, *args, **kwargs):
        data_packets = request.data
        if not isinstance(data_packets, list):
            return Response({"error": "Expected a list of data packets"}, status=status.HTTP_400_BAD_REQUEST)

        for packet in data_packets:
            # Sending each packet to Celery for processing
            process_data_packet.delay(packet)

        # Response immediately after sending packets to Celery
        return Response({"status": "packets accepted"}, status=status.HTTP_202_ACCEPTED)

class HeatmapDataView(APIView):
    """
    Provides data for the heatmap.
    Format: [[lat, lon, severity],...]
    """
    def get(self, request, *args, **kwargs):
        points = ProcessedPoint.objects.all().values_list('latitude', 'longitude', 'severity')
        return Response(list(points))

class MapView(TemplateView):
    """
    Displays an HTML page with the map.
    """
    template_name = "map.html"
