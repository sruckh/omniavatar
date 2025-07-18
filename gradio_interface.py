import gradio as gr
import os
import sys
import subprocess
import shutil
from pathlib import Path
import tempfile

# Add the OmniAvatar directory to the Python path
sys.path.append("/app")

def check_models():
    """Check if required models are available"""
    model_paths = [
        "/app/pretrained_models/Wan2.1-T2V-14B",
        "/app/pretrained_models/OmniAvatar-14B", 
        "/app/pretrained_models/Wan2.1-T2V-1.3B",
        "/app/pretrained_models/OmniAvatar-1.3B",
        "/app/pretrained_models/wav2vec2-base-960h"
    ]
    
    missing_models = []
    for path in model_paths:
        if not os.path.exists(path):
            missing_models.append(path)
    
    return missing_models

def check_acceleration_status():
    """Check if acceleration libraries are available"""
    status = {}
    
    # Check Flash Attention
    try:
        import flash_attn
        status['flash_attn'] = f"✅ Flash Attention {flash_attn.__version__}"
    except ImportError:
        status['flash_attn'] = "❌ Flash Attention not available"
    
    # Check GPU info
    try:
        import torch
        gpu_count = torch.cuda.device_count()
        if gpu_count > 0:
            gpu_name = torch.cuda.get_device_name(0)
            gpu_memory = torch.cuda.get_device_properties(0).total_memory / 1024**3
            status['gpu'] = f"✅ {gpu_count}x {gpu_name} ({gpu_memory:.1f}GB)"
        else:
            status['gpu'] = "❌ No GPU detected"
    except:
        status['gpu'] = "❌ GPU check failed"
    
    return status

def generate_avatar_video(prompt, image_file, audio_file, model_size="14B", guidance_scale=4.5, audio_scale=3.0, num_steps=25, tea_cache_thresh=0.0, use_fsdp=False, max_tokens=30000, overlap_frame=13, sp_size=1, use_gradient_checkpointing=False):
    """Generate avatar video using OmniAvatar"""
    
    # Check if models are available
    missing_models = check_models()
    if missing_models:
        return None, f"Missing models: {', '.join(missing_models)}\nPlease ensure models are properly mounted and downloaded."
    
    # Validate overlap_frame (must be 1 + 4*n)
    if overlap_frame % 4 != 1:
        return None, f"Error: overlap_frame must be of form 1 + 4×n (like 1, 5, 9, 13, 17, 21, 25). Got: {overlap_frame}"
    
    try:
        # Create temporary directory for processing
        with tempfile.TemporaryDirectory() as temp_dir:
            # Copy uploaded files to temp directory
            if image_file is None:
                return None, "Please upload an image file"
            if audio_file is None:
                return None, "Please upload an audio file"
            
            image_path = os.path.join(temp_dir, "input_image.jpg")
            audio_path = os.path.join(temp_dir, "input_audio.wav")
            
            shutil.copy2(image_file, image_path)
            shutil.copy2(audio_file, audio_path)
            
            # Create input file for inference
            input_file = os.path.join(temp_dir, "input.txt")
            with open(input_file, "w") as f:
                f.write(f"{prompt}@@{image_path}@@{audio_path}")
            
            # Choose config based on model size
            config_file = f"/app/configs/inference{'_1.3B' if model_size == '1.3B' else ''}.yaml"
            
            # Build hyperparameters string
            hp_params = [
                f"guidance_scale={guidance_scale}",
                f"audio_scale={audio_scale}", 
                f"num_steps={num_steps}",
                f"max_tokens={max_tokens}",
                f"overlap_frame={overlap_frame}"
            ]
            
            if tea_cache_thresh > 0:
                hp_params.append(f"tea_cache_l1_thresh={tea_cache_thresh}")
            
            if use_fsdp:
                hp_params.append("use_fsdp=True")
                # Add memory optimization for FSDP
                if model_size == "14B":
                    hp_params.append("num_persistent_param_in_dit=7000000000")
            
            if sp_size > 1:
                hp_params.append(f"sp_size={sp_size}")
            
            if use_gradient_checkpointing:
                hp_params.append("use_gradient_checkpointing=True")
            
            # Run inference
            if sp_size == 1:
                # For single-GPU inference, use python directly with proper environment
                cmd = [
                    "python", "/app/scripts/inference.py",
                    "--config", config_file,
                    "--input_file", input_file,
                    "--hp", ",".join(hp_params)
                ]
                # Set environment variables for single-GPU inference
                env = os.environ.copy()
                env.update({
                    "RANK": "0",
                    "LOCAL_RANK": "0", 
                    "WORLD_SIZE": "1",
                    "NNODES": "1",
                    "CUDA_VISIBLE_DEVICES": env.get("CUDA_VISIBLE_DEVICES", "0"),
                    "MASTER_ADDR": "127.0.0.1",
                    "MASTER_PORT": "12345",
                    "NCCL_DEBUG": "WARN"  # Reduce NCCL verbosity
                })
            else:
                # For multi-GPU inference, use torchrun
                cmd = [
                    "torchrun", "--standalone", f"--nproc_per_node={sp_size}", 
                    "/app/scripts/inference.py",
                    "--config", config_file,
                    "--input_file", input_file,
                    "--hp", ",".join(hp_params)
                ]
                env = os.environ.copy()
            
            print(f"Running inference command: {' '.join(cmd)}")
            if sp_size == 1:
                print(f"Environment: RANK={env['RANK']}, LOCAL_RANK={env['LOCAL_RANK']}, WORLD_SIZE={env['WORLD_SIZE']}, CUDA_VISIBLE_DEVICES={env['CUDA_VISIBLE_DEVICES']}, MASTER_ADDR={env['MASTER_ADDR']}, MASTER_PORT={env['MASTER_PORT']}")
            result = subprocess.run(cmd, capture_output=True, text=True, cwd="/app", env=env)
            print(f"Inference stdout: {result.stdout}")
            if result.stderr:
                print(f"Inference stderr: {result.stderr}")
            
            if result.returncode != 0:
                return None, f"Error during inference:\n{result.stderr}"
            
            # Find output video in demo_out directory (matches inference script output)
            demo_out_dir = "/app/demo_out"
            if not os.path.exists(demo_out_dir):
                return None, "No demo_out directory found"
            
            # Search recursively for mp4 files
            video_files = list(Path(demo_out_dir).rglob("*.mp4"))
            
            if not video_files:
                return None, "No output video generated. Check logs for errors."
            
            # Return the most recent video file
            latest_video = max(video_files, key=os.path.getctime)
            
            # Copy to outputs directory for persistence
            output_dir = "/app/outputs"
            os.makedirs(output_dir, exist_ok=True)
            output_path = os.path.join(output_dir, f"generated_{os.path.basename(latest_video)}")
            shutil.copy2(latest_video, output_path)
            
            return str(output_path), "Video generated successfully!"
            
    except Exception as e:
        return None, f"Error: {str(e)}"

def create_interface():
    """Create the Gradio interface"""
    import logging
    logger = logging.getLogger(__name__)
    
    try:
        logger.info("Initializing Gradio interface components...")
        
        # Check system status
        logger.info("Checking system status...")
        missing_models = check_models()
        if missing_models:
            logger.warning(f"Missing models: {missing_models}")
        
        accel_status = check_acceleration_status()
        logger.info(f"Acceleration status: {accel_status}")
        
    except Exception as e:
        logger.error(f"Error during interface initialization: {e}", exc_info=True)
        # Continue anyway to show the interface
    
    with gr.Blocks(title="OmniAvatar - Audio-Driven Avatar Generator") as demo:
        gr.HTML("""
        <div style="text-align: center; margin-bottom: 20px;">
            <h1>🎭 OmniAvatar</h1>
            <p>Efficient Audio-Driven Avatar Video Generation with Adaptive Body Animation</p>
        </div>
        """)
        
        # Check model availability on startup
        missing_models = check_models()
        accel_status = check_acceleration_status()
        
        if missing_models:
            gr.HTML(f"""
            <div style="background-color: #ffebee; padding: 10px; border-radius: 5px; margin-bottom: 20px;">
                <strong>⚠️ Warning:</strong> Missing models detected:<br>
                {', '.join(missing_models)}<br>
                Please ensure models are properly mounted and downloaded.
            </div>
            """)
        
        # Show acceleration status
        gr.HTML(f"""
        <div style="background-color: #f5f5f5; padding: 10px; border-radius: 5px; margin-bottom: 20px; font-family: monospace; font-size: 12px;">
            <strong>🚀 Acceleration Status:</strong><br>
            {accel_status['flash_attn']}<br>
            {accel_status['gpu']}
        </div>
        """)
        
        with gr.Row():
            with gr.Column(scale=1):
                gr.HTML("<h3>📝 Input</h3>")
                prompt = gr.Textbox(
                    label="Prompt",
                    placeholder="[Description of first frame] - [Description of human behavior] - [Description of background (optional)]",
                    lines=3,
                    value="A person with a warm smile - talking and gesturing naturally - modern office background"
                )
                image_file = gr.File(label="Input Image", file_types=[".jpg", ".jpeg", ".png"])
                audio_file = gr.File(label="Input Audio", file_types=[".wav", ".mp3"])
                
                gr.HTML("<h3>⚙️ Settings</h3>")
                model_size = gr.Dropdown(
                    choices=["14B", "1.3B"],
                    value="14B",
                    label="Model Size"
                )
                guidance_scale = gr.Slider(
                    minimum=1.0,
                    maximum=10.0,
                    value=4.5,
                    step=0.1,
                    label="Guidance Scale"
                )
                audio_scale = gr.Slider(
                    minimum=1.0,
                    maximum=10.0,
                    value=3.0,
                    step=0.1,
                    label="Audio Scale"
                )
                num_steps = gr.Slider(
                    minimum=10,
                    maximum=100,
                    value=25,
                    step=1,
                    label="Number of Steps"
                )
                
                with gr.Accordion("🔧 Advanced Settings", open=False):
                    tea_cache_thresh = gr.Slider(
                        minimum=0.0,
                        maximum=0.2,
                        value=0.0,
                        step=0.01,
                        label="TeaCache Threshold (0=disabled, 0.05-0.15 recommended for speed)"
                    )
                    use_fsdp = gr.Checkbox(
                        value=False,
                        label="Use FSDP (reduces VRAM usage)"
                    )
                    max_tokens = gr.Slider(
                        minimum=10000,
                        maximum=80000,
                        value=30000,
                        step=10000,
                        label="Max Tokens (higher = longer videos but more VRAM)"
                    )
                    overlap_frame = gr.Dropdown(
                        choices=[1, 5, 9, 13, 17, 21, 25],
                        value=13,
                        label="Overlap Frame (must be 1 + 4×n, affects coherence)"
                    )
                    sp_size = gr.Slider(
                        minimum=1,
                        maximum=8,
                        value=1,
                        step=1,
                        label="Sequence Parallel Size (multi-GPU: 2-8 for major speedup)"
                    )
                    use_gradient_checkpointing = gr.Checkbox(
                        value=False,
                        label="Use Gradient Checkpointing (saves memory)"
                    )
                
                generate_btn = gr.Button("🎬 Generate Avatar Video", variant="primary")
                
            with gr.Column(scale=1):
                gr.HTML("<h3>🎥 Output</h3>")
                output_video = gr.Video(label="Generated Video")
                status_text = gr.Textbox(label="Status", lines=5)
                
                gr.HTML("<h3>📋 Prompt Structure Guide</h3>")
                gr.HTML("""
                <div style="background-color: #f8f9fa; padding: 15px; border-radius: 8px; margin-bottom: 15px; border-left: 4px solid #007bff;">
                    <strong>✍️ Recommended Prompt Format:</strong><br>
                    <code>[Description of first frame] - [Description of human behavior] - [Description of background (optional)]</code>
                    <br><br>
                    <strong>📝 Guidelines:</strong>
                    <ul style="margin: 10px 0; padding-left: 20px;">
                        <li><strong>First frame:</strong> Describe the person's appearance, pose, clothing</li>
                        <li><strong>Behavior:</strong> Describe how they speak, gesture, move</li>
                        <li><strong>Background:</strong> Optional scene description for context</li>
                        <li><strong>Style:</strong> Use clear, descriptive language</li>
                        <li><strong>Focus:</strong> Emphasize visible hands and facial expressions</li>
                    </ul>
                </div>
                """)
                
                gr.HTML("<h3>💡 Example Prompts</h3>")
                
                # Create example prompts following the guidelines
                example_prompts = [
                    "A professional woman in business attire sitting at a desk - speaking confidently with expressive hand gestures - modern office background",
                    "A young man with casual clothing standing upright - talking enthusiastically with animated hand movements - clean studio background", 
                    "An elderly gentleman in a sweater seated comfortably - speaking warmly with gentle hand gestures - cozy living room setting",
                    "A teacher in front of a whiteboard - explaining concepts with clear pointing gestures - classroom environment",
                    "A chef in white uniform holding utensils - describing cooking techniques with demonstrative hand motions - kitchen background",
                    "A fitness instructor in athletic wear - motivating with energetic gestures and expressions - gym setting",
                    "A news anchor in formal attire at a desk - delivering news with professional hand movements - news studio background",
                    "A doctor in medical coat with stethoscope - explaining medical information with reassuring gestures - clinical office setting",
                    "A musician holding an instrument - discussing music with passionate hand expressions - recording studio background",
                    "A presenter in smart casual attire - engaging audience with dynamic gestures and facial expressions - conference room setting"
                ]
                
                example_dropdown = gr.Dropdown(
                    choices=example_prompts,
                    label="Select an Example Prompt",
                    value=None,
                    interactive=True
                )
        
        # Event handlers
        def update_prompt(selected_example):
            if selected_example:
                return selected_example
            return gr.update()
        
        example_dropdown.change(
            fn=update_prompt,
            inputs=[example_dropdown],
            outputs=[prompt]
        )
        
        generate_btn.click(
            fn=generate_avatar_video,
            inputs=[prompt, image_file, audio_file, model_size, guidance_scale, audio_scale, num_steps, tea_cache_thresh, use_fsdp, max_tokens, overlap_frame, sp_size, use_gradient_checkpointing],
            outputs=[output_video, status_text]
        )
        
        gr.HTML("""
        <div style="margin-top: 20px; text-align: center; color: #666;">
            <p>💡 Tips:</p>
            <ul style="text-align: left; max-width: 600px; margin: 0 auto;">
                <li>Recommended guidance scale: 4-6</li>
                <li>Recommended audio scale: 3-5 for better lip-sync</li>
                <li>More steps = higher quality but slower generation</li>
                <li>Use clear, front-facing photos for best results</li>
                <li><strong>Performance Tips:</strong></li>
                <li>• Enable TeaCache (0.14) for 3-4x speed boost</li>
                <li>• Use FSDP to reduce VRAM usage (36GB → 14GB)</li>
                <li>• <strong>Multi-GPU:</strong> Set sp_size=2-8 for major speedup (4x faster!)</li>
                <li>• Lower num_steps (20-25) for faster generation</li>
                <li>• 1.3B model is much faster than 14B</li>
                <li>• Flash Attention auto-enabled if available</li>
            </ul>
        </div>
        """)
    
    return demo

if __name__ == "__main__":
    import argparse
    import logging
    
    # Set up logging
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
    logger = logging.getLogger(__name__)
    
    try:
        parser = argparse.ArgumentParser(description="OmniAvatar Gradio Interface")
        parser.add_argument("--share", action="store_true", help="Create a public Gradio link")
        parser.add_argument("--port", type=int, default=7860, help="Port to run the interface on")
        args = parser.parse_args()
        
        # Also check environment variable for share option
        share = args.share or os.getenv("GRADIO_SHARE", "false").lower() == "true"
        
        logger.info("Creating Gradio interface...")
        demo = create_interface()
        logger.info(f"Launching interface on port {args.port}, share={share}")
        
        demo.launch(
            server_name="0.0.0.0", 
            server_port=args.port, 
            share=share,
            show_error=True,
            debug=True
        )
    except Exception as e:
        logger.error(f"Failed to start Gradio interface: {e}", exc_info=True)
        raise