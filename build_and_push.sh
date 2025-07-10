#!/bin/bash

# OmniAvatar Docker Build and Push Script
# This script builds the Docker image and pushes it to Docker Hub
#
# Usage:
#   ./build_and_push.sh                    # Build and push with default settings
#   DOCKER_USERNAME=myuser ./build_and_push.sh  # Use custom username
#   VERSION=v1.0 ./build_and_push.sh       # Use custom version tag
#
# Prerequisites:
#   - Docker installed and running
#   - Docker Hub account
#   - Logged in to Docker Hub (docker login)

set -e

# Configuration
DOCKER_USERNAME=${DOCKER_USERNAME:-"your_username"}
IMAGE_NAME="omniavatar"
VERSION=${VERSION:-"latest"}
REGISTRY="docker.io"
FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"

echo "🐳 Building OmniAvatar Docker image..."
echo "📦 Image: ${FULL_IMAGE_NAME}"
echo "👤 Username: ${DOCKER_USERNAME}"
echo "🏷️  Version: ${VERSION}"
echo ""

# Validate username
if [ "${DOCKER_USERNAME}" = "your_username" ]; then
    echo "⚠️  Warning: Using default username 'your_username'"
    echo "   Set DOCKER_USERNAME environment variable to your Docker Hub username"
    echo "   Example: DOCKER_USERNAME=myuser ./build_and_push.sh"
    echo ""
fi

# Build the Docker image
echo "Building Docker image..."
echo "📝 Note: flash_attn now installs at runtime for smaller image size"
docker build -t ${FULL_IMAGE_NAME} .

# Also tag as latest if not already
if [ "${VERSION}" != "latest" ]; then
    docker tag ${FULL_IMAGE_NAME} ${DOCKER_USERNAME}/${IMAGE_NAME}:latest
fi

# Login to Docker Hub (if not already logged in)
echo "Logging in to Docker Hub..."
docker login

# Push the image
echo "Pushing image to Docker Hub..."
docker push ${FULL_IMAGE_NAME}

if [ "${VERSION}" != "latest" ]; then
    docker push ${DOCKER_USERNAME}/${IMAGE_NAME}:latest
fi

echo "✅ Build and push completed successfully!"
echo "🚀 Image available at: ${FULL_IMAGE_NAME}"
echo ""
echo "📋 To use this image:"
echo "1. Set HF_TOKEN environment variable"
echo "2. Run with Docker Compose: docker-compose up"
echo "3. Or run directly (models auto-download):"
echo "   docker run --gpus all -p 7860:7860 \\"
echo "     -v \$(pwd)/outputs:/app/outputs:rw \\"
echo "     -e HF_TOKEN=your_token_here \\"
echo "     ${FULL_IMAGE_NAME}"
echo ""
echo "4. With persistent model storage:"
echo "   docker run --gpus all -p 7860:7860 \\"
echo "     -v \$(pwd)/pretrained_models:/app/pretrained_models:rw \\"
echo "     -v \$(pwd)/outputs:/app/outputs:rw \\"
echo "     -e HF_TOKEN=your_token_here \\"
echo "     ${FULL_IMAGE_NAME}"
echo ""
echo "5. With Gradio share (public link):"
echo "   docker run --gpus all -p 7860:7860 \\"
echo "     -v \$(pwd)/pretrained_models:/app/pretrained_models:rw \\"
echo "     -v \$(pwd)/outputs:/app/outputs:rw \\"
echo "     -e HF_TOKEN=your_token_here \\"
echo "     -e GRADIO_SHARE=true \\"
echo "     ${FULL_IMAGE_NAME}"
echo ""
echo "6. Multi-GPU for maximum performance (requires multiple GPUs):"
echo "   docker run --gpus all -p 7860:7860 \\"
echo "     -v \$(pwd)/pretrained_models:/app/pretrained_models:rw \\"
echo "     -v \$(pwd)/outputs:/app/outputs:rw \\"
echo "     -e HF_TOKEN=your_token_here \\"
echo "     -e CUDA_VISIBLE_DEVICES=0,1,2,3 \\"
echo "     --shm-size=2g \\"
echo "     ${FULL_IMAGE_NAME}"
echo ""
echo "7. With flash_attn cache for faster startup:"
echo "   docker run --gpus all -p 7860:7860 \\"
echo "     -v \$(pwd)/pretrained_models:/app/pretrained_models:rw \\"
echo "     -v \$(pwd)/outputs:/app/outputs:rw \\"
echo "     -v \$(pwd)/cache:/app/cache:ro \\"
echo "     -e HF_TOKEN=your_token_here \\"
echo "     ${FULL_IMAGE_NAME}"
echo ""
echo "💡 Performance Tips:"
echo "• Run ./download_models.sh to pre-download models and flash_attn wheel"
echo "• Flash Attention downloads automatically at container startup if not cached"
echo "• Use the Advanced Settings in Gradio to enable TeaCache (0.14) for 3-4x speedup"
echo "• Enable multi-GPU (sp_size=2-8) if you have multiple GPUs available"
echo "• Try the 1.3B model for much faster inference"
echo "• Use FSDP to reduce VRAM usage from 36GB to 14GB"
