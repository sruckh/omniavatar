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

# Function to install PyTorch with CUDA support
install_pytorch() {
    echo "🔍 Checking for PyTorch..."
    if python -c "import torch; print(f'PyTorch {torch.__version__} (CUDA available: {torch.cuda.is_available()})')" 2>/dev/null; then
        echo "✅ PyTorch is already installed"
        return 0
    else
        echo "📥 Installing PyTorch with CUDA 12.8 support..."
        local pytorch_url="https://download.pytorch.org/whl/cu128"
        local max_retries=3
        local retry_count=0
        
        while [ $retry_count -lt $max_retries ]; do
            echo "📥 Installing PyTorch (attempt $((retry_count + 1))/$max_retries)..."
            
            if pip install --no-cache-dir torch torchvision torchaudio --index-url "$pytorch_url"; then
                echo "✅ PyTorch installed successfully"
                python -c "
import torch
print(f'PyTorch {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'CUDA version: {torch.version.cuda}')
    print(f'GPU count: {torch.cuda.device_count()}')
    print(f'GPU name: {torch.cuda.get_device_name(0)}')
    print(f'GPU memory: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f}GB')
    # Test GPU tensor operations
    x = torch.randn(100, 100).cuda()
    y = torch.randn(100, 100).cuda()
    z = torch.matmul(x, y)
    print(f'GPU tensor test: {z.shape} on {z.device}')
else:
    print('⚠️  No GPU detected')
"
                return 0
            else
                retry_count=$((retry_count + 1))
                if [ $retry_count -lt $max_retries ]; then
                    echo "⚠️  PyTorch installation failed, retrying in 10s..."
                    sleep 10
                else
                    echo "❌ Failed to install PyTorch after $max_retries attempts"
                    echo "⚠️  Cannot continue without PyTorch"
                    exit 1
                fi
            fi
        done
    fi
}

# Function to install flash_attn if not available
install_flash_attn() {
    echo "🔍 Checking for flash_attn..."
    if python -c "import flash_attn" 2>/dev/null; then
        echo "✅ flash_attn is already installed"
        return 0
    else
        echo "📥 Installing flash_attn..."
        local flash_attn_url="https://github.com/Dao-AILab/flash-attention/releases/download/v2.8.1/flash_attn-2.8.1+cu12torch2.7cxx11abiFALSE-cp312-cp312-linux_x86_64.whl"
        local max_retries=3
        local retry_count=0
        
        # Check if cached wheel exists first
        local cached_wheel="/app/cache/flash_attn-2.8.1+cu12torch2.7cxx11abiFALSE-cp312-cp312-linux_x86_64.whl"
        if [ -f "$cached_wheel" ]; then
            echo "✅ Found cached flash_attn wheel, installing..."
            if pip install --no-cache-dir "$cached_wheel"; then
                echo "✅ flash_attn installed successfully from cache"
                return 0
            else
                echo "⚠️  Failed to install from cache, downloading..."
            fi
        fi
        
        # Download and install if not cached or cache failed
        while [ $retry_count -lt $max_retries ]; do
            echo "📥 Downloading flash_attn wheel (attempt $((retry_count + 1))/$max_retries)..."
            
            local wheel_filename="flash_attn-2.8.1+cu12torch2.7cxx11abiFALSE-cp312-cp312-linux_x86_64.whl"
            if wget -q --timeout=300 -O "/tmp/$wheel_filename" "$flash_attn_url" && \
               pip install --no-cache-dir "/tmp/$wheel_filename" && \
               rm -f "/tmp/$wheel_filename"; then
                echo "✅ flash_attn installed successfully"
                return 0
            else
                retry_count=$((retry_count + 1))
                if [ $retry_count -lt $max_retries ]; then
                    echo "⚠️  flash_attn installation failed, retrying in 10s..."
                    sleep 10
                else
                    echo "❌ Failed to install flash_attn after $max_retries attempts"
                    echo "⚠️  Continuing without flash_attn (performance may be slower)"
                    return 1
                fi
            fi
        done
    fi
}

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

# Install PyTorch with CUDA support
install_pytorch

# Install additional Python packages that require PyTorch
install_ml_packages() {
    echo "📦 Installing ML packages (peft, transformers, xfuser)..."
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        echo "📥 Installing ML packages (attempt $((retry_count + 1))/$max_retries)..."
        
        if pip install --no-cache-dir peft==0.15.1 transformers==4.52.3 xfuser==0.4.1; then
            echo "✅ ML packages installed successfully"
            return 0
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                echo "⚠️  ML packages installation failed, retrying in 10s..."
                sleep 10
            else
                echo "❌ Failed to install ML packages after $max_retries attempts"
                echo "⚠️  Cannot continue without ML packages"
                exit 1
            fi
        fi
    done
}

# Install ML packages
install_ml_packages

# Install flash_attn for performance optimization
install_flash_attn

# Verify final model structure
echo "📋 Final model structure:"
ls -la /app/pretrained_models/

# Set GPU environment variables for proper inference
echo "🔧 Setting GPU environment variables..."
export RANK=0
export LOCAL_RANK=0
export WORLD_SIZE=1
export NNODES=1
export CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0}

# Final GPU verification
echo "🔍 Final GPU verification:"
python -c "
import torch
import os
print(f'PyTorch version: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
print(f'Environment variables:')
print(f'  CUDA_VISIBLE_DEVICES: {os.environ.get(\"CUDA_VISIBLE_DEVICES\", \"Not set\")}')
print(f'  RANK: {os.environ.get(\"RANK\", \"Not set\")}')
print(f'  LOCAL_RANK: {os.environ.get(\"LOCAL_RANK\", \"Not set\")}')
print(f'  WORLD_SIZE: {os.environ.get(\"WORLD_SIZE\", \"Not set\")}')
if torch.cuda.is_available():
    print(f'CUDA version: {torch.version.cuda}')
    print(f'GPU count: {torch.cuda.device_count()}')
    for i in range(torch.cuda.device_count()):
        print(f'GPU {i}: {torch.cuda.get_device_name(i)}')
    print(f'Current GPU: {torch.cuda.current_device()}')
    print(f'GPU memory: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f}GB')
    # Test actual GPU operations
    try:
        x = torch.randn(1000, 1000).cuda()
        y = torch.mm(x, x.t())
        print(f'✅ GPU operations working: {y.shape} on {y.device}')
    except Exception as e:
        print(f'❌ GPU operations failed: {e}')
else:
    print('❌ No GPU detected - inference will be CPU-only')
"

echo "🚀 Starting Gradio interface..."

# Parse command line arguments for the Python script
PYTHON_ARGS=""
if [ "${GRADIO_SHARE}" = "true" ]; then
    PYTHON_ARGS="--share"
fi

# Start the Gradio interface
exec python gradio_interface.py $PYTHON_ARGS