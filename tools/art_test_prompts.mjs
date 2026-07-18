#!/usr/bin/env node
/**
 * Art style test — generates the same 3 scenes in 3 different styles
 * to compare which art direction works best for Viking Saga Godot.
 *
 * Usage: node tools/art_test_prompts.mjs
 *
 * Requires: ComfyUI running with Z-Image-Turbo (see gen-art pipeline)
 * Output: public/events/ (same pipeline as browser game)
 */

// ═══════════════════════════════════════════════════════════════════════════
// Test scenes — one for each act + a character portrait
// ═══════════════════════════════════════════════════════════════════════════

const SCENES = {
  fjord: "norwegian fjord at dusk, misty mountains, small viking knarr ship at wooden dock, 8th century norway, calm water reflecting mountains",
  hall_interior: "viking longhouse interior, central fire pit, timber walls, shields on walls, benches, warm firelight, norse settlement, 8th century iceland",
  settlement: "viking settlement on icelandic coast, turf houses, black sand beach, snow-capped mountains in distance, sheep grazing, smoke rising from hall, overcast sky",
  character: "viking warrior portrait, norse man in wool tunic, bearded, rugged features, standing on ship deck, foggy fjord background, dramatic lighting",
}

// ═══════════════════════════════════════════════════════════════════════════
// Three art styles to test
// ═══════════════════════════════════════════════════════════════════════════

const STYLES = {
  painterly: {
    prefix: "dark atmospheric oil painting",
    suffix: "muted earth tones, textured brushstrokes, dramatic sky, moody lighting, painterly texture, norse landscape art",
  },
  flat: {
    prefix: "flat vector illustration, cel-shaded",
    suffix: "bold shapes, limited color palette of deep blues and warm golds, clean lines, modern indie game art style, 2d game background",
  },
  gritty: {
    prefix: "gritty atmospheric scene, desaturated, high contrast",
    suffix: "heavy shadows, near-monochrome with gold highlights, oppressive atmosphere, cinematic, film grain, dark nordic, dramatic",
  },
}

// ═══════════════════════════════════════════════════════════════════════════
// Negative prompt (shared across all styles)
// ═══════════════════════════════════════════════════════════════════════════

const NEGATIVE = "modern, contemporary, 21st century, cars, power lines, text, watermark, signature, low quality, blurry, distorted, deformed, ugly, bad anatomy, extra limbs, cartoon, anime, 3d render, plastic, glossy"

// ═══════════════════════════════════════════════════════════════════════════
// Build all prompt combinations
// ═══════════════════════════════════════════════════════════════════════════

const prompts = []

for (const [sceneKey, sceneDesc] of Object.entries(SCENES)) {
  for (const [styleKey, style] of Object.entries(STYLES)) {
    const id = `test_${sceneKey}_${styleKey}`
    const positive = `${style.prefix} of a ${sceneDesc}, ${style.suffix}`
    prompts.push({ id, positive, negative: NEGATIVE, width: 1344, height: 768 })
  }
}

// Print them
console.log(`Generated ${prompts.length} test prompts (${Object.keys(SCENES).length} scenes × ${Object.keys(STYLES).length} styles):\n`)
for (const p of prompts) {
  console.log(`  ${p.id}`)
  console.log(`    +: ${p.positive.slice(0, 120)}...`)
  console.log(`    -: ${p.negative.slice(0, 80)}...`)
  console.log()
}

// Save to JSON for the gen-art pipeline
import { writeFileSync } from 'fs'
writeFileSync('tools/art_test_prompts.json', JSON.stringify(prompts, null, 2))
console.log('Saved to tools/art_test_prompts.json')
console.log('\nRun with: node tools/gen-art/generate.mjs --all (after updating subjects to include test prompts)')
