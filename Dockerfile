# Stage 1: Base image with common dependencies
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 as base

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1 

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
  python3.10 \
  python3-pip \
  git \
  wget

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Clone ComfyUI repository
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfyui

# Change working directory to ComfyUI
WORKDIR /comfyui

# Install ComfyUI dependencies
RUN pip3 install --upgrade --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 \
  && pip3 install --upgrade -r requirements.txt

# Install runpod
RUN pip3 install runpod requests

# Support for the network volume
ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Add the start and the handler
ADD src/start.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh

ARG HUGGINGFACE_ACCESS_TOKEN

# Change working directory to ComfyUI
WORKDIR /comfyui

# Clone and install custom nodes
RUN git clone https://github.com/cubiq/ComfyUI_InstantID.git custom_nodes/ComfyUI_InstantID
RUN pip3 install --upgrade -r custom_nodes/ComfyUI_InstantID/requirements.txt

# Download models
RUN wget -O models/checkpoints/albedobaseXL_v3Mini.safetensors https://civitai.com/api/download/models/892880 && \
  mkdir -p models/insightface/models/antelopev2 && \
  wget -O models/insightface/models/antelopev2/1k3d68.onnx https://huggingface.co/MonsterMMORPG/tools/resolve/main/1k3d68.onnx && \
  wget -O models/insightface/models/antelopev2/2d106det.onnx https://huggingface.co/MonsterMMORPG/tools/resolve/main/2d106det.onnx && \
  wget -O models/insightface/models/antelopev2/genderage.onnx https://huggingface.co/MonsterMMORPG/tools/resolve/main/genderage.onnx && \
  wget -O models/insightface/models/antelopev2/glintr100.onnx https://huggingface.co/MonsterMMORPG/tools/resolve/main/glintr100.onnx && \
  wget -O models/insightface/models/antelopev2/scrfd_10g_bnkps.onnx https://huggingface.co/MonsterMMORPG/tools/resolve/main/scrfd_10g_bnkps.onnx && \
  mkdir -p models/instantid/SDXL && \
  wget -O models/instantid/SDXL/ip-adapter.bin https://huggingface.co/InstantX/InstantID/resolve/main/ip-adapter.bin && \
  mkdir -p controlnet/SDXL/instantid && \
  wget -O controlnet/SDXL/instantid/diffusion_pytorch_model.safetensors https://huggingface.co/InstantX/InstantID/resolve/main/ControlNetModel/diffusion_pytorch_model.safetensors

# Start the container
CMD /start.sh