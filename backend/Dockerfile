FROM python:3.13-slim

WORKDIR /app

# Install uv using the official multi-stage build image
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Copy dependency configuration
COPY pyproject.toml .

# Install dependencies to system python using uv
RUN uv pip install --system -r pyproject.toml

# Copy application code
COPY app/ ./app/

# Expose FastAPI default port
EXPOSE 8000

# Set Python Path to include /app
ENV PYTHONPATH=/app

# Command to run uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
