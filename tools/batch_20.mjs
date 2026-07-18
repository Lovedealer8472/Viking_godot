#!/usr/bin/env node
import { cp, mkdir, readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';

const COMFY = await import('./comfy.mjs');
const EV = JSON.parse(await readFile('X:/viking/tools/gen-art/events_full.json', 'utf8'));
await mkdir('assets/art/events', { recursive: true });

const S = {
  survey_the_land: 'High-seat pillars as carved wooden post-shapes driven into earth, embroidered coastline below with wave-stitches, ship-shape approaching shore, wild shore in green and brown wool, sea to mountains',
  whispering_bones: 'Stone cairn with marked bone-shapes at base, embroidered sound-lines radiating outward in pale wool, dog-shapes turning away at the border, dusk indicated by ochre sky-stitches',
  driftwood_windfall: 'Pile of driftwood logs heaped on embroidered shoreline, wavy sea-stitch lines, storm-broken branches scattered across the linen, timber washed ashore',
  orlygr_holy_cargo: 'Church-ship approaching shore with cross-shape on sail, timber bundle-shapes on deck, iron bell-shape hanging from mast, consecrated earth as dark soil-stitches in a chest',
  strangers_at_gate: 'Snow-stitched landscape in white wool, three small bundled figure-shapes approaching longhouse door-shape through the snow, warm firelight-glow from within',
  bog_iron: 'Cross-section of peat bog in brown wool stitches, iron-lump shapes extracted with stick-tools, embroidered water-ripples, pile of raw ore beside the bog',
  wood_rights: 'Divided forest with embroidered boundary-line down center, axe-shape stuck in tree-stump, two different wood-pile shapes on each side, contested timber',
  thorolf_haltfoot: 'Restless dead figure-shape in pale grey-blue wool rising from burial mound, embroidered spirit-lines radiating, door-shape with stick-figures performing ritual at threshold',
  landvaettir_omen: 'Land-spirit shapes as small embroidered figures in the hills, raven-shape perched on stone, sacred mound-shape with offering-bowl in gold stitches, mountains behind',
  draugr_dreams: 'Sleeping figure-shapes on floor with embroidered dream-lines rising, hand-shape knocking from below stitched in pale wool through floorboards, names as small rune-marks',
  flokis_temptation: 'Split composition: one side shows fish-shapes leaping in sea-stitches with fishing-line, other side shows hay-stack shapes neglected and small, the choice between sea and fodder',
  bardr_warm_wind: 'Wind-lines in warm ochre wool flowing across the linen, sheltered inland slope with green grass-stitches, bare mountain on other side, warm microclimate as stitch-pattern',
  volcano_ash: 'Mountain shape with dense ash-cloud in grey wool above, falling ash as cross-stitch dots darkening the sky, lichen on rocks turning grey in pale stitches, fields below covered',
  blood_rain_hay: 'Red-brown wool falling diagonally as blood-rain, hay-stack shapes below staining dark, ominous sky in cross-hatched purple-grey wool, the hay turning crimson',
  winter_starvation: 'Empty food-store shapes with nothing inside, thin cattle-shapes with visible rib-stitches, snow-covered ground in white wool, empty bowl-shapes, the hunger of deep winter',
  sickness: 'Sickbed-shape in pale cream wool, herbal bundle-shapes in green stitches beside it, darkened room with small window, one figure-shape lying down, empty space conveying isolation',
  mild_week: 'Sun-shape in gold wool above calm sea-lines, gentle wave-pattern, small ship-shape with full sail, birds as small v-shapes in the border, fair weather',
  harsh_weather: 'Dark grey cross-hatched sky, diagonal rain-stitches across entire frieze, bent tree-shapes leaning hard, roof-shapes with tiles lifting, storm as stitch-pattern',
  shipping_season: 'Viking knarr ship-shape approaching shore, stacked cargo-shapes on beach, trade-goods as bundle-shapes, embroidered wave-lines, sail in ochre and cream stripes',
  lambing: 'Ewe-shape in cream wool lying down, small lamb-shape beside it in pale stitches, embroidered birth-sac, shepherd crook-shape nearby, new life in spring grass',
  spring_thaw_flood: 'Melting ice as broken white stitch-lines, water pooling in blue-grey wool at bottom, emerging grass-shapes through water, sun-shape above melting the frost',
  early_winter: 'First frost as white cross-stitch patterns across the linen, bare tree-shapes with no leaves, thin ice-lines on pond-shape, last autumn leaves falling as ochre stitches',
  grazing_dispute: 'Divided pasture with boundary-marker stones down center, sheep-shapes on one side in cream wool, cattle-shapes on other in brown, two grazing areas clearly separated, no buildings',
  insult_at_feast: 'Overturned drinking horn in center, spilled mead as golden-brown droplets, broken bread loaf split in two, feast table with scattered cup-shapes, fire pit behind',
};

const caps = {
  survey_the_land:'HIC TERRAM INSPICIUNT',whispering_bones:'HIC OSSA SUSURRANT',driftwood_windfall:'HIC LIGNUM DE MARE VENIT',
  orlygr_holy_cargo:'HIC SACRA NAVIS ADVENIT',strangers_at_gate:'HIC VIATORES EX NIVIBUS VENIUNT',bog_iron:'HIC FERRUM E PALUDIBUS TRAHUNT',
  wood_rights:'HIC DE LIGNO CONTENDUNT',thorolf_haltfoot:'HIC MORTUUS AMBULAT',landvaettir_omen:'HIC SPIRITUS TERRAE VIGILANT',
  draugr_dreams:'HIC SOMNIA MORTUORUM',flokis_temptation:'HIC PISCES MULTI SUNT',bardr_warm_wind:'HIC VENTUS TEPIDUS SPIRAT',
  volcano_ash:'HIC CINIS DE MONTE CADIT',blood_rain_hay:'HIC SANGUIS DE CAELO CADIT',winter_starvation:'HIC FAMES IN HIEME',
  sickness:'HIC PESTILENTIA GRAVIS EST',mild_week:'HIC TEMPESTAS MITIS EST',harsh_weather:'HIC TEMPESTAS SAEVA EST',
  shipping_season:'HIC NAVES ADVENIUNT',lambing:'HIC AGNI NASCUNTUR',spring_thaw_flood:'HIC AQUAE VERIS FLUUNT',
  early_winter:'HIC PRIMA HIEMS VENIT',grazing_dispute:'HIC DE PASCUIS CONTENDUNT',insult_at_feast:'HIC CONVICIUM IN CONVIVIO',
};

const T = (s,l) => `authentic 11th century bayeux tapestry textile, edge-to-edge embroidered linen, deteriorated and worn with age, ${s}, horizontal frieze, aged beige linen, bold dark stitched outlines, flat profile style, coarse wool-thread texture, muted faded natural-dye colors, large flat color areas, Latin titulus "${l}" in stitched wool lettering, narrow borders with beasts, ancient artifact, no frame no background`;
const N = 'modern reproduction, clean, polished, painterly, illustration, glossy, soft gradients, excessive folds, ornate, cluttered, 3D, cinematic, smooth faces, fantasy, text, watermark, photograph, white background, modern building, house, vehicle, wheel, frame';

const todo = EV.slice(0, 20);
let ok = 0;

for (const e of todo) {
  if (existsSync('assets/art/events/' + e.id + '.png')) { console.log('SKIP ' + e.id); ok++; continue; }
  const scene = S[e.id] || e.body;
  const cap = caps[e.id] || 'HIC RES GESTA EST';
  process.stdout.write(e.id + '... ');
  try {
    const wf = COMFY.buildZImageWorkflow(T(scene, cap), { width: 1536, height: 640, steps: 30, cfg: 1.0, sampler: 'er_sde', scheduler: 'simple', shift: 3, prefix: 'sym_' + e.id });
    const r = await COMFY.waitForResult(await COMFY.submitPrompt(wf), { maxWaitMs: 600000 });
    if (!r) { console.log('TIMEOUT'); continue; }
    const fn = typeof r === 'string' ? r : (r.filename || '');
    if (!fn) { console.log('NO_FILE'); continue; }
    await cp('E:/Krea2/ComfyUI/output/' + fn, 'assets/art/events/' + e.id + '.png');
    console.log('OK'); ok++;
  } catch (err) { console.log('FAIL: ' + err.message); }
}
console.log(ok + '/' + todo.length + ' done');
