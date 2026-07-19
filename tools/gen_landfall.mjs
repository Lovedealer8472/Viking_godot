// One-off: generate the Act 3 landfall backdrop in the Bayeux-tapestry style
// that matches fjord/hall/ship_deck. Run: node tools/gen_landfall.mjs
import { buildZImageWorkflow, submitPrompt, waitForResult, copyImage } from './comfy.mjs';
import { resolve } from 'node:path';

const PROMPT = [
  'Bayeux Tapestry style embroidered medieval illustration on aged linen,',
  'a Viking longship (knarr) beaching on a black volcanic sand shore of Iceland,',
  'tall dark basalt sea-cliffs rising behind, Norse settlers wading ashore carrying',
  'round shields and cargo, seabirds wheeling overhead, muted wool-thread colours',
  '(ochre, indigo, madder red, cream), decorative ornamental borders top and bottom,',
  'historical Norse saga scene, wide panoramic composition',
].join(' ');

const wf = buildZImageWorkflow(PROMPT, {
  width: 1344, height: 768, steps: 10, prefix: 'viking_landfall',
});

console.log('submitting landfall generation...');
const id = await submitPrompt(wf);
console.log('prompt_id:', id);
const { filename, subfolder } = await waitForResult(id, { maxWaitMs: 150000 });
console.log('generated:', subfolder ? `${subfolder}/${filename}` : filename);
const src = subfolder ? `${subfolder}/${filename}` : filename;
const dest = resolve('assets/art/scenes/landfall.png');
await copyImage(src, dest);
console.log('copied ->', dest);
