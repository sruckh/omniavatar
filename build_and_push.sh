#!/bin/bash

# OmniAvatar Docker Build and Push Script
# This script builds the Docker image and pushes it to DockerHub

set -e

# Configuration
DOCKER_USERNAME=${DOCKER_USERNAME:-"your_username"}
IMAGE_NAME="omniavatar"
VERSION=${VERSION:-"latest"}
FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"

echo "Building OmniAvatar Docker image..."
echo "Image: ${FULL_IMAGE_NAME}"

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

echo "Build and push completed successfully!"
echo "Image available at: ${FULL_IMAGE_NAME}"
echo ""
echo "To use this image:"
echo "1. Download models using: ./download_models.sh"
echo "2. Run with: docker-compose up"
echo "3. Or run directly: docker run --gpus all -p 7860:7860 -v \$(pwd)/pretrained_models:/app/pretrained_models:ro -v \$(pwd)/outputs:/app/outputs:rw ${FULL_IMAGE_NAME}"