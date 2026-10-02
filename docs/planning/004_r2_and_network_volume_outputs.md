# User Story: Upload Generated Images to R2 and Optionally Save to a Network Volume

**Goal:** Upload generated images to Cloudflare R2 using the existing S3-compatible worker configuration, always return base64 image data in the API response, and optionally save a local copy to the mounted network volume.

**Current State:**

- `handler.py` chooses either an S3 URL or base64 output.
- The existing `BUCKET_*` variables and `rp_upload.upload_image` helper provide S3-compatible uploads.
- The worker can read models from `/runpod-volume`, but generated image persistence to that volume is not configurable.

**Desired State:**

- Every generated image response includes:
  - `filename`
  - `type: "base64"`
  - `data` containing the base64 image data
  - `r2_url` when the R2 upload succeeds
- R2 upload is an additional side effect and does not replace base64 output.
- Local network-volume saving is disabled by default and enabled with:

  ```text
  SAVE_OUTPUTS_TO_NETWORK_VOLUME=true
  ```

- Local output files are stored under an isolated job directory such as:

  ```text
  /runpod-volume/runpod-slim/ComfyUI/output/<job_id>/
  ```

- R2 upload failures and local-write failures are reported through the existing `errors` output without discarding successfully encoded base64 data.

## Tasks

1. **Add configurable local output persistence**
   - Parse `SAVE_OUTPUTS_TO_NETWORK_VOLUME` as a case-insensitive boolean, defaulting to `false`.
   - Save generated image bytes only when the flag is enabled.
   - Preserve valid nested output subfolders where appropriate.
   - Prevent absolute paths and `..` traversal from escaping the job output directory.
   - Keep local persistence independent from R2 configuration.

2. **Extend generated-image processing**
   - Retrieve image bytes once from ComfyUI's `/view` endpoint.
   - Save a local copy when enabled.
   - Always base64-encode the bytes for the API response.

- When `BUCKET_ENDPOINT_URL` is configured, upload a temporary copy with `rp_upload.upload_image(f"images/{job_id}", temp_file_path)` so objects are stored under `images/<job_id>/`.
- Add the returned upload URL as `r2_url` on the corresponding image response item.
- Clean up temporary upload files in all success and failure paths.

3. **Document configuration**
   - Document `SAVE_OUTPUTS_TO_NETWORK_VOLUME` and its `false` default in `docs/configuration.md`.
   - Document Cloudflare R2 setup using the existing S3-compatible variables:
     - `BUCKET_ENDPOINT_URL`: the R2 S3 API endpoint
     - `BUCKET_ACCESS_KEY_ID`: an R2 access key ID
     - `BUCKET_SECRET_ACCESS_KEY`: the matching R2 secret
   - Clarify that R2 URLs are returned in addition to base64 data.
   - Document the network-volume output directory and the requirement that the volume be mounted at `/runpod-volume`.

4. **Add focused tests**
   - Verify local saving is disabled when the environment variable is unset or false.
   - Verify enabled saving writes the expected bytes to the job-scoped output directory.
   - Verify unsafe filenames and subfolders cannot escape the output root.
   - Verify R2 upload and local saving can happen together.
   - Verify the response contains base64 data and `r2_url` after a successful R2 upload.
   - Verify base64 data remains in the response when R2 is not configured or upload fails.
   - Verify local-write failures are reported without suppressing successful image output.
   - Mock R2 and filesystem operations so tests do not require credentials or a mounted volume.

## Validation

- Run the focused handler tests:

  ```bash
  .venv/bin/python -m unittest tests.test_handler
  ```

- Run the broader worker test suite after the focused tests pass.
- Manually verify both values of `SAVE_OUTPUTS_TO_NETWORK_VOLUME` with the `/runpod-volume` mount in `docker-compose.yml`.
- Build deployment images with `--platform linux/amd64`.

## Decisions

- Reuse the existing generic S3-compatible upload path for Cloudflare R2; no separate R2 client is required.
- Base64 remains the stable API response format regardless of R2 configuration.
- `r2_url` is optional and appears only after a successful upload.
- Local network-volume persistence is opt-in and does not alter the API response.
- Model downloading and model-path configuration are outside this change.
