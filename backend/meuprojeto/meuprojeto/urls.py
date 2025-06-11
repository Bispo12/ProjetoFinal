from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('Utilizadores.urls')),  # Inclui as URLs da sua app
]