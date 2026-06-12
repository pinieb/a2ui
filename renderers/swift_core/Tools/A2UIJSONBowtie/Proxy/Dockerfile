FROM python:3.11-alpine
WORKDIR /app
COPY proxy.py .
# Set environment variable to ensure python output is unbuffered
ENV PYTHONUNBUFFERED=1
ENTRYPOINT ["python", "proxy.py"]
