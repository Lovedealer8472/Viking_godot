#!/usr/bin/env node
/**
 * Generate Act 1 art using Replicate cloud API.
 * Costs ~$0.20/image × 10 = ~$2 total (SDXL, 25 steps).
 *
 * Setup: Set REPLICATE_API_TOKEN env var or paste token below.
 * Usage: node tools/generate_art_cloud.mjs
 */
import Replicate from 'replicate';
import { writeFileSync, existsSync } from 'node:fs';
import { mkdir } from 'node:fs/promises';

const TOKEN = process.env.REPLICATE_API_TOKEN;
if (!TOKEN) {
  console.error('Set REPLICATE_API_TOKEN. Get one at https://replicate.com/account/api-tokens');
  process.exit(1);
}

const replicate = new Replicate({ auth: TOKEN });

const STYLE = "dark atmospheric norse illustration, painterly concept art, strong chiaroscuro, deep shadows, muted earth tones, gold highlights, Banner Saga meets Darkest Dungeon art style, norse saga illustration";
const NEG = "photorealistic, 3d, glossy, anime, cartoon, bright, cheerful, text, watermark, signature, low quality";

const JOBS = [
  { id: 'fjord', path: 'assets/art/scenes/fjord.png', w: 1344, h: 768,
    prompt: `cinematic wide landscape of a norwegian fjord at dusk, misty mountains, still water, viking knarr ship at wooden dock, overcast sky, ${STYLE}` },
  { id: 'hall', path: 'assets/art/scenes/hall.png', w: 1344, h: 768,
    prompt: `viking longhouse interior, central fire pit, round shields on timber walls, smoke rising, long tables, warm firelight, ${STYLE}` },
  { id: 'ship_deck', path: 'assets/art/scenes/ship_deck.png', w: 1344, h: 768,
    prompt: `viking knarr ship deck, low dramatic angle, carved dragon prow, weathered planks, furled sail, stormy grey sky, dark sea, ${STYLE}` },
  { id: 'leader', path: 'assets/art/characters/leader.png', w: 768, h: 1344,
    prompt: `portrait of norse leader, 32, bearded, weathered, fur-trimmed cloak, ship tiller, dramatic side light, ${STYLE}` },
  { id: 'bjarne', path: 'assets/art/characters/bjarne.png', w: 768, h: 1344,
    prompt: `portrait of norse fighter, broad shoulders, facial scar, bearded axe, leather armor, intense eyes, ${STYLE}` },
  { id: 'ragna', path: 'assets/art/characters/ragna.png', w: 768, h: 1344,
    prompt: `portrait of norse working woman, strong, braided hair, wool dress, weathered face, warm light, ${STYLE}` },
  { id: 'einar', path: 'assets/art/characters/einar.png', w: 768, h: 1344,
    prompt: `portrait of norse scholar, thin gaunt, pale intense eyes, grey hair, rune-sticks, dark robe, harsh overhead light, ${STYLE}` },
  { id: 'brynja', path: 'assets/art/characters/brynja.png', w: 768, h: 1344,
    prompt: `portrait of norse craftswoman, leather apron, tools, soot-stained hands, keen gaze, ${STYLE}` },
  { id: 'leif', path: 'assets/art/characters/leif.png', w: 768, h: 1344,
    prompt: `portrait of norse scout, lean, alert eyes, short bow, hooded cloak, cold grey-blue light, ${STYLE}` },
  { id: 'jarl', path: 'assets/art/characters/jarl.png', w: 768, h: 1344,
    prompt: `portrait of 14-year-old norse boy, eager eyes, oversized tunic, hopeful, warm light, ${STYLE}` },
];

async function main() {
  await mkdir('assets/art/scenes', { recursive: true });
  await mkdir('assets/art/characters', { recursive: true });

  for (const job of JOBS) {
    if (existsSync(job.path)) { console.log(`  SKIP ${job.id}`); continue; }
    process.stdout.write(`  ${job.id} (${job.w}×${job.h})... `);
    const output = await replicate.run(
      "stability-ai/sdxl:39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b",
      { input: { prompt: job.prompt, negative_prompt: NEG, width: job.w, height: job.h, num_outputs: 1, num_inference_steps: 25, guidance_scale: 7 } }
    );
    const url = Array.isArray(output) ? output[0] : output;
    const res = await fetch(url);
    const buf = Buffer.from(await res.arrayBuffer());
    writeFileSync(job.path, buf);
    console.log('✓');
  }
  console.log('\nDone!');
}

main().catch(e => console.error(e));
