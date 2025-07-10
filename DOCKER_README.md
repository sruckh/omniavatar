# OmniAvatar Docker Setup

This document explains how to run OmniAvatar using Docker with optimized performance.

## Quick Start

1. **Set up environment variables:**
   ```bash
   export HF_TOKEN=your_huggingface_token_here
   export CUDA_VISIBLE_DEVICES=0  # Optional: specify GPU(s)
   ```

2. **Download models and dependencies:**
   ```bash
   ./download_models.sh
   ```
   This script will:
   - Download all required models
   - Optionally pre-download flash_attn wheel for faster startup

3. **Run with Docker Compose:**
   ```bash
   docker-compose up
   ```

4. **Access the interface:**
   - Open http://localhost:7860 in your browser
   - Use the Advanced Settings for performance optimization

## Performance Optimizations

### Flash Attention
- **Automatic Installation**: flash_attn downloads automatically at container startup
- **Pre-cached Option**: Run `./download_models.sh` and choose "y" to pre-download the wheel
- **Cache Mount**: Use `-v $(pwd)/cache:/app/cache:ro` to mount the cached wheel

### Advanced Settings in UI
- **TeaCache**: Enable with threshold 0.14 for 3-4x speedup
- **Multi-GPU**: Set sp_size=2-8 for major performance boost
- **FSDP**: Reduces VRAM usage from 36GB to 14GB
- **Model Selection**: 1.3B model is much faster than 14B

## Performance Expectations

### Before Optimizations
- **Time**: 40 minutes on L40s GPU
- **VRAM**: 36GB required

### After Optimizations
- **Time**: 5-10 minutes (with TeaCache + multi-GPU)
- **VRAM**: 14GB (with FSDP)
- **1.3B Model**: 2-3 minutes

## Directory Structure

```
OmniAvatar/
├── pretrained_models/          # Auto-downloaded models
├── cache/                      # Optional: cached wheels
├── outputs/                    # Generated videos
└── examples/                   # Sample inputs
```

## Troubleshooting

### Flash Attention Issues
- Check container logs for installation status
- Ensure CUDA compatibility (requires CUDA 12.x)
- Performance will degrade gracefully if installation fails

### GPU Memory Issues
- Enable FSDP in Advanced Settings
- Use 1.3B model instead of 14B
- Reduce max_tokens setting