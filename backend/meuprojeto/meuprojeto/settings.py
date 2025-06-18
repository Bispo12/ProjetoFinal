import os
from pathlib import Path
import pymysql
from datetime import timedelta

pymysql.install_as_MySQLdb()

# Inicializar o ambiente
import environ
env = environ.Env()
environ.Env.read_env()  # Lê o arquivo .env

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/5.1/howto/deployment/checklist/

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = env('DJANGO_SECRET_KEY', default='django-insecure-9(+%c)=#6*4it7kj^cnd8xowlnx1nulr4v=-gg+!*o)mko3=gx')

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = env.bool('DJANGO_DEBUG', True)

# Adicione o IP à lista de ALLOWED_HOSTS
ALLOWED_HOSTS = env(
    'DJANGO_ALLOWED_HOSTS',
    default='127.0.0.1,localhost,10.117.195.135,10.0.2.2,192.168.240.9,192.168.193.180,192.168.1.13,192.168.187.180,192.168.173.180,192.168.222.180,192.168.1.13'
).split(',')




# Application definition
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',  # Adicione o DRF
    'rest_framework.authtoken',  # Adicione o módulo de tokens de autenticação
    'corsheaders',  # Adicione o CORS
    'Utilizadores',  # Adicione a app de utilizadores
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',  # Adicione o middleware CORS (antes do common)
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'meuprojeto.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'meuprojeto.wsgi.application'

# Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': env('DB_NAME', default='litecs_db'),
        'USER': env('DB_USER', default='root'),
        'PASSWORD': env('DB_PASSWORD', default='Joseluis3'),
        'HOST': env('DB_HOST', default='localhost'),
        'PORT': env('DB_PORT', default='3306'),
    }
}

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

# Internationalization
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# Static files (CSS, JavaScript, Images)
STATIC_URL = 'static/'

# Default primary key field type
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Custom user model
AUTH_USER_MODEL = 'Utilizadores.CustomUser'

# Django REST Framework settings
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',  # Usando JWT para autenticação
    ],
}

# Configurações de CORS
CORS_ALLOWED_ORIGINS = [
    "http://127.0.0.1:8000",  # Seu Django
    "http://10.117.195.135:8000",  # Acesso pela rede local
    "http://localhost:8000",  # Acesso local
    "http://localhost:3000",  # Flutter Web na porta 3000
    "http://127.0.0.1:3000",  # Flutter Web na porta 3000
    "http://localhost:8080",  # Flutter Web na porta 8080
    "http://127.0.0.1:8080",  # Flutter Web na porta 8080
    "http://10.0.2.2:8000"  # Exemplo de acesso de emulador Android
]

# Email settings
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = env('DJANGO_EMAIL_HOST', default='smtp.gmail.com')
EMAIL_PORT = env('DJANGO_EMAIL_PORT', default=587)
EMAIL_USE_TLS = True
EMAIL_HOST_USER = env('DJANGO_EMAIL_HOST_USER', default='your-email@gmail.com')
EMAIL_HOST_PASSWORD = env('DJANGO_EMAIL_HOST_PASSWORD', default='your-email-password')
DEFAULT_FROM_EMAIL = EMAIL_HOST_USER

FRONTEND_URL = env('FRONTEND_URL', default='http://10.0.2.2:3000')

# Add any other necessary configurations here
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=5),  # Defina a validade do token de acesso
    'REFRESH_TOKEN_LIFETIME': timedelta(days=1),    # Defina a validade do refresh token
    'ROTATE_REFRESH_TOKENS': False,
    'BLACKLIST_AFTER_ROTATION': False,
    'ALGORITHM': 'HS256',  # Algoritmo usado para assinatura do JWT
    'SIGNING_KEY': SECRET_KEY,  # Use a mesma chave secreta do Django
    'AUTH_HEADER_TYPES': ('Bearer',),
    'USER_ID_FIELD': 'id',
    'USER_ID_CLAIM': 'user_id',
}

# Configuração do diretório para os arquivos CSV
CSV_DATA_FOLDER = os.path.join(BASE_DIR, 'Data')  
