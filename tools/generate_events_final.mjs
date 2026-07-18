#!/usr/bin/env node
/**
 * Final event generator — object-led Bayeux prompts, 30 steps, FFmpeg autocrop.
 * Each prompt leads with the most visually distinctive element from the body text.
 */
import { cp, mkdir, readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { execSync } from 'node:child_process';

const COMFY = await import('./comfy.mjs');
const EVENTS = JSON.parse(await readFile('X:/viking/tools/gen-art/events_full.json', 'utf8'));
const OUT = 'assets/art/events';
const BATCH = 10;
const W = 1536, H = 640;

const T = (s,l) => `authentic 11th century bayeux tapestry textile, edge-to-edge embroidered linen, deteriorated and worn with age, ${s}, horizontal frieze, aged beige linen, bold dark stitched outlines, flat profile style, coarse wool-thread texture, muted faded natural-dye colors, clean composition, large flat color areas, Latin titulus "${l}" in stitched wool lettering, narrow borders with simple beasts, ancient artifact, no frame no background`;
const N = 'modern reproduction, clean, polished, painterly, illustration, glossy, soft gradients, excessive folds, ornate, cluttered, 3D, cinematic, smooth faces, fantasy, text, watermark, photograph, white background, frame';

// Smart visual element extractor — leads with objects/weather/animals, not people
function visualScene(body, title) {
  const b = (body||'').toLowerCase();
  // Weather / elemental
  if (b.includes('storm')) return 'Massive embroidered storm waves in dark blue-grey wool stitches, zigzag lightning lines, rain as diagonal stitch marks, small ship shape tossed in the waves';
  if (b.includes('volcano')||b.includes('ash')) return 'Mountain shape with dense embroidered ash-cloud in grey wool stitches above it, falling ash as small cross-stitch dots, darkened sky in hatched wool pattern, ash settling on fields below';
  if (b.includes('snow')||b.includes('winter')||b.includes('frozen')) return 'Snow-covered landscape in white and pale blue wool stitches, embroidered snowflake-pattern sky, bare tree shapes in dark brown stitch';
  if (b.includes('wind')||b.includes('warm wind')) return 'Embroidered wind-lines flowing across the linen in long curved stitches, small trees leaning, warm-air indicated by ochre stitch-lines';
  if (b.includes('blood')&&b.includes('rain')) return 'Red-brown wool stitches falling diagonally across the scene as blood-rain, hay-stack shapes below stained dark, ominous sky in cross-hatched purple-grey wool';
  if (b.includes('rain')||b.includes('flood')) return 'Diagonal rain stitches across the linen in grey-blue wool, water pooling at the bottom in wavy stitch lines, flooded fields';
  // Animals
  if (b.includes('whale')) return 'Massive whale shape embroidered on shoreline in dark blue-grey wool, curved body filling the frieze, small stick-figures at the tail for scale, embroidered wave-lines behind';
  if (b.includes('wolf')||b.includes('wolves')) return 'Wolf shapes in dark grey wool stitches, pointed ears and arched backs, embroidered paw-prints leading toward a flock of small sheep-shapes, trees at the border';
  if (b.includes('raven')||b.includes('crow')||b.includes('bird')) return 'Raven shape in black wool stitches perched on border, spread-wing stitch pattern, small message-scroll shape at its feet, embroidered flight-lines';
  if (b.includes('dog')||b.includes('hound')||b.includes('dogs')) return 'Dog shapes in brown wool stitches, raised hackles as zigzag lines along their backs, facing away from a cairn, refusing to approach';
  if (b.includes('sheep')||b.includes('ewe')||b.includes('lamb')) return 'Small sheep shapes scattered across the linen in cream wool stitches, embroidered grazing lines, shepherd stick-figure at the edge';
  if (b.includes('horse')) return 'Stylized horse shapes in terracotta wool stitches, elongated legs in the Bayeux manner, embroidered rein-lines';
  if (b.includes('dragon')||b.includes('serpent')) return 'Serpent-dragon shape in olive and dark wool stitches winding through the border, embroidered flame-shapes from its mouth';
  // Objects & Resources
  if (b.includes('driftwood')||b.includes('timber')||b.includes('wood')) return 'Pile of driftwood logs heaped on embroidered shoreline in brown wool stitches, wavy sea-stitch lines behind, scattered branches across the linen';
  if (b.includes('iron')||b.includes('bog iron')) return 'Cross-section of peat bog in brown wool stitches, iron-lump shapes being extracted with stick-figure tools, embroidered water-ripples around the bog, pile of raw ore';
  if (b.includes('gold')||b.includes('treasure')||b.includes('silver')||b.includes('hoard')) return 'Treasure hoard in gold and ochre wool stitches, coin-shapes and cup-shapes piled together, barrow-mound shape above in dark brown stitches';
  if (b.includes('bone')||b.includes('cairn')||b.includes('burial')) return 'Stone cairn shape in dark wool stitches, rows of bone-shapes at its base, embroidered sound-lines radiating outward, dog-shape turning away';
  if (b.includes('ship')||b.includes('knarr')||b.includes('longship')) return 'Viking longship in brown and terracotta wool stitches, round shield-shapes along the gunwale, striped sail in ochre and cream, oar-shapes extending into embroidered wave-lines';
  if (b.includes('bell')||b.includes('church')||b.includes('temple')||b.includes('hof')) return 'Church building shape in dark wool stitches, bell-shape hanging in the tower, cross-shapes embroidered above, timber walls';
  if (b.includes('fire')||b.includes('flame')||b.includes('burn')) return 'Flame shapes in orange and ochre wool stitches rising from a building, embroidered smoke-lines curling upward, glowing ember-shapes';
  if (b.includes('feast')||b.includes('hall')||b.includes('mead')||b.includes('drink')) return 'Longhouse interior with central fire-pit in ochre wool stitches, table-shapes with cup-shapes, embroidered figures seated along benches';
  // Structures
  if (b.includes('cairn')||b.includes('mound')||b.includes('barrow')) return 'Burial mound shape in dark brown wool stitches, stone-outline in grey stitches, small entrance-shape, bone-shapes scattered nearby';
  if (b.includes('longhouse')||b.includes('hall')||b.includes('door')) return 'Longhouse shape in brown wool stitches, timber-frame lines, door-shape with embroidered figure emerging, smoke from roof-hole';
  // Generic fallbacks based on theme words
  if (b.includes('sickness')||b.includes('plague')||b.includes('ill')) return 'Sickbed shape in cream wool stitches, small figure-shapes lying down, herbal-bundle shapes nearby, darkened room';
  if (b.includes('dream')||b.includes('vision')||b.includes('omen')) return 'Dream-vision scene with embroidered spirit-shapes floating above a sleeping figure, wavy dream-lines in pale wool stitches, moon and star shapes';
  if (b.includes('death')||b.includes('dead')||b.includes('ghost')||b.includes('draugr')||b.includes('spirit')) return 'Restless dead figure in pale grey-blue wool stitches rising from a mound, embroidered spirit-lines around it, small fleeing figures';
  if (b.includes('battle')||b.includes('fight')||b.includes('war')||b.includes('raid')) return 'Two groups of embroidered warrior-shapes with round shields and axes clashing, fallen figure-shapes on the ground, weapons in dark wool stitches';
  // Fallback: title-based
  return `Scene of ${title.toLowerCase()}, embroidered in flat stylized Bayeux manner with bold outlines and muted wool colors`;
}

function latin(id, title) {
  const map = { survey_the_land:'HIC TERRAM INSPICIUNT', whispering_bones:'HIC OSSA SUSURRANT', driftwood_windfall:'HIC LIGNUM DE MARE VENIT', orlygr_holy_cargo:'HIC SACRA NAVIS ADVENIT', strangers_at_gate:'HIC VIATORES EX NIVIBUS VENIUNT', bog_iron:'HIC FERRUM E PALUDIBUS TRAHUNT', thorolf_haltfoot:'HIC MORTUUS AMBULAT', landvaettir_omen:'HIC SPIRITUS TERRAE VIGILANT', draugr_dreams:'HIC SOMNIA MORTUORUM', flokis_temptation:'HIC PISCES MULTI SUNT', bardr_warm_wind:'HIC VENTUS TEPIDUS SPIRAT', volcano_ash:'HIC CINIS DE MONTE CADIT', blood_rain_hay:'HIC SANGUIS DE CAELO CADIT', winter_starvation:'HIC FAMES IN HIEME', shipping_season:'HIC NAVIS MERCATORIA ADVENIT', feast_hall:'HIC CONVIVIUM CELEBRANT', raiders_coast:'HIC PRAEDONES IN LITORE', trade_ship:'HIC MERCATORES ADVENIUNT', thing_assembly:'HIC CONCILIUM HABENT', ghost_door:'HIC SPIRITUS PER IANUAM EXIT', barrow_gold:'HIC THESAURUM IN TUMULO INVENIUNT', wolf_attack:'HIC LUPI GREGEM AGGREDIUNTUR', whale_beach:'HIC CETUS IN LITORE IACET', strange_lights:'HIC LUMINA IN CAELO APPARENT', broken_oath:'HIC IUSIURANDUM FRANGITUR', healing_spring:'HIC AQUA SANAT', raven_message:'HIC CORVUS NUNTIUM PORTAT', star_navigation:'HIC PER STELLAS NAVIGANT', };
  if (map[id]) return map[id];
  const w=title.toLowerCase();
  if (w.includes('storm')) return 'HIC TEMPESTAS SAEVIT'; if (w.includes('fire')) return 'HIC IGNIS ARDET';
  if (w.includes('death')||w.includes('dead')) return 'HIC MORS VENIT'; if (w.includes('feast')) return 'HIC CONVIVIUM EST';
  if (w.includes('winter')||w.includes('snow')) return 'HIC HIEMS GRAVIS EST'; if (w.includes('sea')||w.includes('ship')) return 'HIC MARE NAVES PORTAT';
  if (w.includes('war')||w.includes('battle')) return 'HIC BELLUM GERUNT'; if (w.includes('spirit')||w.includes('omen')) return 'HIC DEI LOQUUNTUR';
  if (w.includes('trade')||w.includes('gold')||w.includes('wealth')) return 'HIC MERCATURA FIT'; if (w.includes('blood')) return 'HIC SANGUIS FLUIT';
  if (w.includes('dream')||w.includes('vision')) return 'HIC SOMNIUM VIDENT'; if (w.includes('hunger')||w.includes('starve')) return 'HIC FAMES PREMIT';
  return 'HIC RES GESTA EST';
}

function autocrop(path) { try { execSync(`ffmpeg -y -i "${path}" -vf "crop=iw-40:ih-20:20:10" -q:v 2 "${path}.tmp.png" 2>nul && move /Y "${path}.tmp.png" "${path}" 2>nul`, {stdio:'ignore'}); } catch {} }

async function restartComfyUI() {
  try { execSync('taskkill //F //IM python.exe 2>nul', {stdio:'ignore'}); } catch {}
  await new Promise(r=>setTimeout(r,3000));
  execSync('start /b cmd /c "cd /d E:\\Krea2\\ComfyUI && set HIP_VISIBLE_DEVICES=0&& set HSA_OVERRIDE_GFX_VERSION=12.0.0&& set MIOPEN_FIND_MODE=FAST&& set PYTORCH_HIP_ALLOC_CONF=expandable_segments:True,garbage_collection_threshold:0.6&& E:\\Krea2\\venv\\Scripts\\python.exe main.py --use-pytorch-cross-attention --listen 127.0.0.1 --port 8188"', {stdio:'ignore'});
  await new Promise(r=>setTimeout(r,8000));
  for(let i=0;i<30;i++){try{if((await fetch('http://127.0.0.1:8188/')).ok)return;}catch{}await new Promise(r=>setTimeout(r,2000));}
  throw new Error('ComfyUI failed');
}

await mkdir(OUT,{recursive:true});
const todo=EVENTS.filter(e=>!existsSync(`${OUT}/${e.id}.png`));
console.log(`${todo.length} to generate (${EVENTS.length-todo.length} done)`);

let gen=0;
for(let i=0;i<todo.length;i+=BATCH){
  const batch=todo.slice(i,i+BATCH);
  console.log(`\nBatch ${Math.floor(i/BATCH)+1}: ${gen+1}-${gen+batch.length}/${todo.length}`);
  if(i>0){process.stdout.write('Restarting ComfyUI... ');await restartComfyUI();console.log('ready');}
  for(const e of batch){
    const cap=latin(e.id,e.title);
    const scene=visualScene(e.body,e.title);
    process.stdout.write(`  ${e.id}... `);
    try{
      const wf=COMFY.buildZImageWorkflow(T(scene,cap),{width:W,height:H,steps:30,cfg:1.0,sampler:'er_sde',scheduler:'simple',shift:3,prefix:'evf_'+e.id});
      const r=await COMFY.waitForResult(await COMFY.submitPrompt(wf),{maxWaitMs:600000});
      if(!r){console.log('TIMEOUT');continue}
      const fn=typeof r==='string'?r:(r.filename||'');
      if(!fn){console.log('NO_FILE');continue}
      const path=`${OUT}/${e.id}.png`;
      await cp('E:/Krea2/ComfyUI/output/'+fn,path);
      autocrop(path); console.log('OK'); gen++;
    }catch(err){console.log('FAIL: '+err.message);}
  }
}
console.log(`\nDone! ${gen} generated.`);
