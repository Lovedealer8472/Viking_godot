#!/usr/bin/env node
import { cp, mkdir, readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { execSync } from 'node:child_process';

const COMFY_URL = process.env.COMFY_URL || 'http://monolith:8188';
process.env.COMFY_URL = COMFY_URL;
const COMFY = await import('./comfy.mjs');
await mkdir('assets/art/events', { recursive: true });
const EV = JSON.parse(await readFile('X:/viking/tools/gen-art/events_full.json', 'utf8'));

// Complete Latin caption map for ALL 115 events
const CAPS = {
  survey_the_land: 'HIC TERRAM INSPICIUNT', whispering_bones: 'HIC OSSA SUSURRANT',
  driftwood_windfall: 'HIC LIGNUM DE MARE VENIT', orlygr_holy_cargo: 'HIC SACRA NAVIS ADVENIT',
  strangers_at_gate: 'HIC VIATORES EX NIVIBUS VENIUNT', bog_iron: 'HIC FERRUM E PALUDIBUS TRAHUNT',
  wood_rights: 'HIC DE LIGNO CONTENDUNT', thorolf_haltfoot: 'HIC MORTUUS AMBULAT',
  landvaettir_omen: 'HIC SPIRITUS TERRAE VIGILANT', draugr_dreams: 'HIC SOMNIA MORTUORUM',
  flokis_temptation: 'HIC PISCES MULTI SUNT', bardr_warm_wind: 'HIC VENTUS TEPIDUS SPIRAT',
  volcano_ash: 'HIC CINIS DE MONTE CADIT', blood_rain_hay: 'HIC SANGUIS DE CAELO CADIT',
  winter_starvation: 'HIC FAMES IN HIEME', sickness: 'HIC PESTILENTIA GRAVIS EST',
  mild_week: 'HIC TEMPESTAS MITIS EST', harsh_weather: 'HIC TEMPESTAS SAEVA EST',
  shipping_season: 'HIC NAVES ADVENIUNT', lambing: 'HIC AGNI NASCUNTUR',
  spring_thaw_flood: 'HIC AQUAE VERIS FLUUNT', early_winter: 'HIC PRIMA HIEMS VENIT',
  grazing_dispute: 'HIC DE PASCUIS CONTENDUNT', insult_at_feast: 'HIC CONVICIUM IN CONVIVIO',
  feast_hall: 'HIC CONVIVIUM CELEBRANT', raiders_coast: 'HIC PRAEDONES IN LITORE',
  trade_ship: 'HIC MERCATORES ADVENIUNT', thing_assembly: 'HIC CONCILIUM HABENT',
  ghost_door: 'HIC SPIRITUS PER IANUAM EXIT', barrow_gold: 'HIC THESAURUM IN TUMULO INVENIUNT',
  lost_sheep: 'HIC OVES ERRANT', wolf_attack: 'HIC LUPI GREGEM AGGREDIUNTUR',
  whale_beach: 'HIC CETUS IN LITORE IACET', strange_lights: 'HIC LUMINA IN CAELO APPARENT',
  hermit_cave: 'HIC EREMITA IN SPELUNCA', broken_oath: 'HIC IUSIURANDUM FRANGITUR',
  healing_spring: 'HIC AQUA SANAT', raven_message: 'HIC CORVUS NUNTIUM PORTAT',
  star_navigation: 'HIC PER STELLAS NAVIGANT', witch_accusation: 'HIC SAGA DE STRIGA',
  bloodfeud_legacy: 'HIC SANGUIS VETERIS', trader_proposal: 'HIC MERCATOR ADVENIT',
  lost_shipment: 'HIC NAVIS PERDITA EST', eastern_routes: 'HIC VIA AD ORIENTEM',
  heir_marriage: 'HIC MATRIMONIUM IUNCTUM', orphan_relative: 'HIC PROPINQUUS ESURIENS',
  christian_missionary: 'HIC SACERDOS CHRISTIANUS', skald_visit: 'HIC POETA CANTAT',
  ancient_settlement: 'HIC RUINAE ANTIQUAE', eagle_hunting: 'HIC AQUILAE VENANTUR',
  gold_find: 'HIC AURUM INVENTUM', dead_man_high_seat: 'HIC MORTUUS IN SELLA',
  the_hill_that_heals: 'HIC COLLIS SANAT', driftwood_red_runes: 'HIC LIGNUM CUM RUNIS',
  door_doom_midnight: 'HIC IUDICIUM NOCTIS', hidden_farm_under_stone: 'HIC FUNDUS SUB SAXO',
  volva_visit: 'HIC SAGA ADVENIT', mountain_moves: 'HIC MONS MOVETUR',
  barrow_temptation: 'HIC THESAURUS IN TUMULO', dwarf_iron: 'HIC FERRUM NANORUM',
  nidstang_opportunity: 'HIC EQUUS MALEDICTUS', feud_escalates: 'HIC INIMICITIA CRESCIT',
  neighbor_grudge: 'HIC OVES IN PRATO', draugr_stirs: 'HIC MORTUUS AMBULAT',
  shipping_returns: 'HIC NAVIS REDIT', barrow_whispers: 'HIC TUMULUS SUSURRAT',
  vaettir_demand: 'HIC SPIRITUS PRETIUM POSCIT', jarls_tribute_due: 'HIC TRIBUTUM EXIGITUR',
  godis_hof_inspection: 'HIC TEMPLUM INSPICITUR', fighters_kin_arrive: 'HIC PROPINQUI BELLATORIS',
  merchant_credit_call: 'HIC MERCATOR DEBITUM PETIT', cast_highseat_pillars: 'HIC COLUMNAE IACTANTUR',
  temple_mould_new_firth: 'HIC TEMPLUM NOVUM', crosses_on_knolls: 'HIC CRUCES IN COLLIBUS',
  blood_for_drift_timber: 'HIC SANGUIS PRO LIGNO', build_hof_oath_ring: 'HIC TEMPLUM AEDIFICATUR',
  helgafell_defiled: 'HIC MONS SACER VIOLATUS', sacred_thing_vale: 'HIC LOCUS SACER CONCILII',
  guardian_curse_pole: 'HIC EQUUS MALEDICTUS ERIGITUR', corpse_demands_hospitality: 'HIC MORTUUS HOSPITIUM PETIT',
  drowned_men_at_hearth: 'HIC SUBMERSI AD FOCUM', giant_driftwood_posts: 'HIC LIGNUM INGENS',
  invite_thorbjorg: 'HIC SAGA PARVA VOCATUR', prepare_ritual_meal: 'HIC CENA SACRA PARATUR',
  find_singer_vardlokkur: 'HIC CANTOR INVENITUR', hear_the_forecast: 'HIC FATUM PRAEDICITUR',
  kveldrida_accusation: 'HIC SAGA NOCTURNA', kotkell_storm_scaffold: 'HIC TEMPESTAS MAGICA',
  rune_scored_root: 'HIC RADIX CUM RUNIS', seek_elf_hill_cure: 'HIC REMEDIUM AB ALFIS',
  feast_the_alfar: 'HIC ALFIS SACRIFICATUR', trade_the_ring: 'HIC ANULUS PRO TAURO',
  release_the_ravens: 'HIC CORVI EMITTUNTUR', name_the_land_from_ice: 'HIC TERRA NOMINATUR',
  blood_rain_on_hay_saga: 'HIC SANGUIS SUPER FAENUM', moon_of_the_dead: 'HIC LUNA MORTUORUM',
  gula_thing_inheritance: 'HIC HEREDITAS IUDICATUR', lesser_outlawry_thrall: 'HIC EXILIUM MINUS',
  door_court_against_dead: 'HIC IUDICIUM AD IANUAM', blood_cloak_settlement: 'HIC PALLIUM SANGUINIS',
  merchant_winters_hall: 'HIC MERCATOR HIEMAT', missionary_rood_cross: 'HIC CRUX ADVENIT',
  war_balls_skraelings: 'HIC PILAE BELLI', one_footer_creek: 'HIC MONSTRUM AD RIVUM',
  white_men_land_rumour: 'HIC TERRA ALBORUM', ship_worm_lottery: 'HIC VERMIS IN NAVI',
  late_heir_marriage: 'HIC MATRIMONIUM NOVUM', late_sheep_plague: 'HIC PESTIS IN GREGE',
  late_glacial_flood: 'HIC GLACIES RUMPIT', late_news_norway: 'HIC NUNTIUS E NORVEGIA',
  late_winter_wolves: 'HIC LUPI IN HIEME', late_second_generation: 'HIC NOVA GENERATIO',
  jarl_patron: 'HIC DUX NAVEM DAT', merchant_patron: 'HIC MERCATOR BONA DAT',
  godi_patron: 'HIC SACERDOS BENEDICIT', fighter_patron: 'HIC BELLATOR SE IUNGIT',
  high_seat_pillars: 'HIC COLUMNAE IACTANTUR', storm_at_sea: 'HIC TEMPESTAS IN MARI',
  sea_wight_sighting: 'HIC MONSTRUM SUB UNDA', doldrums: 'HIC VENTUS DEFICIT',
  leak_spring: 'HIC AQUA NAVEM INTRAT', whale_omen: 'HIC CETUS AUGURIUM DAT',
  crew_dispute: 'HIC CONTENTIO IN NAVI', iceberg_field: 'HIC GLACIES OBSTAT',
  land_sighting: 'HIC TERRA APPARET', scout_inland: 'HIC EXPLORATORES VALLIS',
  scout_headland: 'HIC EXPLORATORES PROMUNTURII', vaettir_first_contact: 'HIC SPIRITUS LOQUUNTUR',
  fresh_water: 'HIC AQUA DULCIS INVENTA', old_ruin: 'HIC RUINA EREMITAE',
};

const T = (s, l) => `authentic 11th century bayeux tapestry textile, edge-to-edge embroidered linen, deteriorated and worn with age, ${s}, horizontal frieze, aged beige linen, bold dark stitched outlines, flat profile style, coarse wool-thread texture, muted faded natural-dye colors, large flat color areas, Latin titulus "${l}" in stitched wool lettering, narrow borders with beasts, ancient artifact, no frame no background`;
const N = 'modern reproduction, clean, polished, painterly, illustration, glossy, soft gradients, excessive folds, ornate, cluttered, 3D, cinematic, smooth faces, fantasy, text, watermark, photograph, white background, modern building, house, vehicle, wheel, frame';

// Only fix events that exist as files (already generated) but have wrong captions
const todo = EV.filter(e => existsSync(`assets/art/events/${e.id}.png`) && CAPS[e.id]);
console.log(`${todo.length} events to fix with proper Latin captions`);

let ok = 0;
for (const e of todo) {
  const cap = CAPS[e.id];
  const body = e.body || e.title;
  process.stdout.write(e.id + '... ');
  try {
    const wf = COMFY.buildZImageWorkflow(T(body, cap), { width: 1536, height: 640, steps: 30, cfg: 1.0, sampler: 'er_sde', scheduler: 'simple', shift: 3, prefix: 'cap_' + e.id });
    const r = await COMFY.waitForResult(await COMFY.submitPrompt(wf), { maxWaitMs: 600000 });
    if (!r) { console.log('TIMEOUT'); continue; }
    const fn = typeof r === 'string' ? r : (r.filename || '');
    if (!fn) { console.log('NO_FILE'); continue; }
    execSync(`scp notandi@monolith:/home/notandi/comfyui/output/${fn} assets/art/events/${e.id}.png`, { stdio: 'ignore' });
    console.log('OK'); ok++;
  } catch (err) { console.log('FAIL: ' + err.message); }
  if (ok % 10 === 0) console.log(ok + '/' + todo.length + ' so far');
}
console.log(ok + '/' + todo.length + ' fixed');
