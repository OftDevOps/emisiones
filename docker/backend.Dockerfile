FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app/backend

RUN apt-get update && apt-get install -y     build-essential     libpq-dev     gettext     curl     && rm -rf /var/lib/apt/lists/*

COPY backend/requirements/base.txt /tmp/base.txt

RUN pip install --upgrade pip     && pip install -r /tmp/base.txt

COPY backend /app/backend

EXPOSE 8000
