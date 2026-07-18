/**
 * Minimal ComfyUI HTTP API client (replaces SwarmUI).
 *
 * Flow: POST /prompt (workflow JSON) -> poll GET /history/<prompt_id> -> copy image
 *
 * Env: COMFY_URL (default http://127.0.0.1:8188)
 *      COMFY_OUTPUT (default E:\Krea2\ComfyUI\output)
 */
import { copyFile } from 'node:fs/promises';
import { resolve as pathResolve } from 'node:path';

const COMFY_URL = (process.env.COMFY_URL ?? 'http://127.0.0.1:8188').replace(/\/+$/, '');
const COMFY_OUTPUT = process.env.COMFY_OUTPUT ?? String.raw`E:\Krea2\ComfyUI\output`;

// ---- Z-Image-Turbo workflow template ----
// Uses the BF16 model with our tuned settings: 6 steps, er_sde, simple, shift 3.
const ZIMAGE_UNET = 'z_image_turbo_bf16.safetensors';
const ZIMAGE_CLIP = 'qwen_3_4b_fp8_mixed.safetensors';
const ZIMAGE_CLIP_TYPE = 'lumina2';
const ZIMAGE_VAE = 'ae.safetensors';

/**
 * Build a Z-Image-Turbo ComfyUI API workflow payload.
 * The prompt text is injected into the CLIPTextEncode node.
 */
export function buildZImageWorkflow(prompt, opts = {}) {
  const {
    seed = -1,
    steps = 10,
    cfg = 1.0,
    sampler = 'er_sde',
    scheduler = 'simple',
    shift = 3,
    width = 1344,
    height = 768,
    prefix = 'viking',
  } = opts;

  const s = seed === -1 ? Math.floor(Math.random() * 0x7fffffff) : seed;

  return {
    '1': { class_type: 'UNETLoader', inputs: { unet_name: ZIMAGE_UNET, weight_dtype: 'default' } },
    '2': { class_type: 'CLIPLoader', inputs: { clip_name: ZIMAGE_CLIP, type: ZIMAGE_CLIP_TYPE } },
    '3': { class_type: 'VAELoader', inputs: { vae_name: ZIMAGE_VAE } },
    '4': { class_type: 'CLIPTextEncode', inputs: { text: prompt, clip: ['2', 0] } },
    '5': { class_type: 'ConditioningZeroOut', inputs: { conditioning: ['4', 0] } },
    '6': { class_type: 'EmptySD3LatentImage', inputs: { width, height, batch_size: 1 } },
    '7': { class_type: 'ModelSamplingAuraFlow', inputs: { model: ['1', 0], shift } },
    '8': { class_type: 'KSampler', inputs: { model: ['7', 0], positive: ['4', 0], negative: ['5', 0], latent_image: ['6', 0], seed: s, control_after_generate: 'fixed', steps, cfg, sampler_name: sampler, scheduler, denoise: 1.0 } },
    '9': { class_type: 'VAEDecode', inputs: { samples: ['8', 0], vae: ['3', 0] } },
    '10': { class_type: 'SaveImage', inputs: { images: ['9', 0], filename_prefix: prefix } },
  };
}

async function apiPost(route, body) {
  const res = await fetch(`${COMFY_URL}${route}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body ?? {}),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(`ComfyUI ${route} HTTP ${res.status}: ${text.slice(0, 200)}`);
  }
  return res.json();
}

/** Submit a workflow, return the prompt_id. */
export async function submitPrompt(workflow) {
  const json = await apiPost('/prompt', {
    client_id: 'viking-gen-art',
    prompt: workflow,
  });
  if (json.node_errors && Object.keys(json.node_errors).length) {
    throw new Error(`ComfyUI node errors: ${JSON.stringify(json.node_errors)}`);
  }
  if (!json.prompt_id) throw new Error('ComfyUI did not return a prompt_id');
  return json.prompt_id;
}

/** Poll /history/<prompt_id> until the result appears, return the output image filename. */
export async function waitForResult(promptId, { maxWaitMs = 90_000, pollMs = 2000 } = {}) {
  const deadline = Date.now() + maxWaitMs;
  while (Date.now() < deadline) {
    const res = await fetch(`${COMFY_URL}/history/${promptId}`);
    if (!res.ok) throw new Error(`ComfyUI history HTTP ${res.status}`);
    const json = await res.json();
    const entry = json?.[promptId];
    if (entry && entry.outputs) {
      for (const [nodeId, output] of Object.entries(entry.outputs)) {
        const images = output?.images;
        if (images?.length) {
          return { filename: images[0].filename, subfolder: images[0].subfolder ?? '' };
        }
      }
    }
    // Also check for errors
    if (entry?.status?.messages) {
      const errs = entry.status.messages.filter((m) => m[0] === 'error');
      if (errs.length) throw new Error(`ComfyUI execution error: ${errs.map((e) => e[1]).join('; ')}`);
    }
    await sleep(pollMs);
  }
  throw new Error(`Timed out waiting for prompt ${promptId} after ${maxWaitMs}ms`);
}

/** Copy a ComfyUI output image to a destination path. */
export async function copyImage(filename, destAbs) {
  const src = pathResolve(COMFY_OUTPUT, filename);
  await copyFile(src, destAbs);
  return destAbs;
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

/** Kill and restart the ComfyUI server. Returns when it's ready. */
export async function restartComfyUI() {
  const { execSync } = await import('node:child_process');

  // Kill running ComfyUI processes (only those with main.py)
  try {
    execSync(
      `powershell -Command "Get-WmiObject Win32_Process -Filter 'Name=\\'python.exe\\'' | Where-Object { \\$_.CommandLine -like '*main.py*' } | ForEach-Object { Stop-Process -Id \\$_.ProcessId -Force }"`,
      { stdio: 'pipe', timeout: 10_000 }
    );
  } catch { /* may fail if no ComfyUI running */ }

  await sleep(2000);

  // Start ComfyUI in background
  const { spawn } = await import('node:child_process');
  const comfyDir = String.raw`E:\Krea2\ComfyUI`;
  const venvActivate = String.raw`E:\Krea2\venv\Scripts\activate.bat`;

  const cmd = `call "${venvActivate}" && cd /d "${comfyDir}" && set HIP_VISIBLE_DEVICES=0 && set HSA_OVERRIDE_GFX_VERSION=12.0.0 && set MIOPEN_FIND_MODE=FAST && set PYTORCH_HIP_ALLOC_CONF=expandable_segments:True,garbage_collection_threshold:0.6,max_split_size_mb:512 && python main.py --use-pytorch-cross-attention --bf16-unet --lowvram --vram-headroom 2 --disable-smart-memory --listen 127.0.0.1`;

  spawn('cmd', ['/c', cmd], {
    detached: true,
    stdio: 'ignore',
    windowsHide: true,
  });

  // Wait for server to be ready (up to 30s)
  for (let i = 0; i < 15; i++) {
    await sleep(2000);
    try {
      const res = await fetch(`${COMFY_URL}/object_info`);
      if (res.ok) {
        const json = await res.json();
        if (json && Object.keys(json).length > 100) {
          return; // ready
        }
      }
    } catch { /* not ready yet */ }
  }
  throw new Error('ComfyUI did not become ready after restart');
}

export { COMFY_URL, COMFY_OUTPUT };
