FROM python:3.13-slim
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
COPY . /app
RUN pip install --no-cache-dir -r public-requirements.txt && pip install --no-cache-dir git+https://github.com/FEEHOAI/feeho-employee.git
EXPOSE 8080
CMD ["sh","-c","uvicorn http_bridge:app --host 0.0.0.0 --port ${PORT:-8080}"]
