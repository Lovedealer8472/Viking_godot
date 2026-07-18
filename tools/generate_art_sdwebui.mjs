#!/usr/bin/env node
/**
 * Generate Act 1 art using Stable Diffusion WebUI API (DirectML).
 * Requires SD WebUI running at http://127.0.0.1:7860 with --api flag.
 *
 * Usage: node tools/generate_art_sdwebui.mjs
 */
import { mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';

const API = 'http://127.0.0.1:7860';

// Darkest Dungeon / Banner Saga style
const STYLE = "dark atmospheric norse illustration, painterly concept art, strong chiaroscuro lighting, deep shadows, muted earth tones with gold and amber highlights, hand-drawn, Banner Saga game art style, Darkest Dungeon aesthetic, norse saga illustration, storybook quality, textured brushwork, dramatic composition";
const NEG = "photorealistic, 3d render, glossy, anime, cartoon, bright, cheerful, text, watermark, signature, low quality, blurry";

const JOBS = [
  // Scenes — landscape 1344×768
  { id: 'fjord', path: 'assets/art/scenes/fjord.png', w: 1344, h: 768,
    prompt: `cinematic wide landscape of a norwegian fjord, misty mountains, dark grey-green water, viking knarr ship at wooden dock, overcast sky, ${STYLE}` },
  { id: 'hall', path: 'assets/art/scenes/hall.png', w: 1344, h: 768,
    prompt: `viking longhouse interior, central fire pit with glowing embers, timber walls with round shields, smoke rising to rafters, warm firelight, long wooden tables with furs, ${STYLE}` },
  { id: 'ship_deck', path: 'assets/art/scenes/ship_deck.png', w: 1344, h: 768,
    prompt: `viking knarr ship deck, low angle looking toward carved dragon prow, rough weathered planks, furled sail, rigging, stormy grey sky, dark sea with whitecaps, ${STYLE}` },

  // Characters — portrait 768×1344
  { id: 'leader', path: 'assets/art/characters/leader.png', w: 768, h: 1344,
    prompt: `portrait of a norse leader, 32, bearded, weathered face, fur-trimmed cloak, standing at ship tiller, dramatic side lighting, ${STYLE}` },
  { id: 'bjarne', path: 'assets/art/characters/bjarne.png', w: 768, h: 1344,
    prompt: `portrait of a norse fighter, broad-shouldered, diagonal scar on face, bearded axe at belt, leather and ringmail armor, intense eyes, ${STYLE}` },
  { id: 'ragna', path: 'assets/art/characters/ragna.png', w: 768, h: 1344,
    prompt: `portrait of a norse working woman, 35, strong arms, braided hair, wool apron dress, weathered dignified face, warm firelight, ${STYLE}` },
  { id: 'einar', path: 'assets/art/characters/einar.png', w: 768, h: 1344,
    prompt: `portrait of a norse scholar, 40, thin gaunt face, piercing pale eyes, grey-streaked hair, clutching rune-sticks, dark wool robe, harsh overhead light, ${STYLE}` },
  { id: 'brynja', path: 'assets/art/characters/brynja.png', w: 768, h: 1344,
    prompt: `portrait of a norse craftswoman, 26, leather apron, tools at belt, soot-stained hands, braided hair, keen intelligent gaze, ${STYLE}` },
  { id: 'leif', path: 'assets/art/characters/leif.png', w: 768, h: 1344,
    prompt: `portrait of a norse scout, 24, lean build, restless alert eyes, short bow over shoulder, hooded cloak, cold blue-grey lighting, ${STYLE}` },
  { id: 'jarl', path: 'assets/art/characters/jarl.png', w: 768, h: 1344,
    prompt: `portrait of a 14-year-old norse apprentice boy, eager eyes, too-large wool tunic, hopeful expression, warm lighting from below, ${STYLE}` },
];

async function generate(job) {
  if (existsSync(job.path)) {
    console.log(`  SKIP ${job.id} — already exists`);
    return;
  }
  console.log(`  Generating ${job.id} (${job.w}×${job.h})...`);
  const res = await fetch(`${API}/sdapi/v1/txt2img`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      prompt: job.prompt,
      negative_prompt: NEG,
      width: job.w, height: job.h,
      steps: 25, cfg_scale: 7,
      sampler_name: 'DPM++ 2M SDE',
    }),
  });
  const data = await res.json();
  if (data.error) { console.error(`  FAIL ${job.id}: ${data.error}`); return; }
  const b64 = data.images[0];
  const buf = Buffer.from(b64, 'base64');
  await mkdir(import.meta.dirname + '/../../' + job.path.replace(/[^/]+$/, ''), { recursive: true });
  const { writeFileSync } = await import('node:fs');
  writeFileSync(job.path, buf);
  console.log(`  ✓ ${job.id}`);
}

// Check if WebUI is running
try {
  await fetch(`${API}/sdapi/v1/sd-models`);
} catch {
  console.error('ERROR: SD WebUI not running at', API);
  console.error('Start it with: cd X:\\viking-godot\\sd-webui && webui-user.bat');
  process.exit(1);
}

console.log('SD WebUI connected. Generating 10 images...\n');
await mkdir('assets/art/scenes', { recursive: true });
await mkdir('assets/art/characters', { recursive: true });

for (const job of JOBS) {
  await generate(job);
}

console.log('\nDone!');
