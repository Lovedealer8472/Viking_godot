#!/usr/bin/env node
/**
 * Generate atmospheric placeholder art for Act 1.
 * Darkest Dungeon / Banner Saga palette — moody gradients with texture.
 * These are placeholders until real ComfyUI art is generated.
 *
 * Usage: node tools/generate_placeholders.mjs
 */

import sharp from 'sharp';
import { mkdir } from 'node:fs/promises';

const W = 1344, H = 768;
const PW = 768, PH = 1344;  // portrait

// Darkest Dungeon palette
const BG  = [15, 11, 10];       // #0f0b0a
const SH  = [42, 31, 26];       // #2a1f1a
const MID = [74, 61, 51];       // #4a3d33
const HI  = [139, 122, 103];    // #8b7a67
const GOLD = [196, 164, 74];    // #c4a44a
const FOG = [200, 200, 210, 40]; // mist

function gradient(buf, top, bot) {
  for (let y = 0; y < H; y++) {
    const t = y / H;
    const r = Math.round(top[0] + (bot[0] - top[0]) * t);
    const g = Math.round(top[1] + (bot[1] - top[1]) * t);
    const b = Math.round(top[2] + (bot[2] - top[2]) * t);
    for (let x = 0; x < W; x++) {
      const i = (y * W + x) * 3;
      buf[i] = r; buf[i+1] = g; buf[i+2] = b;
    }
  }
}

function addNoise(buf, amount = 8) {
  for (let i = 0; i < buf.length; i++) {
    buf[i] = Math.min(255, Math.max(0, buf[i] + (Math.random() - 0.5) * amount));
  }
}

function addVignette(buf) {
  const cx = W/2, cy = H/2, maxDist = Math.sqrt(cx*cx + cy*cy);
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const dist = Math.sqrt((x-cx)**2 + (y-cy)**2) / maxDist;
      const dark = 1 - dist * 0.6;
      const i = (y * W + x) * 3;
      buf[i] = Math.round(buf[i] * dark);
      buf[i+1] = Math.round(buf[i+1] * dark);
      buf[i+2] = Math.round(buf[i+2] * dark);
    }
  }
}

async function scene(name, topColor, botColor, extra = null) {
  const buf = Buffer.alloc(W * H * 3);
  gradient(buf, topColor, botColor);
  addNoise(buf, 6);
  addVignette(buf);
  if (extra) extra(buf);
  await sharp(buf, { raw: { width: W, height: H, channels: 3 } })
    .png().toFile(`assets/art/scenes/${name}.png`);
  console.log(`  ✓ ${name}.png`);
}

async function portrait(name, bgColor, bodyColor) {
  const buf = Buffer.alloc(PW * PH * 3);
  for (let y = 0; y < PH; y++) {
    const t = y / PH;
    const r = Math.round(bgColor[0] + (bodyColor[0] - bgColor[0]) * t);
    const g = Math.round(bgColor[1] + (bodyColor[1] - bgColor[1]) * t);
    const b = Math.round(bgColor[2] + (bodyColor[2] - bgColor[2]) * t);
    for (let x = 0; x < PW; x++) {
      const i = (y * PW + x) * 3;
      buf[i] = r; buf[i+1] = g; buf[i+2] = b;
    }
  }
  // Add a gold rim-light streak on the right side
  for (let y = 0; y < PH; y++) {
    for (let x = Math.round(PW * 0.75); x < PW; x++) {
      const i = (y * PW + x) * 3;
      const strength = (x - PW*0.75) / (PW*0.25);
      buf[i] = Math.round(buf[i] + GOLD[0] * strength * 0.3);
      buf[i+1] = Math.round(buf[i+1] + GOLD[1] * strength * 0.3);
      buf[i+2] = Math.round(buf[i+2] + GOLD[2] * strength * 0.3);
    }
  }
  addNoise(buf, 4);
  // Vignette
  const cx = PW/2, cy = PH/2, maxDist = Math.sqrt(cx*cx + cy*cy);
  for (let y = 0; y < PH; y++) {
    for (let x = 0; x < PW; x++) {
      const dist = Math.sqrt((x-cx)**2 + (y-cy)**2) / maxDist;
      const dark = 1 - dist * 0.55;
      const i = (y * PW + x) * 3;
      buf[i] = Math.round(buf[i] * dark);
      buf[i+1] = Math.round(buf[i+1] * dark);
      buf[i+2] = Math.round(buf[i+2] * dark);
    }
  }
  await sharp(buf, { raw: { width: PW, height: PH, channels: 3 } })
    .png().toFile(`assets/art/characters/${name}.png`);
  console.log(`  ✓ ${name}.png`);
}

// ═══════════════════════════════════════════════════════════════════════════

console.log('Generating placeholder art...\n');

await mkdir('assets/art/scenes', { recursive: true });
await mkdir('assets/art/characters', { recursive: true });

// Scenes
console.log('Scenes:');
await scene('fjord', [30, 40, 50], [15, 18, 22]);        // grey-blue mist → dark
await scene('hall', [50, 35, 20], [20, 12, 8]);          // warm firelit → dark corners
// Hall extra: add a warm glow in the center
await scene('hall_interior', [60, 45, 25], [15, 10, 6], (buf) => {
  const cx = W/2, cy = H * 0.55;
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const dist = Math.sqrt((x-cx)**2 + (y-cy)**2) / 300;
      if (dist < 1) {
        const glow = (1 - dist) * 0.5;
        const i = (y * W + x) * 3;
        buf[i] = Math.round(buf[i] + GOLD[0] * glow);
        buf[i+1] = Math.round(buf[i+1] + GOLD[1] * glow * 0.7);
        buf[i+2] = Math.round(buf[i+2] + GOLD[2] * glow * 0.3);
      }
    }
  }
});
await scene('ship_deck', [50, 60, 70], [25, 30, 40]);    // stormy grey-blue

// Hall interior (for patron meetings)
await sharp(Buffer.alloc(1), { raw: { width: 1, height: 1, channels: 3 } })
  .png().toFile('assets/art/scenes/hall.png')
  .then(() => console.log('  ✓ hall.png (symlink to hall_interior)'));
// Actually just copy hall_interior as hall for the patron scene
import { copyFile } from 'node:fs/promises';
await copyFile('assets/art/scenes/hall_interior.png', 'assets/art/scenes/hall.png');
console.log('  ✓ hall.png');

// Characters
console.log('\nCharacters:');
const chars = [
  ['leader', [25, 20, 15], [50, 45, 35]],     // warm brown tones — leader
  ['bjarne', [30, 20, 15], [55, 35, 25]],      // ruddy — fighter
  ['ragna', [25, 22, 18], [50, 45, 35]],       // earth — worker
  ['einar', [15, 15, 20], [35, 35, 45]],       // cool grey — scholar
  ['brynja', [25, 20, 18], [55, 48, 35]],      // warm — crafter
  ['leif', [20, 30, 35], [40, 50, 55]],         // cool blue-grey — scout
  ['jarl', [20, 18, 15], [48, 42, 35]],        // warm light — apprentice
];
for (const [id, top, bot] of chars) {
  await portrait(id, top, bot);
}

console.log('\nDone. 3 scenes + 7 portraits + 1 hall copy generated.');
console.log('Open the Godot project to see them in Act 1.');
