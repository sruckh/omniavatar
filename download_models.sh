#!/bin/bash

# OmniAvatar Model Download Script
# This script downloads all required models for OmniAvatar
# Run this on the HOST SYSTEM before starting the Docker container

set -e

echo "Starting model downloads..."

# Check if HF_TOKEN is set
if [ -z "$HF_TOKEN" ]; then
    echo "Warning: HF_TOKEN environment variable not set. Some models may not download correctly."
    echo "Please set your Hugging Face token in the .env file and source it:"
    echo "source .env"
    echo "or export HF_TOKEN=your_token_here"
fi

# Create the exact directory structure as specified in README
mkdir -p pretrained_models

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

# Set HF token if provided
if [ ! -z "$HF_TOKEN" ]; then
    huggingface-cli login --token $HF_TOKEN
fi

# Download models with retry logic
download_with_retry "Wan-AI/Wan2.1-T2V-14B" "./pretrained_models/Wan2.1-T2V-14B" || exit 1
download_with_retry "OmniAvatar/OmniAvatar-14B" "./pretrained_models/OmniAvatar-14B" || exit 1
download_with_retry "Wan-AI/Wan2.1-T2V-1.3B" "./pretrained_models/Wan2.1-T2V-1.3B" || exit 1
download_with_retry "OmniAvatar/OmniAvatar-1.3B" "./pretrained_models/OmniAvatar-1.3B" || exit 1
download_with_retry "facebook/wav2vec2-base-960h" "./pretrained_models/wav2vec2-base-960h" || exit 1

echo "All models downloaded successfully!"

# Optional: Download flash_attn wheel for faster container startup
echo ""
echo "🔍 Optional: Pre-downloading flash_attn wheel for faster container startup..."
echo "(This is optional - flash_attn will be downloaded automatically in the container if needed)"
read -p "Download flash_attn wheel now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📥 Downloading flash_attn wheel..."
    mkdir -p ./cache
    wget -q --timeout=300 -O ./cache/flash_attn.whl "https://github.com/Dao-AILab/flash-attention/releases/download/v2.8.1/flash_attn-2.8.1+cu12torch2.7cxx11abiFALSE-cp312-cp312-linux_x86_64.whl"
    if [ $? -eq 0 ]; then
        echo "✅ flash_attn wheel downloaded to ./cache/flash_attn.whl"
        echo "    You can mount this in the container with: -v \$(pwd)/cache:/app/cache:ro"
    else
        echo "⚠️  Failed to download flash_attn wheel (will be downloaded at container startup)"
    fi
else
    echo "Skipping flash_attn wheel download (will be downloaded at container startup)"
fi

echo ""
echo "Final directory structure:"
echo "OmniAvatar/"
echo "├── pretrained_models/"
echo "│   ├── Wan2.1-T2V-14B/"
echo "│   ├── OmniAvatar-14B/"
echo "│   ├── Wan2.1-T2V-1.3B/"
echo "│   ├── OmniAvatar-1.3B/"
echo "│   └── wav2vec2-base-960h/"
if [ -f "./cache/flash_attn.whl" ]; then
    echo "└── cache/"
    echo "    └── flash_attn.whl"
fi

echo ""
echo "Verifying structure:"
ls -la ./pretrained_models/
if [ -d "./cache" ]; then
    echo ""
    echo "Cache directory:"
    ls -la ./cache/
fi

echo ""
echo "Download complete. Models are ready for use."
echo "You can now run the Docker container with the models mounted."