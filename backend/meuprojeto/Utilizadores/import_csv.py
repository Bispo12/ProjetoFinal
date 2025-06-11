import csv
from datetime import datetime
from django.utils.timezone import make_aware
from .models import SensorData

def importar_csv_para_bd(ficheiro_csv):
    with open(ficheiro_csv, newline='', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            try:
                timestamp = make_aware(datetime.fromtimestamp(int(row['Timestamp'])))
                deviceid = row['DeviceID']

                for categoria in ['MaximumWindSpeed(kmh)', 'WindSpeed(kmh)', 'Precipitation(mm)',
                                  'Pressure(hPa)', 'Temperature(C)', 'Humidity(%)',
                                  'Wind Direction', 'Soil Mosture(%)']:
                    valor_str = row.get(categoria, "").strip()
                    if valor_str == "":
                        continue  # ignora campos vazios

                    try:
                        valor = float(valor_str)
                    except ValueError:
                        continue  # ignora valores não numéricos

                    SensorData.objects.create(
                        timestamp=timestamp,
                        deviceid=deviceid,
                        categoria=categoria,
                        valor=valor,
                        categoria_original=categoria
                    )
            except Exception as e:
                print(f"Erro ao importar linha: {e}")
