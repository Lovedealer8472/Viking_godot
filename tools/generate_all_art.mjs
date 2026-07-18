#!/usr/bin/env node
/**
 * Full art regeneration — Act 2 (Sailing) + Act 3 (Landfall) scenes.
 * Darkest Dungeon / Banner Saga style, Z-Image-Turbo on ComfyUI.
 *
 * Generates 10 images per batch, restart ComfyUI between batches.
 * Usage: node tools/generate_all_art.mjs
 */

import { copyFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';

const COMFY = await import('./comfy.mjs');
const OUT_S = 'assets/art/scenes';
const OUT_E = 'assets/art/events';

const S = 'dark norse illustration, painterly concept art, strong chiaroscuro, deep shadows, muted earth tones, gold amber highlights, expressive linework, Banner Saga Darkest Dungeon art style, norse saga storybook quality';
const N = 'photorealistic, 3d render, glossy, anime, cartoon, bright, cheerful, text, watermark, signature, low quality, ugly, deformed';

// ═══════════════════════════════════════════════════════════════════════════
// Act 2: Sailing encounters
// ═══════════════════════════════════════════════════════════════════════════
const ACT2 = [
  ['storm_at_sea', 'Viking knarr in violent north atlantic storm, massive waves crashing over deck, crew struggling with ropes, lightning in dark clouds, rain lashing, dramatic, ' + S],
  ['doldrums', 'Viking knarr becalmed on flat grey sea, limp sail hanging, exhausted crew on deck, oppressive heat haze, endless flat horizon, despair, ' + S],
  ['sea_wight', 'Dark ocean depths beneath viking ship, colossal shadowy sea creature visible under the waves, phosphorescent glow, crew peering over rail in terror, supernatural dread, ' + S],
  ['leak', 'Interior of viking ship hull, seawater pouring through cracked plank, crew frantically bailing with buckets, lantern swinging, desperate survival, ' + S],
  ['whale_omen', 'Massive whale breaching alongside viking knarr, water cascading off its body, crew reaching out, grey mist, awe and wonder, ' + S],
  ['crew_dispute', 'Two viking crewmen fighting on ship deck, others holding them back, stormy sky, tension, dramatic lighting from single lantern, ' + S],
  ['iceberg', 'Viking knarr navigating through field of towering icebergs, narrow passage, blue-white ice walls, dangerous beauty, cold mist, ' + S],
  ['land_sighting', 'Viking crew at ship rail pointing at distant coastline emerging from morning fog, grey cliffs, first light of dawn, hope and relief, ' + S],
];

// ═══════════════════════════════════════════════════════════════════════════
// Act 3: Landfall & scouting
// ═══════════════════════════════════════════════════════════════════════════
const ACT3 = [
  ['scout_valley', 'Lush icelandic valley opening from black sand beach, green slopes, stream, distant snow-capped mountains, scouts with walking sticks, hopeful discovery, ' + S],
  ['scout_headland', 'Wind-swept coastal headland, viking scouts standing on cliff edge overlooking grey sea, driftwood on shore below, dramatic sky, ' + S],
  ['vaettir_contact', 'Viking settler leaving food offering on flat stone in misty icelandic landscape, raven watching from nearby rock, old spirits, sacred land, ' + S],
  ['fresh_water', 'Clear stream running from icelandic hills through volcanic rock, viking crew filling water casks, life-giving discovery, stark beauty, ' + S],
  ['old_ruin', 'Abandoned irish papar stone hut tucked into sheltered icelandic slope, viking explorer peering inside, small iron cross glinting, mystery, ' + S],
  ['landfall_beach', 'Viking knarr beached on black sand, crew wading ashore through surf carrying supplies, grey sky, mountains ahead, new beginning, ' + S],
];

const ALL = [...ACT2, ...ACT3];

// ═══════════════════════════════════════════════════════════════════════════

async function generateBatch(jobs, batchName) {
  console.log(`\n=== ${batchName} (${jobs.length} images) ===`);
  await mkdir(OUT_S, { recursive: true });
  await mkdir(OUT_E, { recursive: true });

  let ok = 0;
  for (const [id, prompt] of jobs) {
    const path = OUT_S + '/' + id + '.png';
    if (existsSync(path)) { console.log(`  SKIP ${id}`); ok++; continue; }
    process.stdout.write(`  ${id}... `);
    try {
      const wf = COMFY.buildZImageWorkflow(prompt, {
        width: 1024, height: 576, steps: 6, cfg: 1.0,
        sampler: 'er_sde', scheduler: 'simple', shift: 3, prefix: 'vka_' + id
      });
      const pid = await COMFY.submitPrompt(wf);
      const r = await COMFY.waitForResult(pid, { maxWaitMs: 300000 });
      if (!r) { console.log('TIMEOUT'); continue; }
      const fn = typeof r === 'string' ? r : (r.filename || '');
      if (fn) { await copyFile('E:/Krea2/ComfyUI/output/' + fn, path); console.log('OK'); ok++; }
      else console.log('NO_FILE');
    } catch(e) { console.log('FAIL: ' + e.message); }
  }
  console.log(`  ${batchName}: ${ok}/${jobs.length}`);
  return ok;
}

// Main — generate in batches
console.log('╔══════════════════════════════════════╗');
console.log('║  Full Art Regeneration              ║');
console.log('║  Z-Image-Turbo · Darkest Dungeon    ║');
console.log('╚══════════════════════════════════════╝');

const total = await generateBatch(ALL, 'Act 2+3 Scenes');
console.log(`\nDone! ${total}/${ALL.length} generated.`);
