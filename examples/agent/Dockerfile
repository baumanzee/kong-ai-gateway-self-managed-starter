FROM python:3.12-slim
WORKDIR /app
COPY agent.py .
RUN useradd -m app
USER app
ENTRYPOINT ["python", "-u", "agent.py"]
