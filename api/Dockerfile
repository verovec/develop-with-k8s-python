FROM python:3.10

WORKDIR /app

COPY src .
COPY pyproject.toml .

RUN pip install --no-cache-dir poetry && \
    poetry config virtualenvs.create false && \
    poetry install

EXPOSE 8080

CMD ["python3", "main.py"]
