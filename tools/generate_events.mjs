#!/usr/bin/env node
/**
 * Batch generate Bayeux Tapestry art for all 115+ events.
 * Processes in groups of 20 with ComfyUI restarts to avoid VRAM fill.
 * Uses 1536x640 for speed (2048x864 also works but takes 2x longer).
 */
import { cp, mkdir, readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { execSync } from 'node:child_process';

const COMFY = await import('./comfy.mjs');
const EVENTS = JSON.parse(await readFile('X:/viking/tools/gen-art/all_events.json', 'utf8'));
const OUT = 'assets/art/events';
const BATCH = 20;
const W = 1536, H = 640;

// Bayeux template
const T = (subject, latin) =>
  `archaeological photograph of an authentic 11th century bayeux tapestry section, ${subject}, embroidered wool thread texture, visible stitchwork, deteriorated faded muted colors on aged yellowed linen, uneven hand-stitched outlines, crude romanesque profile figures, decorative animal borders, horizontal narrative frieze, latin caption "${latin}" in crude stitched lettering, ancient textile artifact, museum documentation`;
const N = 'modern reproduction, clean, vibrant, cartoon, digital, painting, photorealistic, 3d, text, watermark, low quality';

// Quick Latin caption generator from English title
function toLatin(title) {
  const map = {
    'storm': 'TEMPESTAS', 'sea': 'MARE', 'ship': 'NAVIS', 'fire': 'IGNIS',
    'death': 'MORS', 'dead': 'MORTUUS', 'ghost': 'UMBRA', 'spirit': 'SPIRITUS',
    'war': 'BELLUM', 'battle': 'PROELIUM', 'feast': 'CONVIVIUM', 'trade': 'MERCATURA',
    'winter': 'HIEMS', 'summer': 'AESTAS', 'spring': 'VER', 'autumn': 'AUTUMNUS',
    'blood': 'SANGUIS', 'gold': 'AURUM', 'silver': 'ARGENTUM', 'iron': 'FERRUM',
    'land': 'TERRA', 'water': 'AQUA', 'wind': 'VENTUS', 'ice': 'GLACIES',
    'king': 'REX', 'warrior': 'BELLATOR', 'god': 'DEUS', 'gods': 'DEI',
    'dragon': 'DRACO', 'wolf': 'LUPUS', 'raven': 'CORVUS', 'eagle': 'AQUILA',
    'dream': 'SOMNIUM', 'omen': 'OMEN', 'curse': 'MALEDICTIO', 'blessing': 'BENEDICTIO',
  };
  const words = title.split(/\s+/);
  const latin = words.map(w => map[w.toLowerCase()] || w.toUpperCase()).join(' ');
  return 'DE ' + latin.slice(0, 40);
}

async function restartComfyUI() {
  try { execSync('taskkill //F //IM python.exe 2>nul', {stdio:'ignore'}); } catch {}
  await new Promise(r => setTimeout(r, 3000));
  execSync('start /b cmd /c "cd /d E:\\Krea2\\ComfyUI && set HIP_VISIBLE_DEVICES=0&& set HSA_OVERRIDE_GFX_VERSION=12.0.0&& set MIOPEN_FIND_MODE=FAST&& set PYTORCH_HIP_ALLOC_CONF=expandable_segments:True,garbage_collection_threshold:0.6&& E:\\Krea2\\venv\\Scripts\\python.exe main.py --use-pytorch-cross-attention --listen 127.0.0.1 --port 8188"', {stdio:'ignore'});
  await new Promise(r => setTimeout(r, 8000));
  for (let i=0; i<30; i++) {
    try { const res = await fetch('http://127.0.0.1:8188/'); if (res.ok) return; } catch {}
    await new Promise(r => setTimeout(r, 2000));
  }
  throw new Error('ComfyUI failed to start');
}

await mkdir(OUT, { recursive: true });

const todo = EVENTS.filter(e => !existsSync(`${OUT}/${e.id}.png`));
console.log(`${todo.length} events to generate (${EVENTS.length - todo.length} already done)`);

let generated = 0;
for (let i = 0; i < todo.length; i += BATCH) {
  const batch = todo.slice(i, i + BATCH);
  console.log(`\n=== Batch ${Math.floor(i/BATCH)+1}: ${i+1}-${Math.min(i+BATCH, todo.length)} of ${todo.length} ===`);

  if (i > 0) {
    process.stdout.write('Restarting ComfyUI... ');
    await restartComfyUI();
    console.log('ready');
  }

  for (const evt of batch) {
    const latin = toLatin(evt.title);
    const prompt = T(evt.title + ', viking norse scene', latin);
    process.stdout.write(`  ${evt.id}... `);
    try {
      const wf = COMFY.buildZImageWorkflow(prompt, {
        width: W, height: H, steps: 6, cfg: 1.0,
        sampler: 'er_sde', scheduler: 'simple', shift: 3, prefix: 'evt_' + evt.id
      });
      const pid = await COMFY.submitPrompt(wf);
      const r = await COMFY.waitForResult(pid, { maxWaitMs: 600000 });
      if (!r) { console.log('TIMEOUT'); continue; }
      const fn = typeof r === 'string' ? r : (r.filename || '');
      if (fn) { await cp('E:/Krea2/ComfyUI/output/' + fn, `${OUT}/${evt.id}.png`); console.log('OK'); generated++; }
      else console.log('NO_FILE');
    } catch(e) { console.log('FAIL: ' + e.message); }
  }
  console.log(`  Batch done: ${generated}/${todo.length} total`);
}

console.log(`\nDone! ${generated} events generated.`);
