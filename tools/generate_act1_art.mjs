#!/usr/bin/env node
/**
 * generate_act1_art.mjs — Viking Saga Godot: Act 1 art generator.
 *
 * Standalone ComfyUI pipeline for the Godot port. Uses Z-Image-Turbo BF16
 * with the same tuned settings as the browser game's gen-art pipeline, but
 * with a Darkest Dungeon / Banner Saga painterly style.
 *
 * Generates:
 *   - 3 scene backgrounds at 1344×768  → assets/art/scenes/
 *   - 7 character portraits at 768×1344 → assets/art/characters/
 *
 * Usage:
 *   node tools/generate_act1_art.mjs                        # generate everything
 *   node tools/generate_act1_art.mjs --dry-run               # print prompts only
 *   node tools/generate_act1_art.mjs --seed 42               # reproducible seed
 *   node tools/generate_act1_art.mjs --scene fjord           # single scene
 *   node tools/generate_act1_art.mjs --character bjorn       # single portrait
 *   node tools/generate_act1_art.mjs --retry                  # retry failed only
 *
 * Env:
 *   COMFY_URL    ComfyUI server URL  (default http://127.0.0.1:8188)
 *   COMFY_OUTPUT ComfyUI output dir  (default E:\Krea2\ComfyUI\output)
 */

import { copyFile, mkdir, access, readFile, writeFile } from 'node:fs/promises';
import { constants } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

// ─────────────────────────────────────────────────────────────────────────────
// Paths
// ─────────────────────────────────────────────────────────────────────────────

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');
const SCENES_DIR = resolve(ROOT, 'assets/art/scenes');
const CHARACTERS_DIR = resolve(ROOT, 'assets/art/characters');
const FAILED_LOG = resolve(__dirname, '.failed_act1.json');

// ─────────────────────────────────────────────────────────────────────────────
// ComfyUI client (adapted from X:\viking\tools\gen-art\comfy.mjs)
// ─────────────────────────────────────────────────────────────────────────────

const COMFY_URL = (process.env.COMFY_URL ?? 'http://127.0.0.1:8188').replace(/\/+$/, '');
const COMFY_OUTPUT = process.env.COMFY_OUTPUT ?? String.raw`E:\Krea2\ComfyUI\output`;

// Z-Image-Turbo model identifiers
const ZIMAGE_UNET = 'z_image_turbo_bf16.safetensors';
const ZIMAGE_CLIP = 'qwen_3_4b_fp8_mixed.safetensors';
const ZIMAGE_CLIP_TYPE = 'lumina2';
const ZIMAGE_VAE = 'ae.safetensors';

/**
 * Build a Z-Image-Turbo ComfyUI API workflow payload.
 * Mirrors the shape from the browser game's comfy.mjs.
 */
function buildZImageWorkflow(prompt, opts = {}) {
  const {
    seed = -1,
    steps = 6,
    cfg = 1.0,
    sampler = 'er_sde',
    scheduler = 'simple',
    shift = 3,
    width = 1344,
    height = 768,
    prefix = 'viking_godot',
  } = opts;

  const s = seed === -1 ? Math.floor(Math.random() * 0x7fffffff) : seed;

  return {
    '1':  { class_type: 'UNETLoader',     inputs: { unet_name: ZIMAGE_UNET, weight_dtype: 'default' } },
    '2':  { class_type: 'CLIPLoader',     inputs: { clip_name: ZIMAGE_CLIP, type: ZIMAGE_CLIP_TYPE } },
    '3':  { class_type: 'VAELoader',      inputs: { vae_name: ZIMAGE_VAE } },
    '4':  { class_type: 'CLIPTextEncode', inputs: { text: prompt, clip: ['2', 0] } },
    '5':  { class_type: 'ConditioningZeroOut', inputs: { conditioning: ['4', 0] } },
    '6':  { class_type: 'EmptySD3LatentImage', inputs: { width, height, batch_size: 1 } },
    '7':  { class_type: 'ModelSamplingAuraFlow', inputs: { model: ['1', 0], shift } },
    '8':  { class_type: 'KSampler',       inputs: { model: ['7', 0], positive: ['4', 0], negative: ['5', 0], latent_image: ['6', 0], seed: s, control_after_generate: 'fixed', steps, cfg, sampler_name: sampler, scheduler, denoise: 1.0 } },
    '9':  { class_type: 'VAEDecode',      inputs: { samples: ['8', 0], vae: ['3', 0] } },
    '10': { class_type: 'SaveImage',      inputs: { images: ['9', 0], filename_prefix: prefix } },
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

async function submitPrompt(workflow) {
  const json = await apiPost('/prompt', {
    client_id: 'viking-godot-art',
    prompt: workflow,
  });
  if (json.node_errors && Object.keys(json.node_errors).length) {
    throw new Error(`ComfyUI node errors: ${JSON.stringify(json.node_errors)}`);
  }
  if (!json.prompt_id) throw new Error('ComfyUI did not return a prompt_id');
  return json.prompt_id;
}

async function waitForResult(promptId, { maxWaitMs = 90_000, pollMs = 2000 } = {}) {
  const deadline = Date.now() + maxWaitMs;
  while (Date.now() < deadline) {
    const res = await fetch(`${COMFY_URL}/history/${promptId}`);
    if (!res.ok) throw new Error(`ComfyUI history HTTP ${res.status}`);
    const json = await res.json();
    const entry = json?.[promptId];
    if (entry && entry.outputs) {
      for (const output of Object.values(entry.outputs)) {
        const images = output?.images;
        if (images?.length) {
          return { filename: images[0].filename, subfolder: images[0].subfolder ?? '' };
        }
      }
    }
    if (entry?.status?.messages) {
      const errs = entry.status.messages.filter((m) => m[0] === 'error');
      if (errs.length) throw new Error(`ComfyUI execution error: ${errs.map((e) => e[1]).join('; ')}`);
    }
    await sleep(pollMs);
  }
  throw new Error(`Timed out waiting for prompt ${promptId} after ${maxWaitMs}ms`);
}

async function copyComfyImage(filename, destAbs) {
  const src = resolve(COMFY_OUTPUT, filename);
  await copyFile(src, destAbs);
  return destAbs;
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

// ─────────────────────────────────────────────────────────────────────────────
// Darkest Dungeon / Banner Saga style prompt template
// ─────────────────────────────────────────────────────────────────────────────

const STYLE_PREFIX =
  'dark hand-drawn norse illustration, painterly concept art, strong chiaroscuro lighting, ' +
  'deep shadows, muted earth tones with gold highlights, expressive linework, atmospheric, ' +
  'storybook quality, banner saga darkest dungeon art style';

const STYLE_SUFFIX =
  'painterly texture, ink wash details, subtle vignette, norse saga illustration, ' +
  'aged parchment feel, dramatic composition';

const NEGATIVE_PROMPT =
  'photorealistic, 3d render, glossy, smooth, digital art, anime, cartoon, ' +
  'bright, cheerful, modern, text, watermark, signature';

function buildPositive(subject) {
  return `${STYLE_PREFIX}. DOMINANT SCENE: ${subject}. ${STYLE_SUFFIX}.`;
}

// ─────────────────────────────────────────────────────────────────────────────
// Act 1 art catalogue
// ─────────────────────────────────────────────────────────────────────────────

const SCENES = {
  fjord: {
    label: 'Fjord Background',
    subject:
      'A vast norwegian fjord at dusk, steep misty cliffs plunging into dark water, ' +
      'a single viking knarr ship with striped sail moored at a wooden dock, ' +
      'snow-capped mountains receding into low cloud, calm water reflecting the fading sky, ' +
      'small figures on the dock, 8th century norway, epic scale',
  },
  hall_interior: {
    label: 'Hall Interior',
    subject:
      'Interior of a viking longhouse at feasting time, central stone fire pit casting ' +
      'warm golden light on timber walls hung with round shields and spears, ' +
      'long tables with wooden cups and platters, smoke drifting to roof vents, ' +
      'benches with cloaked figures, carved dragon-head pillars, deep shadows in corners, ' +
      'intimate torchlit atmosphere',
  },
  ship_deck: {
    label: 'Ship Deck',
    subject:
      'Close view of a viking knarr ship deck, coiled ropes and cargo barrels, ' +
      'tall mast with furled striped sail, oars stowed along sides, ' +
      'figurehead of a snarling dragon prow in foreground, ' +
      'open sea and grey sky beyond the gunwale, spray on wooden planks, ' +
      'sense of journey and distant horizon',
  },
};

const CHARACTERS = {
  eirik: {
    label: 'Eirik — Chieftain',
    subject:
      'Portrait of Eirik, a weathered norse chieftain, mid-40s, long braided auburn hair and full beard, ' +
      'deep thoughtful eyes, high cheekbones, wearing a woollen tunic under a leather jerkin with a ' +
      'silver Thor\'s hammer pendant, fur cloak over one shoulder, standing against a misty fjord backdrop, ' +
      'stern but wise expression, strong chiaroscuro lighting from one side',
  },
  sigrid: {
    label: 'Sigrid — Shieldmaiden',
    subject:
      'Portrait of Sigrid, a fierce young shieldmaiden, 20s, braided blonde hair threaded with leather ' +
      'straps, sharp piercing blue eyes, scar on one cheekbone, wearing ring mail over a woollen kirtle, ' +
      'round shield visible over her shoulder, standing on a wind-swept cliff edge with sea behind, ' +
      'defiant determined expression, dramatic side lighting',
  },
  bjorn: {
    label: 'Bjorn — Berserker',
    subject:
      'Portrait of Bjorn, a massive norse berserker, late 30s, wild unkempt dark hair and tangled beard ' +
      'streaked with grey, scarred weathered face, intense wild eyes, wearing a bearskin over simple tunic, ' +
      'gripping a bearded axe handle visible at his side, shadowed forest background, ' +
      'primal fierce energy, deep shadows carving his features',
  },
  astrid: {
    label: 'Astrid — Seeress',
    subject:
      'Portrait of Astrid, a norse völva seeress, indeterminate age 40s-50s, long silver-grey hair ' +
      'falling loose, pale blue eyes with distant knowing gaze, high sharp cheekbones, wearing ' +
      'a dark hooded cloak with embroidered runic symbols at the hem, a carved staff over her shoulder, ' +
      'standing in swirling mist, mysterious otherworldly atmosphere, soft ethereal lighting',
  },
  torsten: {
    label: 'Torsten — Ship Captain',
    subject:
      'Portrait of Torsten, a seasoned knarr captain, 50s, short grey-white hair and close-cropped ' +
      'beard, sun-weathered leathery skin, squinting sea-grey eyes, friendly weathered face with ' +
      'crow\'s feet, wearing a thick woollen maritime tunic and sealskin vest, coiled rope over shoulder, ' +
      'standing on dock with ship visible behind, warm approachable expression, natural daylight',
  },
  helga: {
    label: 'Helga — Healer',
    subject:
      'Portrait of Helga, a kind-faced norse healer, 30s, chestnut hair pulled back in a practical ' +
      'bun with loose wisps, warm brown eyes, gentle smile, wearing a simple linen shift under a ' +
      'woollen apron dress, leather pouch at her belt with dried herbs, holding a small clay pot, ' +
      'standing in a sunlit meadow with longhouse behind, soft warm lighting, nurturing presence',
  },
  leif: {
    label: 'Leif — Scout',
    subject:
      'Portrait of Leif, a lean young norse scout, late teens, short sandy hair, keen alert eyes, ' +
      'boyish features with a hint of stubble, wearing leather tunic and fur-lined cloak, ' +
      'short bow slung across back, standing on a forested hillside at dawn, ' +
      'curious watchful expression, mist rising from valley below, cool morning light',
  },
};

// ─────────────────────────────────────────────────────────────────────────────
// CLI argument parsing
// ─────────────────────────────────────────────────────────────────────────────

function parseArgs(argv) {
  const args = {
    scenes: [],
    characters: [],
    allScenes: false,
    allCharacters: false,
    dryRun: false,
    retry: false,
    seed: -1,
  };

  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--dry-run' || a === '--dryrun') {
      args.dryRun = true;
    } else if (a === '--retry') {
      args.retry = true;
    } else if (a === '--seed') {
      args.seed = Number(argv[++i]);
    } else if (a === '--scene') {
      args.scenes.push(argv[++i]);
    } else if (a === '--character') {
      args.characters.push(argv[++i]);
    } else if (a.startsWith('--')) {
      throw new Error(`Unknown flag: ${a}`);
    }
  }

  // If no specific items requested, generate everything
  if (args.scenes.length === 0 && args.characters.length === 0 && !args.retry) {
    args.allScenes = true;
    args.allCharacters = true;
  } else {
    if (args.scenes.length === 0) args.allScenes = true;
    if (args.characters.length === 0) args.allCharacters = true;
  }

  return args;
}

function resolveItems(args) {
  const items = [];

  if (args.allScenes) {
    for (const [id, scene] of Object.entries(SCENES)) {
      items.push({
        id,
        type: 'scene',
        outDir: SCENES_DIR,
        filename: `${id}.png`,
        prompt: buildPositive(scene.subject),
        width: 1344,
        height: 768,
      });
    }
  } else {
    for (const id of args.scenes) {
      if (!SCENES[id]) throw new Error(`Unknown scene: ${id}. Known: ${Object.keys(SCENES).join(', ')}`);
      items.push({
        id,
        type: 'scene',
        outDir: SCENES_DIR,
        filename: `${id}.png`,
        prompt: buildPositive(SCENES[id].subject),
        width: 1344,
        height: 768,
      });
    }
  }

  if (args.allCharacters) {
    for (const [id, ch] of Object.entries(CHARACTERS)) {
      items.push({
        id,
        type: 'portrait',
        outDir: CHARACTERS_DIR,
        filename: `${id}.png`,
        prompt: buildPositive(ch.subject),
        width: 768,
        height: 1344,
      });
    }
  } else {
    for (const id of args.characters) {
      if (!CHARACTERS[id]) throw new Error(`Unknown character: ${id}. Known: ${Object.keys(CHARACTERS).join(', ')}`);
      items.push({
        id,
        type: 'portrait',
        outDir: CHARACTERS_DIR,
        filename: `${id}.png`,
        prompt: buildPositive(CHARACTERS[id].subject),
        width: 768,
        height: 1344,
      });
    }
  }

  return items;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

async function exists(p) {
  try { await access(p, constants.F_OK); return true; } catch { return false; }
}

function loadFailedLog() {
  return readFile(FAILED_LOG, 'utf-8').then(JSON.parse).catch(() => ({}));
}

function saveFailedLog(data) {
  return writeFile(FAILED_LOG, JSON.stringify(data, null, 2));
}

const PER_ITEM_SETTINGS = {
  steps: 6,
  cfg: 1.0,
  sampler: 'er_sde',
  scheduler: 'simple',
  shift: 3,
};

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  const args = parseArgs(process.argv.slice(2));

  const items = args.retry
    ? await loadRetryItems()
    : resolveItems(args);

  if (!items.length) {
    console.log('Nothing to generate.');
    return;
  }

  if (args.dryRun) {
    console.log(`Dry run — ${items.length} items:\n`);
    for (const item of items) {
      const size = `${item.width}×${item.height}`;
      const kind = item.type === 'scene' ? 'SCENE' : 'PORTRAIT';
      console.log(`  [${kind}] ${item.id}  ${size}  ->  assets/art/${item.type === 'scene' ? 'scenes' : 'characters'}/${item.filename}`);
      console.log(`    +: ${item.prompt}`);
      console.log(`    -: ${NEGATIVE_PROMPT}`);
      console.log();
    }
    return;
  }

  await mkdir(SCENES_DIR, { recursive: true });
  await mkdir(CHARACTERS_DIR, { recursive: true });

  console.log(`ComfyUI: ${COMFY_URL}`);
  console.log(`Output scenes:   ${SCENES_DIR}`);
  console.log(`Output portraits: ${CHARACTERS_DIR}`);
  console.log(`Settings: ${PER_ITEM_SETTINGS.steps} steps, ${PER_ITEM_SETTINGS.sampler}/${PER_ITEM_SETTINGS.scheduler}, shift ${PER_ITEM_SETTINGS.shift}, CFG ${PER_ITEM_SETTINGS.cfg}`);
  console.log(`Total items: ${items.length}`);
  console.log();

  let ok = 0;
  const failed = [];
  const MAX_RETRIES = 1;

  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    const sizeLabel = `${item.width}×${item.height}`;
    const kind = item.type === 'scene' ? 'scene' : 'portrait';
    const dest = resolve(item.outDir, item.filename);

    // Skip if already exists
    if (await exists(dest)) {
      console.log(`  [${i + 1}/${items.length}] ${kind} ${item.id} — already exists, skipping`);
      ok++;
      continue;
    }

    let saved = false;
    for (let attempt = 0; attempt <= MAX_RETRIES && !saved; attempt++) {
      const tag = attempt > 0 ? `[retry ${attempt}] ` : '';
      process.stdout.write(`  [${i + 1}/${items.length}] ${tag}${kind} ${item.id} (${sizeLabel}) ... `);

      try {
        const workflow = buildZImageWorkflow(item.prompt, {
          ...PER_ITEM_SETTINGS,
          width: item.width,
          height: item.height,
          seed: args.seed,
          prefix: `vg_${item.id}`,
        });
        const promptId = await submitPrompt(workflow);
        const result = await waitForResult(promptId);
        await copyComfyImage(result.filename, dest);
        console.log(`saved -> ${item.type === 'scene' ? 'scenes' : 'characters'}/${item.filename}`);
        ok++;
        saved = true;
      } catch (err) {
        if (attempt < MAX_RETRIES) {
          console.log('retrying after restart');
          try {
            await restartComfyUI();
          } catch (restartErr) {
            console.error(`  restart failed: ${restartErr.message}`);
          }
        } else {
          console.log('FAILED');
          console.error(`  ${err.message}`);
          failed.push(item.id);
        }
      }
    }
  }

  // Save failed items for --retry
  if (failed.length) {
    const existing = await loadFailedLog();
    existing.failed = [...new Set([...(existing.failed || []), ...failed])];
    await saveFailedLog(existing);
  } else {
    // Clear failed log on clean run
    await saveFailedLog({});
  }

  console.log(`\nDone: ${ok}/${items.length} generated.`);
  if (failed.length) {
    console.log(`Failed (${failed.length}): ${failed.join(', ')}`);
    console.log('Re-run with: node tools/generate_act1_art.mjs --retry');
  }
  if (ok < items.length) process.exit(1);

  // ── Sub-function for retry mode ──
  async function loadRetryItems() {
    const log = await loadFailedLog();
    const ids = log.failed || [];
    if (!ids.length) {
      console.log('No failed items to retry.');
      return [];
    }

    const sceneIds = ids.filter((id) => SCENES[id]);
    const charIds = ids.filter((id) => CHARACTERS[id]);

    const items = [];
    for (const id of sceneIds) {
      items.push({
        id,
        type: 'scene',
        outDir: SCENES_DIR,
        filename: `${id}.png`,
        prompt: buildPositive(SCENES[id].subject),
        width: 1344,
        height: 768,
      });
    }
    for (const id of charIds) {
      items.push({
        id,
        type: 'portrait',
        outDir: CHARACTERS_DIR,
        filename: `${id}.png`,
        prompt: buildPositive(CHARACTERS[id].subject),
        width: 768,
        height: 1344,
      });
    }

    console.log(`Retrying ${items.length} previously failed items`);
    return items;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Restart ComfyUI (extracted from browser game's comfy.mjs)
// ─────────────────────────────────────────────────────────────────────────────

async function restartComfyUI() {
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

// ─────────────────────────────────────────────────────────────────────────────
// Entry
// ─────────────────────────────────────────────────────────────────────────────

main().catch((err) => {
  console.error(`\nFatal: ${err.message}`);
  process.exit(1);
});
