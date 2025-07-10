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

# Function to download with retry logic
download_with_retry() {
    local model_name=$1
    local local_dir=$2
    local max_retries=8
    local retry_count=0
    local wait_time=5
    
    while [ $retry_count -lt $max_retries ]; do
        echo "📥 Downloading $model_name (attempt $((retry_count + 1))/$max_retries)..."
        
        # Use longer timeout and additional HF CLI options for better reliability
        if timeout 7200 huggingface-cli download "$model_name" \
            --local-dir "$local_dir" \
            --resume-download \
            --local-dir-use-symlinks False \
            --repo-type model; then
            echo "✅ Successfully downloaded $model_name"
            return 0
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                echo "⚠️  Download failed, retrying in ${wait_time}s..."
                sleep $wait_time
                # More conservative backoff to avoid overwhelming the server
                if [ $retry_count -ge 3 ]; then
                    wait_time=$((wait_time + 30))  # Longer waits after multiple failures
                else
                    wait_time=$((wait_time * 2))   # Standard exponential backoff initially
                fi
            else
                echo "❌ Failed to download $model_name after $max_retries attempts"
                return 1
            fi
        fi
    done
}

# Download models if they don't exist
if ! check_models; then
    echo "🔐 Logging in to Hugging Face..."
    huggingface-cli login --token $HF_TOKEN
    
    echo "📁 Creating models directory..."
    mkdir -p /app/pretrained_models
    
    # Download models with retry logic
    download_with_retry "Wan-AI/Wan2.1-T2V-14B" "/app/pretrained_models/Wan2.1-T2V-14B" || exit 1
    download_with_retry "OmniAvatar/OmniAvatar-14B" "/app/pretrained_models/OmniAvatar-14B" || exit 1
    download_with_retry "Wan-AI/Wan2.1-T2V-1.3B" "/app/pretrained_models/Wan2.1-T2V-1.3B" || exit 1
    download_with_retry "OmniAvatar/OmniAvatar-1.3B" "/app/pretrained_models/OmniAvatar-1.3B" || exit 1
    download_with_retry "facebook/wav2vec2-base-960h" "/app/pretrained_models/wav2vec2-base-960h" || exit 1
    
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