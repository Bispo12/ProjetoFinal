import csv, json, os, logging
from datetime import datetime
from django.utils.timezone import make_aware
from .models import SensorData

logger = logging.getLogger(__name__)

CATEGORIAS_FIXAS = [
    "MaximumWindSpeed(kmh)", "WindSpeed(kmh)", "Precipitation(mm)",
    "Pressure(hPa)", "Temperature(C)", "Humidity(%)",
    "Wind Direction", "Soil Mosture(%)", "estado",
]

# ------- helper p/ nomes limpos (se quiseres indexar/filtrar) --------
def normalizar_nome(nome: str) -> str:
    return (
        nome.strip().lower()
            .replace(" ", "")
            .replace("(", "")
            .replace(")", "")
            .replace("%", "percent")
            .replace("/", "")
    )

# --------------------------------------------------------------------
def importar_ficheiro_para_bd(ficheiro) -> None:
    nome = ficheiro.name.lower()

    if nome.endswith(".csv"):
        _importar_csv(ficheiro)
    elif nome.endswith(".json"):
        _importar_json(ficheiro)
    else:
        raise ValueError("Formato não suportado (usa .csv ou .json)")
# ---------------------------- CSV -----------------------------------
def _importar_csv(ficheiro) -> None:
    decoded = ficheiro.read().decode("utf-8").splitlines()
    reader = csv.DictReader(decoded)

    for row in reader:
        try:
            ts = make_aware(datetime.fromtimestamp(int(row["Timestamp"])))
            dev = row["DeviceID"]
        except (KeyError, ValueError):
            logger.warning("Linha CSV ignorada: %s", row)
            continue

        estado_atual = None
        for cat in CATEGORIAS_FIXAS:
            valor_txt = (row.get(cat) or "").strip()
            if valor_txt == "":
                continue
            try:
                val = float(valor_txt)
            except ValueError:
                continue

            if cat == "estado":
                estado_atual = val

            SensorData.objects.create(
                timestamp=ts,
                deviceid=dev,
                categoria=cat,
                categoria_original=cat,
                valor=val,
                estado=estado_atual
            )

# ---------------------------- JSON ----------------------------------
def _importar_json(ficheiro_json: str) -> None:
    with open(ficheiro_json, encoding="utf-8") as f:
        try:
            payload = json.load(f)
        except json.JSONDecodeError as e:
            logger.error("JSON inválido: %s", e)
            return

    if isinstance(payload, dict):
        payload = [payload]          # permite objecto único

    for item in payload:
        try:
            ts  = make_aware(datetime.fromtimestamp(int(item["Timestamp"])))
            dev = str(item["Deviceid"]).strip()
            dados = item["data"]
        except (KeyError, ValueError, TypeError):
            logger.warning("Registo JSON ignorado: %s", item)
            continue

        for cat, raw in dados.items():
            # aceita as categorias que já conhecidas
            if cat not in CATEGORIAS_FIXAS:
                continue
            try:
                val = float(raw)
            except (ValueError, TypeError):
                continue

            SensorData.objects.create(
                timestamp=ts,
                deviceid=dev,
                categoria=cat,
                categoria_original=cat,
                valor=val,
                estado=val if cat == "estado" else None
            )

