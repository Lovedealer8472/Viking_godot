#!/usr/bin/env node
/**
 * v2 — Each event gets a UNIQUE visual prompt from its body text + proper Latin.
 * Batch size of 15 with ComfyUI restarts. 1536×640.
 */
import { cp, mkdir, readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { execSync } from 'node:child_process';

const COMFY = await import('./comfy.mjs');
const EVENTS = JSON.parse(await readFile('X:/viking/tools/gen-art/events_full.json', 'utf8'));
const OUT = 'assets/art/events';
const BATCH = 15;
const W = 1536, H = 640;

// Proper Latin captions — HIC + subject + verb (Bayeux style)
function latin(id, title, body) {
  const map = {
    survey_the_land: 'HIC TERRAM INSPICIUNT', whispering_bones: 'HIC OSSA SUSURRANT',
    driftwood_windfall: 'HIC LIGNUM DE MARE VENIT', orlygr_holy_cargo: 'HIC SACRA NAVIS ADVENIT',
    strangers_at_gate: 'HIC VIATORES EX NIVIBUS VENIUNT', bog_iron: 'HIC FERRUM E PALUDIBUS TRAHUNT',
    wood_rights: 'HIC DE LIGNO CONTENDUNT', thorolf_haltfoot: 'HIC MORTUUS AMBULAT',
    landvaettir_omen: 'HIC SPIRITUS TERRAE VIGILANT', draugr_dreams: 'HIC SOMNIA MORTUORUM',
    flokis_temptation: 'HIC PISCES MULTI SUNT', bardr_warm_wind: 'HIC VENTUS TEPIDUS SPIRAT',
    sickness: 'HIC PESTILENTIA GRAVIS EST', volcano_ash: 'HIC CINIS DE MONTE CADIT',
    blood_rain_hay: 'HIC SANGUIS DE CAELO CADIT', winter_starvation: 'HIC FAMES IN HIEME',
    shipping_season: 'HIC NAVIS MERCATORIA ADVENIT', feast_hall: 'HIC CONVIVIUM CELEBRANT',
    raiders_coast: 'HIC PRAEDONES IN LITORE', trade_ship: 'HIC MERCATORES ADVENIUNT',
    thing_assembly: 'HIC CONCILIUM HABENT', ghost_door: 'HIC SPIRITUS PER IANUAM EXIT',
    barrow_gold: 'HIC THESAURUM IN TUMULO INVENIUNT', lost_sheep: 'HIC OVES ERRANT',
    wolf_attack: 'HIC LUPI GREGEM AGGREDIUNTUR', whale_beach: 'HIC CETUS IN LITORE IACET',
    strange_lights: 'HIC LUMINA IN CAELO APPARENT', hermit_cave: 'HIC EREMITA IN SPELUNCA',
    broken_oath: 'HIC IUSIURANDUM FRANGITUR', healing_spring: 'HIC AQUA SANAT',
    raven_message: 'HIC CORVUS NUNTIUM PORTAT', star_navigation: 'HIC PER STELLAS NAVIGANT',
  };
  if (map[id]) return map[id];
  // Fallback: build from title keywords
  const w = title.toLowerCase();
  if (w.includes('storm')) return 'HIC TEMPESTAS SAEVIT';
  if (w.includes('fire')) return 'HIC IGNIS ARDET';
  if (w.includes('death')||w.includes('dead')) return 'HIC MORS VENIT';
  if (w.includes('feast')||w.includes('feast')) return 'HIC CONVIVIUM EST';
  if (w.includes('winter')||w.includes('snow')) return 'HIC HIEMS GRAVIS EST';
  if (w.includes('sea')||w.includes('ship')) return 'HIC MARE NAVES PORTAT';
  if (w.includes('war')||w.includes('battle')||w.includes('raid')) return 'HIC BELLUM GERUNT';
  if (w.includes('god')||w.includes('spirit')||w.includes('omen')) return 'HIC DEI LOQUUNTUR';
  if (w.includes('trade')||w.includes('gold')||w.includes('silver')||w.includes('wealth')) return 'HIC MERCATURA FIT';
  if (w.includes('blood')) return 'HIC SANGUIS FLUIT';
  if (w.includes('dream')||w.includes('vision')) return 'HIC SOMNIUM VIDENT';
  if (w.includes('curse')||w.includes('witch')) return 'HIC MALEDICTIO EST';
  if (w.includes('child')||w.includes('birth')) return 'HIC INFANS NASCITUR';
  if (w.includes('hunger')||w.includes('starve')||w.includes('famine')) return 'HIC FAMES PREMIT';
  if (w.includes('law')||w.includes('thing')||w.includes('court')) return 'HIC LEGEM DICUNT';
  return 'HIC RES GESTA EST'; // default: "Here a deed was done"
}

const N = 'modern reproduction, clean, vibrant, cartoon, digital, painting, photorealistic, 3d, text, watermark, low quality';

async function restartComfyUI() {
  try { execSync('taskkill //F //IM python.exe 2>nul', {stdio:'ignore'}); } catch {}
  await new Promise(r => setTimeout(r, 3000));
  execSync('start /b cmd /c "cd /d E:\\Krea2\\ComfyUI && set HIP_VISIBLE_DEVICES=0&& set HSA_OVERRIDE_GFX_VERSION=12.0.0&& set MIOPEN_FIND_MODE=FAST&& set PYTORCH_HIP_ALLOC_CONF=expandable_segments:True,garbage_collection_threshold:0.6&& E:\\Krea2\\venv\\Scripts\\python.exe main.py --use-pytorch-cross-attention --listen 127.0.0.1 --port 8188"', {stdio:'ignore'});
  await new Promise(r => setTimeout(r, 8000));
  for (let i=0; i<30; i++) {
    try { if ((await fetch('http://127.0.0.1:8188/')).ok) return; } catch {}
    await new Promise(r => setTimeout(r, 2000));
  }
  throw new Error('ComfyUI failed');
}

await mkdir(OUT, { recursive: true });
const todo = EVENTS.filter(e => !existsSync(`${OUT}/${e.id}.png`));
console.log(`${todo.length} to generate, ${EVENTS.length - todo.length} already done`);

let gen = 0;
for (let i=0; i < todo.length; i+=BATCH) {
  const batch = todo.slice(i, i+BATCH);
  console.log(`\nBatch ${Math.floor(i/BATCH)+1}: ${gen+1}-${gen+batch.length}/${todo.length}`);
  if (i > 0) { process.stdout.write('Restarting ComfyUI... '); await restartComfyUI(); console.log('ready'); }
  for (const e of batch) {
    const cap = latin(e.id, e.title, e.body);
    // Body text + Bayeux style = unique visual narrative per event
    const prompt = `archaeological photograph of an authentic 11th century bayeux tapestry section, ${e.body}, embroidered wool thread texture, visible stitchwork, deteriorated faded muted colors on aged yellowed linen, uneven hand-stitched outlines, crude romanesque profile figures, decorative animal borders, horizontal narrative frieze, latin caption "${cap}" in crude stitched lettering, ancient textile artifact`;
    process.stdout.write(`  ${e.id}... `);
    try {
      const wf = COMFY.buildZImageWorkflow(prompt, {width:W,height:H,steps:30,cfg:1.0,sampler:'er_sde',scheduler:'simple',shift:3,prefix:'ev2_'+e.id});
      const r = await COMFY.waitForResult(await COMFY.submitPrompt(wf),{maxWaitMs:600000});
      if (!r) { console.log('TIMEOUT'); continue; }
      const fn = typeof r==='string'?r:(r.filename||'');
      if (fn) { await cp('E:/Krea2/ComfyUI/output/'+fn,`${OUT}/${e.id}.png`); console.log('OK'); gen++; }
      else console.log('NO_FILE');
    } catch(err) { console.log('FAIL: '+err.message); }
  }
}
console.log(`\nDone! ${gen} generated.`);
