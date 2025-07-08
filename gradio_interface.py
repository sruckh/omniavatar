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

def generate_avatar_video(prompt, image_file, audio_file, model_size="14B", guidance_scale=4.5, audio_scale=3.0, num_steps=25):
    """Generate avatar video using OmniAvatar"""
    
    # Check if models are available
    missing_models = check_models()
    if missing_models:
        return None, f"Missing models: {', '.join(missing_models)}\nPlease ensure models are properly mounted and downloaded."
    
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
            
            # Run inference
            cmd = [
                "torchrun", "--standalone", "--nproc_per_node=1", 
                "/app/scripts/inference.py",
                "--config", config_file,
                "--input_file", input_file,
                "--hp", f"guidance_scale={guidance_scale},audio_scale={audio_scale},num_steps={num_steps}"
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, cwd="/app")
            
            if result.returncode != 0:
                return None, f"Error during inference:\n{result.stderr}"
            
            # Find output video (this may need adjustment based on actual output location)
            output_dir = "/app/outputs"
            video_files = list(Path(output_dir).glob("*.mp4"))
            
            if not video_files:
                return None, "No output video generated"
            
            # Return the most recent video file
            latest_video = max(video_files, key=os.path.getctime)
            return str(latest_video), "Video generated successfully!"
            
    except Exception as e:
        return None, f"Error: {str(e)}"

def create_interface():
    """Create the Gradio interface"""
    
    with gr.Blocks(title="OmniAvatar - Audio-Driven Avatar Generator") as demo:
        gr.HTML("""
        <div style="text-align: center; margin-bottom: 20px;">
            <h1>🎭 OmniAvatar</h1>
            <p>Efficient Audio-Driven Avatar Video Generation with Adaptive Body Animation</p>
        </div>
        """)
        
        # Check model availability on startup
        missing_models = check_models()
        if missing_models:
            gr.HTML(f"""
            <div style="background-color: #ffebee; padding: 10px; border-radius: 5px; margin-bottom: 20px;">
                <strong>⚠️ Warning:</strong> Missing models detected:<br>
                {', '.join(missing_models)}<br>
                Please ensure models are properly mounted and downloaded.
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
                
                generate_btn = gr.Button("🎬 Generate Avatar Video", variant="primary")
                
            with gr.Column(scale=1):
                gr.HTML("<h3>🎥 Output</h3>")
                output_video = gr.Video(label="Generated Video")
                status_text = gr.Textbox(label="Status", lines=5)
        
        # Event handlers
        generate_btn.click(
            fn=generate_avatar_video,
            inputs=[prompt, image_file, audio_file, model_size, guidance_scale, audio_scale, num_steps],
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
            </ul>
        </div>
        """)
    
    return demo

if __name__ == "__main__":
    demo = create_interface()
    demo.launch(server_name="0.0.0.0", server_port=7860, share=False)