from django.db import models
from django.contrib.auth import get_user_model
from django.contrib.auth.models import AbstractUser

class CustomUser(AbstractUser):
    bio = models.TextField(blank=True)

    def __str__(self):
        return self.username

class Produto(models.Model):
    nome = models.CharField(max_length=200)
    descricao = models.TextField()
    preco = models.DecimalField(max_digits=10, decimal_places=2)

    def __str__(self):
        return self.nome

class Localizacao(models.Model):
    lat = models.FloatField()
    lng = models.FloatField()
    descricao = models.CharField(max_length=255, blank=True)

    def __str__(self):
        return f"{self.lat}, {self.lng} - {self.descricao}"

class Alerta(models.Model):
    user = models.ForeignKey(get_user_model(), on_delete=models.CASCADE)
    parametro = models.CharField(max_length=50)
    valor = models.FloatField()
    direcao = models.CharField(max_length=10)
    ativo = models.BooleanField(default=True)

    def __str__(self):
        return f'{self.parametro} {self.direcao} {self.valor}'

class Profile(models.Model):
    user = models.OneToOneField(get_user_model(), on_delete=models.CASCADE)
    idioma = models.CharField(max_length=10, default='pt')
    notificacoes = models.BooleanField(default=True)

    def __str__(self):
        return f'Perfil de {self.user.username}'

class SensorData(models.Model):
    timestamp = models.BigIntegerField()
    categoria = models.CharField(max_length=100)  # Nome normalizado
    categoria_original = models.CharField(max_length=100)  # Nome tal como está no CSV
    valor = models.FloatField()
    deviceid = models.CharField(max_length=100)
    estado = models.FloatField(null=True, blank=True)

    def __str__(self):
        return f"{self.timestamp} - {self.categoria_original} ({self.deviceid}): {self.valor}"
