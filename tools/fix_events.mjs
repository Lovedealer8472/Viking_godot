#!/usr/bin/env node
import { cp, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';

const COMFY_URL = process.env.COMFY_URL || 'http://monolith:8188';
const COMFY = await import('./comfy.mjs');
await mkdir('assets/art/events', { recursive: true });

const T = (s, l) => `authentic 11th century bayeux tapestry textile, edge-to-edge embroidered linen, deteriorated and worn with age, ${s}, horizontal frieze, aged beige linen, bold dark stitched outlines, flat profile style, coarse wool-thread texture, muted faded natural-dye colors, large flat color areas, Latin titulus "${l}" in stitched wool lettering, narrow borders with beasts, ancient artifact, no frame no background`;
const N = 'modern reproduction, clean, polished, painterly, illustration, glossy, soft gradients, excessive folds, ornate, cluttered, 3D, cinematic, smooth faces, fantasy, text, watermark, photograph, white background, modern building, house, vehicle, wheel, frame';

const fixes = {
  shipping_season: ['Viking knarr ship-shape approaching shore, stacked cargo bundle-shapes on beach, trade-goods as small stitched bundles, embroidered wave-lines below, sail in ochre and cream stripes', 'HIC NAVES ADVENIUNT'],
  temple_mould_new_firth: ['Temple-shape being built at water edge, sacred mould-earth spread in brown stitches, firth as blue wool wave-lines, new hof rising', 'HIC TEMPLUM NOVUM'],
  crosses_on_knolls: ['Small hill-shapes with cross-marks stitched on top in dark wool, christian markers on landscape, old norse land meeting new faith', 'HIC CRUCES IN COLLIBUS'],
  blood_for_drift_timber: ['Red blood-drop stitches on driftwood log-shapes on shore, timber stained crimson, price paid for the wood', 'HIC SANGUIS PRO LIGNO'],
  build_hof_oath_ring: ['Hof-shape under construction with timber frame-stitches, oath-ring as gold circle-shape hanging within, sacred building', 'HIC TEMPLUM AEDIFICATUR'],
  helgafell_defiled: ['Sacred mountain-shape with defilement marks as red slash-stitches across it, the holy hill profaned, dark wool stitches', 'HIC MONS SACER VIOLATUS'],
  sacred_thing_vale: ['Valley-shape with thing-stones arranged in circle, sacred assembly place, dritsker rock-shape at edge', 'HIC LOCUS SACER CONCILII'],
  guardian_curse_pole: ['Curse-pole with horse-head shape on top in dark wool, guardian spirit-shapes around it, the nithing-pole raised', 'HIC EQUUS MALEDICTUS ERIGITUR'],
  corpse_demands_hospitality: ['Dead figure-shape in pale grey wool standing at longhouse door, hand-shape reaching in, corpse demanding entry, night sky', 'HIC MORTUUS HOSPITIUM PETIT'],
  drowned_men_at_hearth: ['Three drowned figure-shapes in blue-grey wool seated at fire-pit, water-drop stitches around them, sea-dead at the hearth', 'HIC SUBMERSI AD FOCUM'],
  giant_driftwood_posts: ['Massive driftwood log-shapes larger than ship, hall-post timber from the sea, giant gift of the waves', 'HIC LIGNUM INGENS'],
  invite_thorbjorg: ['Small cloaked woman figure-shape approaching settlement, staff-shape in hand, invitation being offered, little volva', 'HIC SAGA PARVA VOCATUR'],
  prepare_ritual_meal: ['Feast preparation with meat-shapes on spits over fire, ritual bowl-shapes arranged, sacred meal for ceremony', 'HIC CENA SACRA PARATUR'],
  find_singer_vardlokkur: ['Singer figure-shape with open mouth-stitches, weird-song lines flowing as wavy wool marks, vardlokkur being found', 'HIC CANTOR INVENITUR'],
  hear_the_forecast: ['Ear-shapes as large embroidered symbols, fate-lines as stitch-patterns flowing from volva mouth, forecast heard', 'HIC FATUM PRAEDICITUR'],
  kveldrida_accusation: ['Night-rider as dark figure-shape on horse-shape in moonlit stitches, kveldrida accusation, moonlight in pale wool', 'HIC SAGA NOCTURNA'],
  kotkell_storm_scaffold: ['Storm-scaffold as wooden frame-shape with dark storm-cloud stitches above, Kotkell and Grima figures beside it, weather magic', 'HIC TEMPESTAS MAGICA'],
  rune_scored_root: ['Tree-root shape with rune-marks carved along its length in red wool stitches, curse sent to enemy', 'HIC RADIX CUM RUNIS'],
  seek_elf_hill_cure: ['Hill-shape with elf-door as small opening, sick figure approaching with offering-bowl, seeking hidden people cure', 'HIC REMEDIUM AB ALFIS'],
  feast_the_alfar: ['Feast table with offerings to alfar, elf-shapes as small pale figures receiving slaughter-gifts', 'HIC ALFIS SACRIFICATUR'],
  trade_the_ring: ['Gold ring-shape being exchanged for bull-shape, trade between ring and beast, hands meeting in bargain', 'HIC ANULUS PRO TAURO'],
  release_the_ravens: ['Two raven-shapes in black wool being released from ship-shape, flight-lines toward distant land-shape', 'HIC CORVI EMITTUNTUR'],
  name_the_land_from_ice: ['Ice-shapes melting into land-shape, name-marks as rune stitches appearing, new land named', 'HIC TERRA NOMINATUR'],
  blood_rain_on_hay_saga: ['Red-brown wool falling diagonally as blood-rain, hay-stack shapes staining crimson, omen in field', 'HIC SANGUIS SUPER FAENUM'],
  moon_of_the_dead: ['Moon-shape in pale wool above hall-shape, dead figure-shapes gathering in moonlight', 'HIC LUNA MORTUORUM'],
  gula_thing_inheritance: ['Thing-circle with inheritance dispute, land-shapes being divided with stitch-lines, law being spoken', 'HIC HEREDITAS IUDICATUR'],
  lesser_outlawry_thrall: ['Outlaw figure-shape being banished, thrall-shape lying dead, lesser outlawry judgment', 'HIC EXILIUM MINUS'],
  door_court_against_dead: ['Door-shape as court, dead figure-shapes being judged at threshold, law-stitches flowing', 'HIC IUDICIUM AD IANUAM'],
  blood_cloak_settlement: ['Blood-stained cloak-shape being offered as settlement, two household emblems meeting, peace bought with blood-price', 'HIC PALLIUM SANGUINIS'],
  merchant_winters_hall: ['Merchant ship-shape at winter shore, hall-shape with smoke rising, trader staying through cold season', 'HIC MERCATOR HIEMAT'],
  missionary_rood_cross: ['Large cross-shape in dark wool carried by priest-figure, the rood arriving at settlement, new faith', 'HIC CRUX ADVENIT'],
  war_balls_skraelings: ['War-ball shapes as large stitched spheres, skraeling figure-shapes hurling them, conflict with native peoples', 'HIC PILAE BELLI'],
  one_footer_creek: ['One-legged creature shape at creek, single foot-print stitches, strange being at water', 'HIC MONSTRUM AD RIVUM'],
  white_men_land_rumour: ['Map-shape with rumour-lines as dotted stitches leading westward, white men land marked', 'HIC TERRA ALBORUM'],
  ship_worm_lottery: ['Ship-shape with worm-shapes boring through hull in brown stitches, lottery-marks as numbered lots, Irish ocean', 'HIC VERMIS IN NAVI'],
};

let ok = 0;
const total = Object.keys(fixes).length;

for (const [id, [scene, cap]] of Object.entries(fixes)) {
  process.stdout.write(id + '... ');
  try {
    const wf = COMFY.buildZImageWorkflow(T(scene, cap), { width: 1536, height: 640, steps: 30, cfg: 1.0, sampler: 'er_sde', scheduler: 'simple', shift: 3, prefix: 'fix_' + id });
    const r = await COMFY.waitForResult(await COMFY.submitPrompt(wf), { maxWaitMs: 600000 });
    if (!r) { console.log('TIMEOUT'); continue; }
    const fn = typeof r === 'string' ? r : (r.filename || '');
    if (!fn) { console.log('NO_FILE'); continue; }
    // Copy from Monolith via SCP
    const { execSync } = await import('node:child_process');
    execSync(`scp notandi@monolith:/home/notandi/comfyui/output/${fn} assets/art/events/${id}.png`, { stdio: 'ignore' });
    console.log('OK'); ok++;
  } catch (err) { console.log('FAIL: ' + err.message); }
  if (ok % 5 === 0) console.log(ok + '/' + total + ' so far');
}
console.log(ok + '/' + total + ' done');
