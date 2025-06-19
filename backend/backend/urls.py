from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('roader/admin/', admin.site.urls),
    path('roader/api/', include('api.urls')),
]