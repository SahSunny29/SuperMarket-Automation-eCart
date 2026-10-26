#!/usr/bin/env python3
# ==============================================================================
# Smart Shopping Cart Edge Controller - Camera Node Asset Downloader
# Purpose: Downloads ONNX Runtime Web client assets (ort.min.js, WASM binaries)
#          and quantized YOLOv8n ONNX model to enable offline USB serving from
#          the Raspberry Pi to mounted camera smartphones without internet.
# ==============================================================================

import argparse
import logging
import os
import sys
import urllib.request
import urllib.error

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("AssetDownloader")

ORT_VERSION = "1.18.0"
BASE_CDN = f"https://cdn.jsdelivr.net/npm/onnxruntime-web@{ORT_VERSION}/dist"

RUNTIME_FILES = {
    "ort.min.js": f"{BASE_CDN}/ort.min.js",
    "ort-wasm-simd.wasm": f"{BASE_CDN}/ort-wasm-simd.wasm",
    "ort-wasm-simd-threaded.wasm": f"{BASE_CDN}/ort-wasm-simd-threaded.wasm",
    "ort-wasm.wasm": f"{BASE_CDN}/ort-wasm.wasm",
}

# Standard official YOLOv8n ONNX model asset URL
MODEL_URLS = [
    "https://github.com/ultralytics/assets/releases/download/v8.2.0/yolov8n.onnx",
    "https://github.com/ultralytics/assets/releases/download/v8.1.0/yolov8n.onnx",
    "https://huggingface.co/arnabdhar/YOLOv8-Nano-ONNX/resolve/main/model.onnx",
]


def download_file(url: str, dest_path: str, timeout: int = 30) -> bool:
    """Download a file with progress indicators and error handling."""
    logger.info(f"Downloading: {url} -> {dest_path}")
    os.makedirs(os.path.dirname(os.path.abspath(dest_path)), exist_ok=True)

    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "Mozilla/5.0 (SmartCart-EdgeController/1.0)"},
        )
        with urllib.request.urlopen(req, timeout=timeout) as response:
            total_size = int(response.headers.get("Content-Length", 0))
            chunk_size = 64 * 1024
            downloaded = 0

            with open(dest_path, "wb") as f:
                while True:
                    chunk = response.read(chunk_size)
                    if not chunk:
                        break
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total_size > 0:
                        pct = (downloaded / total_size) * 100
                        mb_down = downloaded / (1024 * 1024)
                        mb_total = total_size / (1024 * 1024)
                        sys.stdout.write(f"\r  Progress: {pct:5.1f}% ({mb_down:.2f}/{mb_total:.2f} MB)")
                        sys.stdout.flush()

            sys.stdout.write("\n")
            logger.info(f"Successfully saved ({os.path.getsize(dest_path):,} bytes).")
            return True

    except urllib.error.URLError as err:
        sys.stdout.write("\n")
        logger.warning(f"Network error downloading {url}: {err.reason}")
        return False
    except Exception as err:
        sys.stdout.write("\n")
        logger.error(f"Unexpected error downloading {url}: {err}")
        return False


def download_runtime(camera_node_dir: str) -> bool:
    """Download ONNX Runtime Web JS and WASM files into camera_node/."""
    logger.info("=== Fetching ONNX Runtime Web Client Assets ===")
    success_count = 0

    for filename, url in RUNTIME_FILES.items():
        dest = os.path.join(camera_node_dir, filename)
        if os.path.exists(dest) and os.path.getsize(dest) > 1000:
            logger.info(f"File '{filename}' already exists ({os.path.getsize(dest):,} bytes). Skipping.")
            success_count += 1
            continue

        if download_file(url, dest):
            success_count += 1

    return success_count > 0


def download_model(models_dir: str) -> bool:
    """Download quantized YOLOv8n ONNX model into camera_node/models/."""
    logger.info("=== Fetching YOLOv8n Quantized ONNX Model ===")
    dest = os.path.join(models_dir, "yolov8n_quantized.onnx")

    if os.path.exists(dest) and os.path.getsize(dest) > 100_000:
        logger.info(f"Model already exists at {dest} ({os.path.getsize(dest):,} bytes). Skipping.")
        return True

    for url in MODEL_URLS:
        logger.info(f"Attempting model download from: {url}")
        if download_file(url, dest, timeout=60):
            logger.info("Model download complete.")
            return True

    logger.warning("All online model URLs failed or offline.")
    logger.info(
        "Note: The camera node will automatically engage its high-speed "
        "Motion-Fallback centroid tracker when no .onnx model is present."
    )
    return False


def main():
    parser = argparse.ArgumentParser(description="Download assets for Camera Node offline USB serving.")
    parser.add_argument("--runtime-only", action="store_true", help="Download only ONNX Runtime JS/WASM.")
    parser.add_argument("--model-only", action="store_true", help="Download only the YOLOv8n ONNX model.")
    args = parser.parse_args()

    # Determine directories relative to this script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    # script_dir is Backend/Pi-Backend/camera_node/models
    models_dir = script_dir
    camera_node_dir = os.path.abspath(os.path.join(script_dir, ".."))

    logger.info(f"Camera Node Root: {camera_node_dir}")
    logger.info(f"Models Directory: {models_dir}")

    fetch_runtime = not args.model_only
    fetch_model = not args.runtime_only

    runtime_ok = True
    model_ok = True

    if fetch_runtime:
        runtime_ok = download_runtime(camera_node_dir)

    if fetch_model:
        model_ok = download_model(models_dir)

    logger.info("==================================================")
    if runtime_ok and model_ok:
        logger.info("All requested offline assets are ready.")
    else:
        logger.info("Asset download finished with partial or fallback status.")
    logger.info("==================================================")


if __name__ == "__main__":
    main()
