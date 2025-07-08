#!/bin/bash

# OmniAvatar Docker Build and Push Script
# This script builds the Docker image and pushes it to DockerHub
#
# Usage:
#   ./build_and_push.sh                    # Build and push with default settings
#   DOCKER_USERNAME=myuser ./build_and_push.sh  # Use custom username
#   VERSION=v1.0 ./build_and_push.sh       # Use custom version tag
#
# Prerequisites:
#   - Docker installed and running
#   - DockerHub account
#   - Logged in to DockerHub (docker login)

set -e

# Configuration
DOCKER_USERNAME=${DOCKER_USERNAME:-"your_username"}
IMAGE_NAME="omniavatar"
VERSION=${VERSION:-"latest"}
FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"

echo "🐳 Building OmniAvatar Docker image..."
echo "📦 Image: ${FULL_IMAGE_NAME}"
echo "👤 Username: ${DOCKER_USERNAME}"
echo "🏷️  Version: ${VERSION}"
echo ""

# Validate username
if [ "${DOCKER_USERNAME}" = "your_username" ]; then
    echo "⚠️  Warning: Using default username 'your_username'"
    echo "   Set DOCKER_USERNAME environment variable to your DockerHub username"
    echo "   Example: DOCKER_USERNAME=myuser ./build_and_push.sh"
    echo ""
fi

# Build the Docker image
echo "Building Docker image..."
docker build -t ${FULL_IMAGE_NAME} .

# Also tag as latest if not already
if [ "${VERSION}" != "latest" ]; then
    docker tag ${FULL_IMAGE_NAME} ${DOCKER_USERNAME}/${IMAGE_NAME}:latest
fi

# Login to DockerHub (if not already logged in)
echo "Logging in to DockerHub..."
docker login

# Push the image
echo "Pushing image to DockerHub..."
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