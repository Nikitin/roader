from celery import shared_task
import math
from.models import ProcessedPoint

# Threshold value for acceleration magnitude to detect anomalies.
# This is determined experimentally. Starting with 15.0 m/s^2.
SEVERITY_THRESHOLD = 15.0

@shared_task
def process_data_packet(data_packet):
    """
    Processes a single data packet from the client.
    """
    try:
        acc_x = data_packet.get('user_accelerometer', {}).get('x', 0)
        acc_y = data_packet.get('user_accelerometer', {}).get('y', 0)
        acc_z = data_packet.get('user_accelerometer', {}).get('z', 0)

        # Calculate the magnitude of the acceleration vector
        magnitude = math.sqrt(acc_x**2 + acc_y**2 + acc_z**2)

        # If the magnitude exceeds the threshold, save the point
        if magnitude > SEVERITY_THRESHOLD:
            lat = data_packet.get('gps', {}).get('latitude')
            lon = data_packet.get('gps', {}).get('longitude')

            if lat is not None and lon is not None:
                ProcessedPoint.objects.create(
                    latitude=lat,
                    longitude=lon,
                    severity=magnitude # Use the magnitude itself as the "severity"
                )
                return f"Processed point with magnitude {magnitude}"
        return f"Point with magnitude {magnitude} below threshold"
    except Exception as e:
        # Logging errors is important for debugging
        print(f"Error processing packet: {e}")
        return "Error"