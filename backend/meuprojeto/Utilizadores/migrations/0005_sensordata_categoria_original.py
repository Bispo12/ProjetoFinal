# Generated by Django 5.2.3 on 2025-06-11 13:15

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('Utilizadores', '0004_sensordata'),
    ]

    operations = [
        migrations.AddField(
            model_name='sensordata',
            name='categoria_original',
            field=models.CharField(default='categoria_original', max_length=100),
            preserve_default=False,
        ),
    ]
