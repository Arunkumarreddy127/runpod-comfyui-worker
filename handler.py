import base64
import json
import os
import time
import uuid
from pathlib import Path

import requests
import runpod
import websocket


COMFY_URL = os.getenv("COMFY_URL", "http://127.0.0.1:8188")
COMFY_WS = COMFY_URL.replace("http://", "ws://").replace("https://", "wss://")
OUTPUT_DIR = Path("/comfyui/output")


def upload_images(images):
    for image in images or []:
        image_data = image["image"]
        if "," in image_data:
            image_data = image_data.split(",", 1)[1]
        response = requests.post(
            f"{COMFY_URL}/upload/image",
            files={
                "image": (
                    image["name"],
                    base64.b64decode(image_data),
                    "application/octet-stream",
                ),
                "overwrite": (None, "true"),
            },
            timeout=60,
        )
        response.raise_for_status()


def queue_workflow(workflow, client_id):
    response = requests.post(
        f"{COMFY_URL}/prompt",
        json={"prompt": workflow, "client_id": client_id},
        timeout=60,
    )
    response.raise_for_status()
    payload = response.json()
    if "prompt_id" not in payload:
        raise RuntimeError(f"ComfyUI did not return a prompt ID: {payload}")
    return payload["prompt_id"]


def wait_for_completion(ws, prompt_id):
    try:
        while True:
            message = ws.recv()
            if not isinstance(message, str):
                continue
            event = json.loads(message)
            data = event.get("data", {})
            if event.get("type") == "execution_error" and data.get("prompt_id") == prompt_id:
                raise RuntimeError(data.get("exception_message", "ComfyUI execution failed"))
            if (
                event.get("type") == "executing"
                and data.get("prompt_id") == prompt_id
                and data.get("node") is None
            ):
                return
    finally:
        ws.close()


def get_outputs(prompt_id):
    for _ in range(60):
        response = requests.get(f"{COMFY_URL}/history/{prompt_id}", timeout=30)
        response.raise_for_status()
        history = response.json().get(prompt_id)
        if history is not None:
            return history.get("outputs", {})
        time.sleep(1)
    raise TimeoutError(f"Timed out waiting for history for prompt {prompt_id}")


def encode_outputs(outputs):
    result = []
    for node_output in outputs.values():
        for image in node_output.get("images", []):
            if image.get("type") == "temp":
                continue
            response = requests.get(
                f"{COMFY_URL}/view",
                params={
                    "filename": image["filename"],
                    "subfolder": image.get("subfolder", ""),
                    "type": image.get("type", "output"),
                },
                timeout=120,
            )
            response.raise_for_status()
            result.append(
                {
                    "filename": image["filename"],
                    "type": "base64",
                    "data": base64.b64encode(response.content).decode("ascii"),
                }
            )
    return result


def handler(job):
    job_input = job.get("input") or {}
    workflow = job_input.get("workflow")
    if not isinstance(workflow, dict):
        return {"error": "input.workflow must be an API-format workflow object"}

    try:
        upload_images(job_input.get("images"))
        client_id = str(uuid.uuid4())
        ws = websocket.create_connection(
            f"{COMFY_WS}/ws?clientId={client_id}", timeout=30
        )
        try:
            prompt_id = queue_workflow(workflow, client_id)
            wait_for_completion(ws, prompt_id)
        finally:
            ws.close()
        return {"images": encode_outputs(get_outputs(prompt_id))}
    except Exception as error:
        return {"error": str(error)}


if __name__ == "__main__":
    runpod.serverless.start({"handler": handler})
