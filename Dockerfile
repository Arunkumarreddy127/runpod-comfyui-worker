FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04

ARG COMFYUI_VERSION=v0.34.0

ENV DEBIAN_FRONTEND=noninteractive \
	COMFY_HOME=/comfyui \
	VIRTUAL_ENV=/opt/venv \
	PATH=/opt/venv/bin:$PATH \
	PYTHONUNBUFFERED=1 \
	PIP_PREFER_BINARY=1

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		git \
		python3.12 \
		python3.12-venv \
		python3-pip \
		yq \
		ffmpeg \
		curl \
		libgl1 \
		libglib2.0-0 \
		wget \
	&& python3.12 -m venv "$VIRTUAL_ENV" \
	&& python -m pip install --upgrade pip setuptools wheel \
	&& python -m pip install --no-cache-dir \
		torch==2.11.0 torchvision==0.26.0 torchaudio==2.11.0 \
		--index-url https://download.pytorch.org/whl/cu128 \
	&& git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "$COMFY_HOME" \
	&& if [ "$COMFYUI_VERSION" != "latest" ]; then \
		cd "$COMFY_HOME" \
		&& git fetch --tags \
		&& git checkout "$COMFYUI_VERSION"; \
	fi \
	&& cd "$COMFY_HOME" \
	&& python -m pip install --no-cache-dir -r requirements.txt \
	&& python -m pip install --no-cache-dir huggingface_hub runpod requests websocket-client \
	&& git clone --depth 1 https://github.com/Arunkumarreddy127/comfy-bootstrap.git /tmp/comfy-bootstrap \
	&& cd /tmp/comfy-bootstrap \
	&& ./workflow install qwen-image-2.1 \
	&& rm -rf /tmp/comfy-bootstrap \
	&& apt-get purge -y --auto-remove git python3-pip \
	&& rm -rf /var/lib/apt/lists/*

COPY start.sh /start.sh
COPY handler.py /handler.py

RUN chmod +x /start.sh

WORKDIR /
CMD ["/start.sh"]