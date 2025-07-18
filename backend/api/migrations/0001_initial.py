# Generated by Django 5.1.3 on 2025-06-19 18:00

from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
    ]

    operations = [
        migrations.CreateModel(
            name='ProcessedPoint',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('timestamp', models.DateTimeField(auto_now_add=True, db_index=True)),
                ('latitude', models.FloatField()),
                ('longitude', models.FloatField()),
                ('severity', models.FloatField()),
            ],
        ),
    ]
