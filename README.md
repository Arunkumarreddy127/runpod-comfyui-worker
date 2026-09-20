# RunPod ComfyUI Worker

This repository is a minimal base verification worker for RunPod Serverless.
It uses the current official `runpod/worker-comfyui` image and does not add
custom nodes, models, Python packages, or application-specific logic.

## Dockerfile

The Dockerfile uses the pinned official `runpod/worker-comfyui:5.10.0-base`
image. This image provides the ComfyUI installation and the official RunPod
worker handler/runtime, so this repository only needs to select that base image.

The `-base` image is intentionally a clean ComfyUI installation without
pre-packaged models.

## Verification workflow

This repository is intentionally limited to verifying that:

1. RunPod can build the Docker image from GitHub.
2. The resulting Serverless worker starts correctly.
3. ComfyUI is available inside the worker.
4. A basic request can be submitted from Postman.
5. The worker can process a simple ComfyUI API workflow.

After pushing this repository to GitHub, use this sequence:

`GitHub repository` -> `RunPod Docker build` -> `Serverless endpoint` ->
`Postman` -> `basic ComfyUI workflow`

Do not add custom nodes or models during this base verification. They can be
introduced in a later, separate change after the worker and API path are known
to work.

## RunPod GitHub deployment settings

In RunPod, choose **Serverless** -> **New Endpoint** -> **Deploy from GitHub
Repository** and configure:

| Setting         | Value                                                                    |
| --------------- | ------------------------------------------------------------------------ |
| Repository      | Your GitHub repository, for example `your-account/runpod-comfyui-worker` |
| Branch          | `main`                                                                   |
| Context Path    | `/`                                                                      |
| Dockerfile Path | `Dockerfile`                                                             |

RunPod will build from the repository root and use the official worker runtime
provided by the base image. Configure the endpoint's GPU and worker settings
for the basic ComfyUI workflow you use for testing.

## Official references

- [Official worker repository](https://github.com/runpod-workers/worker-comfyui)
- [Customization guide](https://github.com/runpod-workers/worker-comfyui/blob/main/docs/customization.md)
- [Deployment guide](https://github.com/runpod-workers/worker-comfyui/blob/main/docs/deployment.md)
