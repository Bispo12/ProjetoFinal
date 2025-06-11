import os, csv, json, logging, requests
from datetime import datetime
from django.conf import settings
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.core.mail import send_mail
from django.core.files.storage import default_storage
from django.contrib.auth import get_user_model, authenticate
from django.contrib.auth.tokens import default_token_generator
from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import SensorData, Alerta, Localizacao, Profile
from .serializers import (
    UserSerializer, RegisterSerializer, LoginSerializer,
    PasswordResetRequestSerializer, PasswordResetConfirmSerializer
)

logger = logging.getLogger(__name__)
DATA_FOLDER = getattr(settings, 'CSV_DATA_FOLDER', 'Data')

# === AUTENTICAÇÃO ===

class CustomUserList(generics.ListCreateAPIView):
    queryset = get_user_model().objects.all()
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]

class CustomUserDetail(generics.RetrieveUpdateDestroyAPIView):
    queryset = get_user_model().objects.all()
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]

    def perform_destroy(self, instance):
        instance.is_active = False
        instance.save()
        return Response({"message": "User deactivated successfully."}, status=200)

class RegisterAPIView(generics.CreateAPIView):
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]

    def perform_create(self, serializer):
        user = serializer.save()
        return Response({
            "user": UserSerializer(user, context=self.get_serializer_context()).data,
            "message": "User created. Do login now."
        }, status=201)

class LoginAPIView(generics.GenericAPIView):
    serializer_class = LoginSerializer
    permission_classes = [AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        if serializer.is_valid():
            return Response(serializer.validated_data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class PasswordResetRequestView(generics.GenericAPIView):
    serializer_class = PasswordResetRequestSerializer
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        if serializer.is_valid():
            email = serializer.validated_data['email']
            try:
                user = get_user_model().objects.get(email=email)
                token = default_token_generator.make_token(user)
                reset_link = f"{settings.FRONTEND_URL}/reset-password/{token}/"
                send_mail(
                    'Password Reset Request',
                    f'Reset password: {reset_link}',
                    settings.DEFAULT_FROM_EMAIL,
                    [email]
                )
                return Response({"detail": "Password reset email sent."}, status=200)
            except get_user_model().DoesNotExist:
                return Response({"detail": "No user with this email."}, status=404)
        return Response(serializer.errors, status=400)

class PasswordResetConfirmView(generics.GenericAPIView):
    serializer_class = PasswordResetConfirmSerializer
    permission_classes = [AllowAny]

    def post(self, request):
        token = request.data.get('token')
        email = request.data.get('email')
        new_password = request.data.get('new_password')

        if len(new_password) < 8:
            return Response({"detail": "Password must be at least 8 characters."}, status=400)

        try:
            user = get_user_model().objects.get(email=email)
            if default_token_generator.check_token(user, token):
                user.set_password(new_password)
                user.save()
                return Response({"detail": "Password reset successfully."}, status=200)
            return Response({"detail": "Invalid or expired token."}, status=400)
        except get_user_model().DoesNotExist:
            return Response({"detail": "User does not exist."}, status=400)

# === LOCALIZAÇÃO ===

@api_view(['POST'])
def guardar_localizacao(request):
    try:
        lat = request.data.get('lat')
        lng = request.data.get('lng')
        descricao = request.data.get('descricao', '')

        if lat is None or lng is None:
            return Response({'erro': 'Parâmetros lat e lng são obrigatórios.'}, status=400)

        Localizacao.objects.create(lat=lat, lng=lng, descricao=descricao)
        return Response({'mensagem': 'Localização guardada com sucesso!'})
    except Exception as e:
        return Response({'erro': str(e)}, status=500)

@api_view(['GET'])
@permission_classes([AllowAny])
def listar_localizacoes(request):
    localizacoes = Localizacao.objects.only('lat', 'lng', 'descricao')
    dados = list(localizacoes.values('lat', 'lng', 'descricao'))
    return Response(dados)

# === ALERTAS ===

@csrf_exempt
def criar_alerta(request):
    if request.method == 'POST':
        data = json.loads(request.body)
        alerta = Alerta.objects.create(
            user_id=data['user_id'],
            parametro=data['parametro'],
            valor=data['valor'],
            direcao=data['direcao'],
            ativo=True
        )
        return JsonResponse({'status': 'ok', 'alerta_id': alerta.id})

def listar_alertas(request, user_id):
    alertas = Alerta.objects.filter(user_id=user_id, ativo=True).values()
    return JsonResponse(list(alertas), safe=False)

def enviar_push(token, titulo, corpo):
    if not token:
        return
    headers = {
        'Authorization': 'Bearer SEU_TOKEN_DO_SERVIDOR_FCM',
        'Content-Type': 'application/json',
    }
    payload = {
        'to': token,
        'notification': {
            'title': titulo,
            'body': corpo,
        }
    }
    try:
        requests.post('https://fcm.googleapis.com/fcm/send', headers=headers, json=payload)
    except Exception as e:
        logger.error(f"Erro ao enviar push: {e}")

def verificar_alertas_para_user(user_id, categoria, valor_atual, token_fcm):
    alertas = Alerta.objects.filter(user_id=user_id, parametro=categoria, ativo=True)
    for alerta in alertas:
        if alerta.direcao == 'acima' and valor_atual > alerta.valor:
            enviar_push(token_fcm, "Alerta!", f"{categoria.title()} está acima de {alerta.valor}")
        elif alerta.direcao == 'abaixo' and valor_atual < alerta.valor:
            enviar_push(token_fcm, "Alerta!", f"{categoria.title()} está abaixo de {alerta.valor}")

# === DEFINIÇÕES ===

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def atualizar_definicoes(request):
    user = request.user
    try:
        idioma = request.data.get('idioma')
        notificacoes = request.data.get('notificacoes')

        profile, _ = Profile.objects.get_or_create(user=user)

        if idioma:
            profile.idioma = idioma
        if notificacoes is not None:
            profile.notificacoes = notificacoes

        profile.save()
        return Response({'status': 'ok'})
    except Exception as e:
        return Response({'erro': str(e)}, status=500)

# === CSV (API COM BASE DE DADOS) ===
def normalizar_nome(nome):
    return (
        nome.strip()
        .lower()
        .replace(" ", "")
        .replace("(", "")
        .replace(")", "")
        .replace("%", "percent")
        .replace("/", "")
    )

@csrf_exempt
@api_view(['POST'])
@permission_classes([AllowAny])
def upload_csv(request):
    try:
        ficheiro = request.FILES.get('ficheiro')
        if not ficheiro:
            return Response({'erro': 'Ficheiro não fornecido'}, status=400)

        path = default_storage.save(f"csv_uploads/{ficheiro.name}", ficheiro)

        with open(default_storage.path(path), 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)

            for row in reader:
                timestamp_segundos = int(row['Timestamp'])
                timestamp = datetime.fromtimestamp(timestamp_segundos)
                deviceid = row['DeviceID']

                for coluna, valor_str in row.items():
                    if coluna in ['Timestamp', 'DeviceID']:
                        continue
                    try:
                        valor = float(valor_str)
                    except:
                        continue  # ignora valores não numéricos

                    categoria = normalizar_nome(coluna)
                    if not SensorData.objects.filter(timestamp=timestamp, categoria=categoria, deviceid=deviceid).exists():
                        SensorData.objects.create(
                            timestamp=timestamp,
                            categoria=categoria,
                            categoria_original=coluna,
                            valor=valor,
                            deviceid=deviceid
                        )

        return Response({'mensagem': 'CSV importado com sucesso.'})
    except Exception as e:
        logger.error(f"Erro ao importar CSV: {e}")
        return Response({'erro': str(e)}, status=500)

@api_view(['GET'])
@permission_classes([AllowAny])
def dados_por_categoria(request, categoria):
    iddevice = request.GET.get('iddevice')
    if not iddevice:
        return Response({'erro': 'ID do dispositivo é obrigatório'}, status=400)

    dados = SensorData.objects.filter(
        deviceid=iddevice,
        categoria=normalizar_nome(categoria)
    ).order_by('timestamp')

    resultado = [["timestamp", "valor"]]
    for d in dados:
        resultado.append([d.timestamp.strftime("%Y-%m-%d %H:%M:%S"), d.valor])

    return Response(resultado)

@api_view(['GET'])
@permission_classes([AllowAny])
def listar_dispositivos(request):
    dispositivos = SensorData.objects.values_list('deviceid', flat=True).distinct()
    return Response(sorted(list(dispositivos)))

@api_view(['GET'])
@permission_classes([AllowAny])
def categorias_por_dispositivo(request):
    iddevice = request.GET.get('iddevice')
    if not iddevice:
        return Response({'erro': 'ID do dispositivo é obrigatório'}, status=400)

    categorias = (
        SensorData.objects
        .filter(deviceid=iddevice)
        .values_list('categoria_original', flat=True)
        .distinct()
    )

    return Response(sorted(categorias))