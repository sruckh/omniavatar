# Multi-stage build for OmniAvatar
FROM python:3.12-slim AS base

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    build-essential \
    libsndfile1 \
    libsndfile1-dev \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements-base.txt .

# Install base requirements only (PyTorch, peft, transformers, xfuser, and flash_attn will be installed at runtime)
RUN pip install --no-cache-dir -r requirements-base.txt

# Install huggingface-cli for model downloads
RUN pip install --no-cache-dir "huggingface_hub[cli]"

# Install gradio for web interface
RUN pip install --no-cache-dir gradio

# Copy application code
COPY . .

# Create directories for outputs and models (models will be auto-downloaded)
RUN mkdir -p outputs pretrained_models

# Copy application files
COPY gradio_interface.py .
COPY startup.sh .

# Expose port for Gradio
EXPOSE 7860

# Default command - startup script handles model downloads and launches Gradio
CMD ["./startup.sh"]