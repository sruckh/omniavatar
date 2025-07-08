# OmniAvatar Docker Setup

This Docker setup provides a complete containerized environment for running OmniAvatar with a Gradio web interface. **Models are automatically downloaded on first startup!**

## Prerequisites

- Docker with GPU support (nvidia-docker2)
- NVIDIA GPU with CUDA 12.8 support
- Hugging Face account and token

## Quick Start

### 1. Set up Hugging Face Token

```bash
# Create .env file from template
cp .env.template .env

# Edit .env file and add your Hugging Face token
# HF_TOKEN=your_actual_token_here
```

### 2. Run with Docker Compose (Models Auto-Download!)

```bash
# Start the container (models will auto-download on first run)
docker-compose up -d

# Start with public Gradio link
GRADIO_SHARE=true docker-compose up -d

# View logs (including model download progress)
docker-compose logs -f

# Stop the container
docker-compose down
```

**Note:** On first startup, the container will automatically download all required models (~50GB). This may take 10-30 minutes depending on your internet connection. Models are cached locally for subsequent runs.

### 3. Access the Web Interface

Open your browser and navigate to:
- Local: `http://localhost:7860`
- Remote: `http://your_server_ip:7860`

## Alternative: Run with Docker Command

```bash
# Local access only (models auto-download)
docker run --gpus all \
  -p 7860:7860 \
  -v $(pwd)/outputs:/app/outputs:rw \
  -e HF_TOKEN=your_token_here \
  omniavatar:latest

# With persistent model storage (recommended)
docker run --gpus all \
  -p 7860:7860 \
  -v $(pwd)/pretrained_models:/app/pretrained_models:rw \
  -v $(pwd)/outputs:/app/outputs:rw \
  -e HF_TOKEN=your_token_here \
  omniavatar:latest

# With public Gradio link
docker run --gpus all \
  -p 7860:7860 \
  -v $(pwd)/pretrained_models:/app/pretrained_models:rw \
  -v $(pwd)/outputs:/app/outputs:rw \
  -e HF_TOKEN=your_token_here \
  -e GRADIO_SHARE=true \
  omniavatar:latest
```

## Building the Image

### Build Locally

```bash
docker build -t omniavatar:latest .
```

### Build and Push to DockerHub

```bash
# Set your DockerHub username
export DOCKER_USERNAME=your_username

# Build and push
./build_and_push.sh
```

## Configuration

### Environment Variables

- `HF_TOKEN`: Your Hugging Face token (required)
- `CUDA_VISIBLE_DEVICES`: GPU device selection (default: 0)
- `PYTORCH_CUDA_ALLOC_CONF`: PyTorch CUDA memory configuration
- `GRADIO_SHARE`: Create public Gradio link (default: false)

### Volume Mounts

- `./pretrained_models:/app/pretrained_models:rw` - Model files (auto-downloaded and cached)
- `./outputs:/app/outputs:rw` - Generated videos (read-write)
- `./examples:/app/examples:ro` - Example files (optional)

## Usage

1. Upload an image (portrait photo works best)
2. Upload an audio file (.wav or .mp3)
3. Enter a descriptive prompt following the format:
   `[Description of first frame] - [Description of human behavior] - [Background description]`
4. Adjust settings:
   - **Model Size**: 14B (higher quality) or 1.3B (faster)
   - **Guidance Scale**: 4-6 recommended
   - **Audio Scale**: 3-5 for better lip-sync
   - **Steps**: 20-50 (more steps = higher quality)
5. Click "Generate Avatar Video"

## Performance Tips

- Use front-facing, clear portrait photos
- Audio files should be clear speech
- For RunPod/cloud deployment, use environment variables instead of .env file
- Monitor GPU memory usage with `nvidia-smi`

## Troubleshooting

### Common Issues

1. **Out of GPU Memory**: Reduce model size to 1.3B or reduce batch size
2. **Models Not Found**: Ensure models are downloaded and properly mounted
3. **Slow Generation**: Use fewer steps or smaller model size
4. **Poor Quality**: Try higher guidance scale or more steps

### Logs

```bash
# View container logs
docker-compose logs -f omniavatar

# Check GPU usage
nvidia-smi
```

## File Structure

```
OmniAvatar/
├── Dockerfile              # Container definition
├── docker-compose.yml      # Service configuration
├── download_models.sh      # Model download script
├── build_and_push.sh      # Docker build/push script
├── gradio_interface.py     # Web interface
├── .env.template          # Environment template
├── DOCKER_README.md       # This file
├── requirements.txt       # Python dependencies
├── pretrained_models/     # Downloaded models (host)
├── outputs/              # Generated videos (host)
└── examples/             # Example inputs
```

## For RunPod/Cloud Deployment

1. Use the pre-built image from DockerHub
2. Set `HF_TOKEN` environment variable in the platform UI
3. Mount a persistent volume for outputs (models auto-download)
4. Ensure GPU support is enabled
5. Open port 7860 for web access
6. Set `GRADIO_SHARE=true` for public access if needed

**RunPod Example:**
- Template: Custom
- Image: `your_username/omniavatar:latest`
- Environment Variables: `HF_TOKEN=your_token_here`
- Exposed Ports: `7860`
- GPU: Enabled