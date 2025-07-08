# Multi-stage build for OmniAvatar
FROM python:3.12-slim as base

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
COPY requirements.txt .

# Install PyTorch with CUDA 12.8 support
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

# Install flash-attention wheel for Python 3.12
RUN pip install --no-cache-dir https://github.com/Dao-AILab/flash-attention/releases/download/v2.8.0.post2/flash_attn-2.8.0.post2+cu118torch2.5cxx11abiFALSE-cp312-cp312-linux_x86_64.whl

# Install other requirements
RUN pip install --no-cache-dir -r requirements.txt

# Install huggingface-cli for model downloads
RUN pip install --no-cache-dir "huggingface_hub[cli]"

# Install gradio for web interface
RUN pip install --no-cache-dir gradio

# Copy application code
COPY . .

# Create directories for outputs (models will be mounted from host)
RUN mkdir -p outputs

# Copy gradio interface
COPY gradio_interface.py .

# Expose port for Gradio
EXPOSE 7860

# Default command
CMD ["python", "gradio_interface.py"]