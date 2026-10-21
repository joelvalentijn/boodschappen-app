// Haalt het hele HEMA-assortiment op en schrijft products-hema.json.
//
//   node scraper-hema.mjs
//
// Naam, foto en afdeling staan allemaal in de sitemap van hema.nl, dus er hoeven
// geen productpagina's te worden opgehaald. Prijs en omschrijving haalt de app zelf
// op als je een product opent.

import { appendFileSync, existsSync, readFileSync, writeFileSync } from 'node:fs';

const SITEMAP_INDEX = 'https://www.hema.nl/sitemap_index.xml';
const OUTPUT = 'products-hema.json';
// Producten uit de eerste catalogus tellen niet als "nieuw".
const BASELINE_DATE = '2026-09-01';
const HEADERS = { 'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36' };

// Afdelingen in de volgorde van de app. `paths` zijn de eerste één of twee mappen van de productlink.
const DEPARTMENTS = [
  { name: 'Snoep & chocolade', emoji: '🍫', paths: ['eten-drinken/snoep', 'eten-drinken/chocolade'] },
  { name: 'Koekjes & snacks', emoji: '🍪', paths: ['eten-drinken/koekjes', 'eten-drinken/snacks', 'eten-drinken/kinder-tussendoortjes'] },
  { name: 'Gebak & taart', emoji: '🎂', paths: ['eten-drinken/gebak', 'eten-drinken/vers'] },
  { name: 'Koffie & thee', emoji: '☕', paths: ['eten-drinken/koffie', 'eten-drinken/thee', 'eten-drinken/restaurant'] },
  { name: 'Frisdrank & sap', emoji: '🥤', paths: ['eten-drinken/frisdrank', 'eten-drinken/alcoholvrij'] },
  { name: 'Wijn, bier & cocktails', emoji: '🍷', paths: ['eten-drinken/wijn', 'eten-drinken/bier', 'eten-drinken/cocktails'] },
  { name: 'Eten & drinken', emoji: '🧺', paths: ['eten-drinken'] },
  { name: 'Verzorging', emoji: '🧴', paths: ['mooi-gezond/persoonlijke-verzorging'] },
  { name: 'Make-up', emoji: '💄', paths: ['mooi-gezond/make-up'] },
  { name: 'Gezondheid', emoji: '🩹', paths: ['mooi-gezond'] },
  { name: 'Huishouden & schoonmaak', emoji: '🧹', paths: ['wonen-slapen/huishouden'] },
  { name: 'Badkamer', emoji: '🛁', paths: ['wonen-slapen/badkamer'] },
  { name: 'Slapen', emoji: '🛏️', paths: ['wonen-slapen/slapen'] },
  { name: 'Huisdieren', emoji: '🐾', paths: ['wonen-slapen/huisdieren'] },
  { name: 'Wonen', emoji: '🛋️', paths: ['wonen-slapen'] },
  { name: 'Koken & tafelen', emoji: '🍳', paths: ['koken-tafelen'] },
  { name: 'School & kantoor', emoji: '✏️', paths: ['school-kantoor', 'vrije-tijd-kantoor', 'buiten-kantoor'] },
  { name: 'Speelgoed & hobby', emoji: '🧸', paths: ['speelgoed-hobby', 'nijntje'] },
  { name: 'Baby', emoji: '🍼', paths: ['baby'] },
  { name: 'Kinderkleding', emoji: '👕', paths: ['kind'] },
  { name: 'Dameskleding', emoji: '👗', paths: ['dames'] },
  { name: 'Herenkleding', emoji: '👔', paths: ['heren'] },
  { name: 'Buiten & onderweg', emoji: '🎒', paths: ['buiten-onderweg'] },
  { name: 'Feest & cadeau', emoji: '🎁', paths: ['feest-cadeau', 'feest', 'cadeau', 'halloween'] },
  { name: 'Sinterklaas', emoji: '🎅', paths: ['sinterklaas'] },
  { name: 'Kerst', emoji: '🎄', paths: ['kerst'] },
  { name: 'Overig', emoji: '📦', paths: [] },
];

// Langste pad eerst, zodat "eten-drinken/snoep" voor "eten-drinken" gaat.
const PATH_LOOKUP = DEPARTMENTS
  .flatMap((d) => d.paths.map((path) => ({ path, name: d.name })))
  .sort((a, b) => b.path.length - a.path.length);

function department(url) {
  const path = new URL(url).pathname.replace(/^\//, '');
  for (const { path: prefix, name } of PATH_LOOKUP) {
    if (path.startsWith(`${prefix}/`)) return name;
  }
  return 'Overig';
}

function decodeXml(text) {
  return text
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number(code)))
    .replace(/&quot;/g, '"').replace(/&apos;/g, "'")
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
}

function cleanName(text) {
  const name = decodeXml(text).replace(/\s+/g, ' ').trim();
  return name.charAt(0).toUpperCase() + name.slice(1);
}

// De originele foto's zijn vaak 2 MB; via de beeldserver van HEMA krijg je 400 px breed.
function smallImage(url) {
  if (!url) return null;
  const marker = 'https://www.hema.nl/on/demandware.static/';
  if (!url.startsWith(marker)) return url;
  return `https://static.hema.nl/dw/image/v2/BBRK_PRD/on/demandware.static/${url.slice(marker.length)}?sw=400`;
}

function slugName(url) {
  const file = new URL(url).pathname.split('/').pop().replace(/\.html$/, '');
  return cleanName(file.replace(/-\d+[A-Z]?$/, '').replace(/-+/g, ' '));
}

async function fetchText(url) {
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const res = await fetch(url, { headers: HEADERS });
      if (res.ok) return await res.text();
      throw new Error(`HTTP ${res.status}`);
    } catch (err) {
      if (attempt === 3) throw new Error(`${url} niet beschikbaar: ${err.message}`);
      await new Promise((r) => setTimeout(r, attempt * 3000));
    }
  }
}

async function loadProducts() {
  console.log('🔄 Sitemap downloaden...');
  const index = await fetchText(SITEMAP_INDEX);
  const sitemaps = [...index.matchAll(/<loc>([^<]*-product\.xml)<\/loc>/g)].map((m) => m[1]);
  if (!sitemaps.length) throw new Error('Geen productsitemaps gevonden');

  const products = [];
  for (const sitemap of sitemaps) {
    const xml = await fetchText(sitemap);
    for (const [, block] of xml.matchAll(/<url>([\s\S]*?)<\/url>/g)) {
      const url = block.match(/<loc>([^<]+)<\/loc>/)?.[1]?.trim();
      if (!url || !url.endsWith('.html')) continue;
      const title = block.match(/<image:title>([\s\S]*?)<\/image:title>/)?.[1];
      const image = block.match(/<image:loc>([^<]+)<\/image:loc>/)?.[1]?.trim();
      products.push({
        url: decodeXml(url),
        name: title ? cleanName(title) : slugName(url),
        image: smallImage(image ? decodeXml(image) : null),
      });
    }
  }
  console.log(`📦 ${products.length} producten in ${sitemaps.length} sitemaps`);
  return products;
}

function loadExisting() {
  if (!existsSync(OUTPUT)) return { data: null, firstSeen: new Map() };
  const data = JSON.parse(readFileSync(OUTPUT, 'utf-8'));
  const firstSeen = new Map();
  for (const category of data.categories || []) {
    for (const p of category.products || []) firstSeen.set(p.url, p.firstSeen || BASELINE_DATE);
  }
  return { data, firstSeen };
}

async function main() {
  const today = new Date().toISOString().slice(0, 10);
  const existing = loadExisting();
  const isFirstRun = existing.data === null;
  const products = await loadProducts();

  const byDepartment = new Map(DEPARTMENTS.map((d) => [d.name, []]));
  const seen = new Set();
  const added = [];
  for (const p of products) {
    if (seen.has(p.url)) continue;
    seen.add(p.url);
    const firstSeen = existing.firstSeen.get(p.url) || (isFirstRun ? BASELINE_DATE : today);
    if (!existing.firstSeen.has(p.url) && !isFirstRun) added.push(p);
    byDepartment.get(department(p.url)).push({ name: p.name, brand: null, image: p.image, url: p.url, firstSeen });
  }
  const removed = [...existing.firstSeen.keys()].filter((url) => !seen.has(url)).length;

  const categories = DEPARTMENTS
    .map((d) => ({
      name: d.name,
      emoji: d.emoji,
      products: byDepartment.get(d.name).sort((a, b) => a.name.localeCompare(b.name, 'nl') || a.url.localeCompare(b.url)),
    }))
    .filter((c) => c.products.length > 0);
  const total = categories.reduce((sum, c) => sum + c.products.length, 0);

  // Alleen een nieuwe datum zetten als de inhoud echt veranderd is.
  const previous = existing.data;
  const unchanged = previous && JSON.stringify(previous.categories) === JSON.stringify(categories);
  const generatedAt = unchanged && previous.generatedAt
    ? previous.generatedAt
    : new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');

  writeFileSync(OUTPUT, `${JSON.stringify({ generatedAt, categories }, null, 1)}\n`, 'utf-8');

  const lines = [
    `✅ ${total} HEMA-producten in ${categories.length} afdelingen${unchanged ? ' (geen wijzigingen)' : ''}`,
    ...categories.map((c) => `   ${c.emoji} ${c.name}: ${c.products.length}`),
    `🆕 Nieuw: ${added.length}   🗑️ Uit assortiment: ${removed}`,
    ...added.slice(0, 50).map((p) => `   + ${p.name}`),
  ];
  if (added.length > 50) lines.push(`   ... en nog ${added.length - 50}`);
  console.log(lines.join('\n'));
  if (process.env.GITHUB_STEP_SUMMARY) {
    appendFileSync(process.env.GITHUB_STEP_SUMMARY, `\`\`\`\n${lines.join('\n')}\n\`\`\`\n`);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
