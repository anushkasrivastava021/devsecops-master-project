FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

RUN useradd -m appuser && chown -R appuser /app
USER appuser

EXPOSE 8080

CMD ["python", "main.py"]