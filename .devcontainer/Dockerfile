FROM python:3.10-bookworm

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apt update && apt install -y 
git 
curl 
build-essential 
libxml2-dev 
libxslt1-dev 
libjpeg-dev 
zlib1g-dev 
libpq-dev 
mc 
vim 
&& rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY requirements.txt .

RUN pip install --upgrade pip setuptools wheel

RUN pip install -r requirements.txt

RUN pip install 
black 
ruff 
pytest 
ipython 
django-debug-toolbar 
debugpy
