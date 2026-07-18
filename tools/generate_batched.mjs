#!/usr/bin/env node
/**
 * Batched art generator — restarts ComfyUI between each image to avoid VRAM fill.
 * The Last Kingdom aesthetic: gritty historical realism, dark low fantasy.
 */
import { copyFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { execSync } from 'node:child_process';

const COMFY = await import('./comfy.mjs');
const S = 'gritty historical realism, overcast grey sky, cold damp, muddy ground, worn patched undyed wool, roughspun textiles, desaturated muted colors, the last kingdom aesthetic, dark low fantasy';
const N = 'heroic fantasy, epic, golden hour, beautiful, glamorous, shiny armor, colorful, saturated, clean, perfect, muscular, hollywood vikings, cosplay, text, watermark, low quality, ugly';

const JOBS = [
  ['fjord','assets/art/scenes/fjord.png',1024,576,'Bleak norwegian fjord, grey sky, cold dark water, small weathered knarr at rough wooden dock, muddy shore, mist'],
  ['hall','assets/art/scenes/hall.png',1024,576,'Dark cramped turf longhouse, small smoky fire, rough timber, patched blankets, wooden benches, dirt floor, cold damp poverty'],
  ['ship','assets/art/scenes/ship_deck.png',1024,576,'Cramped wet deck of small weathered knarr, rough planks, patched grey sail, coiled rope, grey sea, overcast, cold spray'],
  ['leader','assets/art/characters/leader.png',512,896,'Weathered thin norse settler, tired gaunt face, patched undyed wool tunic, worn cloak, standing in cold rain, grey overcast, documentary portrait'],
  ['bjarne','assets/art/characters/bjarne.png',512,896,'Rough norse fighter, gaunt scarred face, patched leather over wool, hand on weathered axe, cold rain, tired eyes'],
  ['ragna','assets/art/characters/ragna.png',512,896,'Weather-beaten norse woman, practical braided hair, patched wool apron dress, tired dignified face, cold grey light'],
  ['einar','assets/art/characters/einar.png',512,896,'Thin gaunt norse scholar, hollow cheeks, grey-streaked hair, clutching bundle of rune sticks, frayed dark wool robe, harsh grey light'],
  ['brynja','assets/art/characters/brynja.png',512,896,'Norse craftswoman, soot-stained hands, worn leather apron, patched wool tunic, practical tired face, cold workshop light'],
  ['leif','assets/art/characters/leif.png',512,896,'Lean tired norse scout, wind-burned face, patched hooded cloak, simple short bow, cold grey-blue overcast light'],
  ['jarl','assets/art/characters/jarl.png',512,896,'Thin norse boy, too-large patched wool tunic, tangled hair, hopeful tired eyes, cold grey light, documentary portrait'],
];

async function restartComfyUI() {
  try { execSync('taskkill //F //IM python.exe 2>nul', {stdio: 'ignore'}); } catch {}
  await new Promise(r => setTimeout(r, 3000));
  execSync('start /b cmd /c "cd /d E:\\Krea2\\ComfyUI && set HIP_VISIBLE_DEVICES=0&& set HSA_OVERRIDE_GFX_VERSION=12.0.0&& set MIOPEN_FIND_MODE=FAST&& set PYTORCH_HIP_ALLOC_CONF=expandable_segments:True,garbage_collection_threshold:0.6&& E:\\Krea2\\venv\\Scripts\\python.exe main.py --use-pytorch-cross-attention --listen 127.0.0.1 --port 8188"', {stdio: 'ignore'});
  await new Promise(r => setTimeout(r, 8000));
  let tries = 0;
  while (tries < 10) {
    try { const res = await fetch('http://127.0.0.1:8188/'); if (res.ok) return; } catch {}
    await new Promise(r => setTimeout(r, 2000));
    tries++;
  }
  throw new Error('ComfyUI failed to start');
}

await mkdir('assets/art/scenes', {recursive: true});
await mkdir('assets/art/characters', {recursive: true});

let done = 0;
for (const [id, path, w, h, prompt] of JOBS) {
  if (existsSync(path)) { console.log(`SKIP ${id}`); done++; continue; }

  console.log(`\n=== ${id} (${done+1}/${JOBS.length}) — restarting ComfyUI ===`);
  await restartComfyUI();
  process.stdout.write(`${id}... `);

  try {
    const wf = COMFY.buildZImageWorkflow(`${prompt}, ${S}`, {
      width: w, height: h, steps: 6, cfg: 1.0,
      sampler: 'er_sde', scheduler: 'simple', shift: 3, prefix: 'vglk_' + id
    });
    const pid = await COMFY.submitPrompt(wf);
    const r = await COMFY.waitForResult(pid, { maxWaitMs: 300000 });
    if (!r) { console.log('TIMEOUT'); continue; }
    const fn = typeof r === 'string' ? r : (r.filename || '');
    if (fn) { await copyFile('E:/Krea2/ComfyUI/output/' + fn, path); console.log('OK'); done++; }
    else console.log('NO_FILE');
  } catch(e) { console.log('FAIL: ' + e.message); }
}

console.log(`\nDone: ${done}/${JOBS.length}`);
