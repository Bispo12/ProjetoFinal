# Generated by Django 5.2.3 on 2025-06-13 17:09

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('Utilizadores', '0005_sensordata_categoria_original'),
    ]

    operations = [
        migrations.AlterField(
            model_name='sensordata',
            name='timestamp',
            field=models.BigIntegerField(),
        ),
    ]
