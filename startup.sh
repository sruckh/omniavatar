#!/bin/bash

# OmniAvatar Startup Script
# This script downloads models automatically and then starts the Gradio interface

set -e

echo "🎭 Starting OmniAvatar..."

# Check if HF_TOKEN is set
if [ -z "$HF_TOKEN" ]; then
    echo "❌ Error: HF_TOKEN environment variable is not set"
    echo "Please set your Hugging Face token as an environment variable"
    exit 1
fi

echo "✅ HF_TOKEN is set"

# Function to check if models exist
check_models() {
    local models_exist=true
    
    if [ ! -d "/app/pretrained_models/Wan2.1-T2V-14B" ]; then
        models_exist=false
    fi
    if [ ! -d "/app/pretrained_models/OmniAvatar-14B" ]; then
        models_exist=false
    fi
    if [ ! -d "/app/pretrained_models/Wan2.1-T2V-1.3B" ]; then
        models_exist=false
    fi
    if [ ! -d "/app/pretrained_models/OmniAvatar-1.3B" ]; then
        models_exist=false
    fi
    if [ ! -d "/app/pretrained_models/wav2vec2-base-960h" ]; then
        models_exist=false
    fi
    
    if $models_exist; then
        echo "✅ All models found in /app/pretrained_models/"
        return 0
    else
        echo "📥 Models not found. Downloading..."
        return 1
    fi
}

# Download models if they don't exist
if ! check_models; then
    echo "🔐 Logging in to Hugging Face..."
    huggingface-cli login --token $HF_TOKEN
    
    echo "📁 Creating models directory..."
    mkdir -p /app/pretrained_models
    
    echo "📥 Downloading Wan2.1-T2V-14B base model..."
    huggingface-cli download Wan-AI/Wan2.1-T2V-14B --local-dir /app/pretrained_models/Wan2.1-T2V-14B
    
    echo "📥 Downloading OmniAvatar-14B model..."
    huggingface-cli download OmniAvatar/OmniAvatar-14B --local-dir /app/pretrained_models/OmniAvatar-14B
    
    echo "📥 Downloading Wan2.1-T2V-1.3B base model..."
    huggingface-cli download Wan-AI/Wan2.1-T2V-1.3B --local-dir /app/pretrained_models/Wan2.1-T2V-1.3B
    
    echo "📥 Downloading OmniAvatar-1.3B model..."
    huggingface-cli download OmniAvatar/OmniAvatar-1.3B --local-dir /app/pretrained_models/OmniAvatar-1.3B
    
    echo "📥 Downloading Wav2Vec2 audio encoder..."
    huggingface-cli download facebook/wav2vec2-base-960h --local-dir /app/pretrained_models/wav2vec2-base-960h
    
    echo "✅ All models downloaded successfully!"
else
    echo "✅ Using existing models"
fi

# Verify final model structure
echo "📋 Final model structure:"
ls -la /app/pretrained_models/

echo "🚀 Starting Gradio interface..."

# Parse command line arguments for the Python script
PYTHON_ARGS=""
if [ "${GRADIO_SHARE}" = "true" ]; then
    PYTHON_ARGS="--share"
fi

# Start the Gradio interface
exec python gradio_interface.py $PYTHON_ARGS