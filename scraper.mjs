// Haalt het Lidl-assortiment op en schrijft products.json.
//
//   node scraper.mjs            Nieuwe producten ophalen (bestaande worden hergebruikt)
//   node scraper.mjs --full     Alle productpagina's opnieuw ophalen
//   node scraper.mjs --offline  Geen internet: alleen products.json opnieuw opschonen
//
// Elk product krijgt een "firstSeen"-datum, zodat de app nieuwe producten kan tonen.

import { gunzipSync } from 'node:zlib';
import { appendFileSync, existsSync, readFileSync, writeFileSync } from 'node:fs';
import {
  CATEGORIES,
  categorize,
  cleanBrand,
  cleanName,
  isOnlineShopId,
  normalize,
} from './catalog-rules.mjs';

const SITEMAP_URL = 'https://www.lidl.nl/p/export/NL/nl/product_sitemap.xml.gz';
const OUTPUT = 'products.json';
// Datum waarop de eerste catalogus is gemaakt; producten zonder datum krijgen deze.
const BASELINE_DATE = '2026-04-13';

const args = new Set(process.argv.slice(2));
const FULL = args.has('--full');
const OFFLINE = args.has('--offline');

// Non-food merken en woorden in de productlink (aanvulling op het id-filter).
const NON_FOOD_PREFIXES = [
  'parkside', 'crivit', 'esmara', 'livergy', 'lupilu', 'livarno', 'silvercrest',
  'ernesto', 'bosch', 'vileda', 'wenko', 'bestway', 'hudora', 'tronic', 'sanitas',
  'powerfix', 'florabest', 'grillmeister', 'auriol', 'zoofari', 'miomare',
  'aquapur', 'playtive', 'lego', 'philips', 'braun', 'oral-b', 'karcher',
  'einhell', 'gardena', 'weber', 'meradiso', 'rocktrail', 'ultimate-speed',
  'medisana', 'sensiplast', 'nevadent',
];
const NON_FOOD_KEYWORDS = [
  'stofzuiger', 'boormachine', 'fiets', 'tent-', 'slaapzak', 'schoen', 'sneaker',
  'sokken', 'ondergoed', 'dekbed', 'hoeslaken', 'gordijn', 'vloerkleed',
  'speelgoed', 'gereedschap', 'tuinmeubel', 'parasol', 'kookpan', 'koekenpan',
  'messenset', 'airfryer', 'koffiezetapparaat', 'waterkoker', 'broodrooster',
];

function isNonFoodSlug(slug) {
  const lower = slug.toLowerCase();
  return NON_FOOD_PREFIXES.some((p) => lower.startsWith(p))
    || NON_FOOD_KEYWORDS.some((k) => lower.includes(k));
}

function parseProductUrl(url) {
  const match = url.match(/\/p\/(.+?)\/p(\d+)$/);
  return match ? { url, slug: match[1], id: match[2] } : null;
}

function slugToName(slug) {
  const text = slug.replace(/-/g, ' ');
  return text.charAt(0).toUpperCase() + text.slice(1);
}

async function fetchWithRetry(url, retries = 3) {
  for (let i = 0; i < retries; i++) {
    try {
      const res = await fetch(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'nl-NL,nl;q=0.9',
        },
      });
      if (res.ok) return await res.text();
      if (res.status === 429) {
        await new Promise((r) => setTimeout(r, (i + 1) * 5000));
        continue;
      }
      return null;
    } catch {
      if (i < retries - 1) await new Promise((r) => setTimeout(r, 2000));
    }
  }
  return null;
}

function extractJsonLd(html) {
  const blocks = html.matchAll(/<script[^>]*type="application\/ld\+json"[^>]*>([\s\S]*?)<\/script>/g);
  for (const block of blocks) {
    try {
      const data = JSON.parse(block[1]);
      const list = Array.isArray(data) ? data : [data];
      const product = list.find((d) => d && d['@type'] === 'Product');
      if (product) return product;
    } catch { /* volgende blok proberen */ }
  }
  return null;
}

async function scrapeProduct(entry) {
  const html = await fetchWithRetry(entry.url);
  if (!html) return { ...entry, name: slugToName(entry.slug), brand: null, image: null };
  const jsonLd = extractJsonLd(html);
  const image = Array.isArray(jsonLd?.image) ? jsonLd.image[0] : jsonLd?.image;
  return {
    ...entry,
    name: jsonLd?.name || slugToName(entry.slug),
    brand: jsonLd?.brand?.name || (typeof jsonLd?.brand === 'string' ? jsonLd.brand : null),
    image: image || null,
  };
}

function loadExisting() {
  if (!existsSync(OUTPUT)) return { generatedAt: null, products: new Map() };
  const data = JSON.parse(readFileSync(OUTPUT, 'utf-8'));
  const products = new Map();
  for (const category of data.categories || []) {
    for (const p of category.products || []) {
      const parsed = parseProductUrl(p.url);
      if (!parsed) continue;
      products.set(p.url, { ...parsed, ...p, firstSeen: p.firstSeen || BASELINE_DATE });
    }
  }
  return { generatedAt: data.generatedAt || null, products };
}

async function loadSitemap() {
  console.log('🔄 Sitemap downloaden...');
  const res = await fetch(SITEMAP_URL);
  if (!res.ok) throw new Error(`Sitemap niet beschikbaar (HTTP ${res.status})`);
  const xml = gunzipSync(Buffer.from(await res.arrayBuffer())).toString('utf-8');
  const urls = xml.match(/https:\/\/www\.lidl\.nl\/p\/[^<]+/g) || [];
  console.log(`📦 ${urls.length} producten in de sitemap`);
  return urls.map(parseProductUrl).filter(Boolean);
}

function buildCatalog(products) {
  const byCategory = new Map(CATEGORIES.map((c) => [c.name, []]));
  const seen = new Set();

  for (const p of products) {
    const name = cleanName(p.name);
    const brand = cleanBrand(p.brand, p.slug);
    const category = categorize(name, p.slug, brand);
    // Dubbele producten (zelfde merk + naam) maar één keer tonen.
    const dedupeKey = `${category}|${normalize(brand || '')}|${normalize(name)}`;
    if (seen.has(dedupeKey)) continue;
    seen.add(dedupeKey);
    byCategory.get(category).push({
      name,
      brand,
      image: p.image || null,
      url: p.url,
      firstSeen: p.firstSeen,
    });
  }

  return CATEGORIES
    .map((c) => ({
      name: c.name,
      emoji: c.emoji,
      products: byCategory.get(c.name).sort((a, b) =>
        a.name.localeCompare(b.name, 'nl') || (a.brand || '').localeCompare(b.brand || '', 'nl')),
    }))
    .filter((c) => c.products.length > 0);
}

async function main() {
  const today = new Date().toISOString().slice(0, 10);
  const existing = loadExisting();
  console.log(`📂 ${existing.products.size} producten in huidige ${OUTPUT}`);

  let entries;
  let newEntries = [];
  let removed = 0;

  if (OFFLINE) {
    entries = [...existing.products.values()];
  } else {
    const sitemap = await loadSitemap();
    const food = sitemap.filter((p) => !isOnlineShopId(p.id) && !isNonFoodSlug(p.slug));
    console.log(`🍎 ${food.length} winkelproducten (webshop en non-food overgeslagen)`);

    const inSitemap = new Set(food.map((p) => p.url));
    removed = [...existing.products.keys()].filter((url) => !inSitemap.has(url)).length;

    const toScrape = food.filter((p) => FULL || !existing.products.has(p.url));
    console.log(`🌐 ${toScrape.length} productpagina's ophalen...`);

    const scraped = new Map();
    const BATCH_SIZE = 8;
    for (let i = 0; i < toScrape.length; i += BATCH_SIZE) {
      const batch = toScrape.slice(i, i + BATCH_SIZE);
      const results = await Promise.all(batch.map(scrapeProduct));
      for (const r of results) scraped.set(r.url, r);
      process.stdout.write(`\r   ${Math.min(i + BATCH_SIZE, toScrape.length)}/${toScrape.length}`);
      await new Promise((r) => setTimeout(r, 300));
    }
    if (toScrape.length) process.stdout.write('\n');

    entries = food.map((p) => {
      const old = existing.products.get(p.url);
      const fresh = scraped.get(p.url);
      if (!old) {
        const product = { ...fresh, firstSeen: today };
        newEntries.push(product);
        return product;
      }
      return fresh ? { ...fresh, firstSeen: old.firstSeen } : old;
    });
  }

  // Webshop-artikelen die nog in een oud bestand staan ook weghalen.
  entries = entries.filter((p) => !isOnlineShopId(p.id) && !isNonFoodSlug(p.slug));

  const categories = buildCatalog(entries);
  const total = categories.reduce((sum, c) => sum + c.products.length, 0);

  // Alleen een nieuwe datum zetten als de inhoud echt veranderd is.
  const previous = existsSync(OUTPUT) ? JSON.parse(readFileSync(OUTPUT, 'utf-8')) : null;
  const unchanged = previous && JSON.stringify(previous.categories) === JSON.stringify(categories);
  const generatedAt = unchanged && previous.generatedAt
    ? previous.generatedAt
    : new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');

  writeFileSync(OUTPUT, `${JSON.stringify({ generatedAt, categories }, null, 1)}\n`, 'utf-8');

  const lines = [
    `✅ ${total} producten in ${categories.length} categorieën${unchanged ? ' (geen wijzigingen)' : ''}`,
    ...categories.map((c) => `   ${c.emoji} ${c.name}: ${c.products.length}`),
  ];
  if (!OFFLINE) {
    lines.push(`🆕 Nieuw: ${newEntries.length}   🗑️ Uit assortiment: ${removed}`);
    for (const p of newEntries.slice(0, 50)) {
      const brand = cleanBrand(p.brand, p.slug);
      lines.push(`   + ${brand ? `${brand} ` : ''}${cleanName(p.name)}`);
    }
    if (newEntries.length > 50) lines.push(`   ... en nog ${newEntries.length - 50}`);
  }
  console.log(lines.join('\n'));

  if (process.env.GITHUB_STEP_SUMMARY) {
    appendFileSync(process.env.GITHUB_STEP_SUMMARY, `\`\`\`\n${lines.join('\n')}\n\`\`\`\n`);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
