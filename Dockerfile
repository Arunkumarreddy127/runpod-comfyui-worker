# Use the official RunPod ComfyUI worker with a clean ComfyUI installation.
FROM runpod/worker-comfyui:5.10.0-base

# Tell the bootstrap installer where the base image keeps ComfyUI.
ENV COMFY_HOME=/workspace/runpod-slim/ComfyUI

# Clone the bootstrap repository and install only the models declared by the
# z-image-turbo-fp8-aio workflow manifest - removed z-image folder.
RUN apt-get update \
	&& apt-get install -y --no-install-recommends git python3-pip yq \
	&& python3 -m pip install --no-cache-dir --break-system-packages huggingface_hub \
	&& git clone --depth 1 https://github.com/Arunkumarreddy127/comfy-bootstrap.git /tmp/comfy-bootstrap \
	&& cd /tmp/comfy-bootstrap \
	&& ./workflow install z-image-turbo-fp8-aio \
	&& rm -rf /tmp/comfy-bootstrap \
	&& apt-get purge -y --auto-remove git python3-pip \
	&& rm -rf /var/lib/apt/lists/*