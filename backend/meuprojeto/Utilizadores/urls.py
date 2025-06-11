from django.urls import path, re_path
from .views import (
    upload_csv, dados_por_categoria, listar_dispositivos, categorias_por_dispositivo,
    CustomUserList, CustomUserDetail, RegisterAPIView, LoginAPIView,
    PasswordResetRequestView, PasswordResetConfirmView,
    guardar_localizacao, listar_localizacoes,
    criar_alerta, listar_alertas, atualizar_definicoes
)
from rest_framework_simplejwt.views import TokenRefreshView

urlpatterns = [
    # Autenticação
    path('users/', CustomUserList.as_view(), name='user-list'),
    path('users/<int:pk>/', CustomUserDetail.as_view(), name='user-detail'),
    path('register/', RegisterAPIView.as_view(), name='register'),
    path('login/', LoginAPIView.as_view(), name='login'),
    path('refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('password-reset-request/', PasswordResetRequestView.as_view(), name='password_reset_request'),
    path('password-reset-confirm/', PasswordResetConfirmView.as_view(), name='password_reset_confirm'),

    # Localização
    path('guardar-localizacao/', guardar_localizacao, name='guardar-localizacao'),
    path('listar-localizacoes/', listar_localizacoes, name='listar-localizacoes'),

    # Notificações
    path('alertas/criar/', criar_alerta),
    path('alertas/<int:user_id>/', listar_alertas),

    # Definições
    path('settings/', atualizar_definicoes),

    # Dados
    path('upload_csv/', upload_csv, name='upload_csv'),
    re_path(r'^data/(?P<categoria>.+)/$', dados_por_categoria, name='dados_por_categoria'),
    path('dispositivos/', listar_dispositivos, name='listar_dispositivos'),
    path('devices/', listar_dispositivos),  # alias compatível com Flutter
    path('categorias/', categorias_por_dispositivo, name='categorias_por_dispositivo'),
    path('categorias-por-device/', categorias_por_dispositivo),  # alias compatível com Flutter
]
