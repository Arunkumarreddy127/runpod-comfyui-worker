# Network Volumes & Model Paths

This document explains how to use RunPod **Network Volumes** with `worker-comfyui`, how model paths are resolved inside the container, and how to debug cases where models are not detected.

> **Scope**
>
> These instructions apply to **serverless endpoints** using this worker. Pods mount network volumes at `/workspace` by default, while serverless workers see them at `/runpod-volume`.

## Directory Mapping

For **serverless endpoints**:

- Network volume root is mounted at: `/runpod-volume`
- ComfyUI models are expected under: `/runpod-volume/runpod-slim/ComfyUI/models/...`

For **Pods**:

- Network volume root is mounted at: `/workspace`
- ComfyUI model path: `/workspace/runpod-slim/ComfyUI/models/...`

If you use the S3-compatible API, the same paths map as:

- Serverless: `/runpod-volume/my-folder/file.txt`
- Pod: `/workspace/my-folder/file.txt`
- S3 API: `s3://<NETWORK_VOLUME_ID>/my-folder/file.txt`

## Expected Directory Structure

Models must be placed in the following structure on your network volume:

```text
/runpod-volume/
└── runpod-slim/
  └── ComfyUI/
    └── models/
      ├── checkpoints/      # Stable Diffusion checkpoints (.safetensors, .ckpt)
      ├── loras/            # LoRA files (.safetensors, .pt)
      ├── vae/              # VAE models (.safetensors, .pt)
      ├── clip/             # CLIP models (.safetensors, .pt)
      ├── clip_vision/      # CLIP Vision models
      ├── controlnet/       # ControlNet models (.safetensors, .pt)
      ├── diffusion_models/ # Diffusion/UNet models (.safetensors, .ckpt)
      ├── embeddings/       # Textual inversion embeddings (.safetensors, .pt)
      ├── upscale_models/   # Upscaling models (.safetensors, .pt)
      ├── text_encoders/    # CLIP/text encoder models (.safetensors, .bin)
      ├── unet/             # UNet models
      └── configs/           # Model configs (.yaml, .json)
```

> **Note**
>
> Only create the subdirectories you actually need; empty or missing folders are fine.

## Supported File Extensions

ComfyUI only recognizes files with specific extensions when scanning model directories.

| Model Type     | Supported Extensions                           |
| -------------- | ---------------------------------------------- |
| Checkpoints    | `.safetensors`, `.ckpt`, `.pt`, `.pth`, `.bin` |
| LoRAs          | `.safetensors`, `.pt`                          |
| VAE            | `.safetensors`, `.pt`, `.bin`                  |
| CLIP           | `.safetensors`, `.pt`, `.bin`                  |
| ControlNet     | `.safetensors`, `.pt`, `.pth`, `.bin`          |
| Embeddings     | `.safetensors`, `.pt`, `.bin`                  |
| Upscale Models | `.safetensors`, `.pt`, `.pth`                  |

Files with other extensions (for example `.txt`, `.zip`) are **ignored** by ComfyUI’s model discovery.

## MiniMax H3 model files

The MiniMax H3 worker image does not download these files during `docker build`.
Copy them to the following paths on the Network Volume:

| Network Volume path                                                                            | Download URL                                                                                                                               | Approximate size |
| ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | ---------------: |
| `runpod-slim/ComfyUI/models/diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors` | [Hugging Face](https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors) |          21.0 GB |
| `runpod-slim/ComfyUI/models/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors`        | [Hugging Face](https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors)        |          15.7 GB |
| `runpod-slim/ComfyUI/models/vae/minimax_h3_video_vae_fp16.safetensors`                         | [Hugging Face](https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_video_vae_fp16.safetensors)                         |           5.2 GB |
| `runpod-slim/ComfyUI/models/vae/minimax_h3_audio_vae_fp32.safetensors`                         | [Hugging Face](https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_audio_vae_fp32.safetensors)                         |          0.61 GB |

The total storage requirement is approximately **42.5 GB**. Populate the volume
using a temporary Pod, `wget`/`curl`, or the Network Volume S3-compatible API,
then attach that volume to the serverless endpoint under **Advanced > Select
Network Volume**. The volume must be in the same region as the endpoint.

## Common Issues

- **Wrong root directory**
  - Models placed under `/runpod-volume/models/...` instead of `/runpod-volume/runpod-slim/ComfyUI/models/...`.
- **Incorrect extensions**
  - Files named without one of the supported extensions are skipped.
- **Empty directories**
  - No actual model files present in `runpod-slim/ComfyUI/models/checkpoints` (or other folders).
- **Volume not attached**
  - Endpoint created without selecting a network volume under **Advanced → Select Network Volume**.

If any of the above is true, ComfyUI will silently fail to discover models from the network volume.

## Debugging with `NETWORK_VOLUME_DEBUG`

The worker exposes an opt‑in debug mode controlled via the `NETWORK_VOLUME_DEBUG` environment variable.

### When to Use

Enable this when:

- Models on your network volume are not appearing in ComfyUI
- You suspect the directory structure or file extensions are wrong
- You want to quickly verify what the worker can actually see on `/runpod-volume`

### How to Enable

1. Go to your serverless **Endpoint → Manage → Edit**.
2. Under **Environment Variables**, add:
   - `NETWORK_VOLUME_DEBUG=true`

3. Save and wait for workers to restart (or scale to zero and back up).
4. Send any request to your endpoint (even a minimal one) to trigger the diagnostics.

### Reading the Diagnostics

When enabled, each request prints a detailed report to the worker logs, for example:

```text
======================================================================
NETWORK VOLUME DIAGNOSTICS (NETWORK_VOLUME_DEBUG=true)
======================================================================

[1] Checking extra_model_paths.yaml configuration...
    ✓ FOUND: /comfyui/extra_model_paths.yaml

[2] Checking network volume mount at /runpod-volume...
    ✓ MOUNTED: /runpod-volume

[3] Checking directory structure...
    ✓ FOUND: /runpod-volume/runpod-slim/ComfyUI/models

[4] Scanning model directories...

    checkpoints/:
      - my-model.safetensors (6.5 GB)

    loras/:
      - style-lora.safetensors (144.2 MB)

[5] Summary
    ✓ Models found on network volume!
======================================================================
```

If there is a problem, the diagnostics will instead highlight it, for example:

- Missing `runpod-slim/ComfyUI/models/` directory
- No valid model files in any subdirectory
- Files present but ignored due to wrong extensions

### Disabling Debug Mode

Once you have resolved your issue, disable diagnostics to keep logs clean:

- Remove the `NETWORK_VOLUME_DEBUG` environment variable, **or**
- Set `NETWORK_VOLUME_DEBUG=false`

This returns the worker to normal behavior without extra log noise.
