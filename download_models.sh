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

# Set HF token if provided
if [ ! -z "$HF_TOKEN" ]; then
    huggingface-cli login --token $HF_TOKEN
fi

echo "Downloading Wan2.1-T2V-14B base model..."
huggingface-cli download Wan-AI/Wan2.1-T2V-14B --local-dir ./pretrained_models/Wan2.1-T2V-14B

echo "Downloading OmniAvatar-14B model..."
huggingface-cli download OmniAvatar/OmniAvatar-14B --local-dir ./pretrained_models/OmniAvatar-14B

echo "Downloading Wan2.1-T2V-1.3B base model..."
huggingface-cli download Wan-AI/Wan2.1-T2V-1.3B --local-dir ./pretrained_models/Wan2.1-T2V-1.3B

echo "Downloading OmniAvatar-1.3B model..."
huggingface-cli download OmniAvatar/OmniAvatar-1.3B --local-dir ./pretrained_models/OmniAvatar-1.3B

echo "Downloading Wav2Vec2 audio encoder..."
huggingface-cli download facebook/wav2vec2-base-960h --local-dir ./pretrained_models/wav2vec2-base-960h

echo "All models downloaded successfully!"
echo "Final directory structure:"
echo "OmniAvatar/"
echo "├── pretrained_models/"
echo "│   ├── Wan2.1-T2V-14B/"
echo "│   ├── OmniAvatar-14B/"
echo "│   ├── Wan2.1-T2V-1.3B/"
echo "│   ├── OmniAvatar-1.3B/"
echo "│   └── wav2vec2-base-960h/"

echo ""
echo "Verifying structure:"
ls -la ./pretrained_models/

echo ""
echo "Download complete. Models are ready for use."
echo "You can now run the Docker container with the models mounted."