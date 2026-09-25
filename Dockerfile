FROM runpod/worker-comfyui:5.10.0-base

# Tell the bootstrap installer where the base image keeps ComfyUI.
ENV COMFY_HOME=/comfyui

# Clone the bootstrap repository and install the MiniMax H3 models and nodes
# declared by its workflow manifest.
RUN apt-get update \
	&& apt-get install -y --no-install-recommends git python3-pip yq \
	&& python3 -m pip install --no-cache-dir --break-system-packages huggingface_hub \
	&& git clone --depth 1 https://github.com/Arunkumarreddy127/comfy-bootstrap.git /tmp/comfy-bootstrap \
	&& cd /tmp/comfy-bootstrap \
	&& ./workflow install minimax-h3 \
	&& rm -rf /tmp/comfy-bootstrap \
	&& apt-get purge -y --auto-remove git python3-pip \
	&& rm -rf /var/lib/apt/lists/*