import { gunzipSync } from 'node:zlib';
import { writeFileSync } from 'node:fs';

const SITEMAP_URL = 'https://www.lidl.nl/p/export/NL/nl/product_sitemap.xml.gz';

// Known non-food brand prefixes in URL slugs
const NON_FOOD_PREFIXES = [
  'parkside', 'crivit', 'esmara', 'livergy', 'lupilu', 'livarno',
  'silvercrest', 'sansibar', 'ernesto', 'hummel', 'under-armour',
  'puma', 'adidas', 'bosch', 'vileda', 'wenko', 'bestway',
  'schildmeyer', 'osann', 'hudora', 'tambu', 'reebok', 'roba',
  'tronic', 'char-broil', 'greemotion', 'ridder', 'sanitas',
  'donic-schildkrot', 'rowenta', 'qbrick', 'masterpro', 'bayer-design',
  'livarno-home', 'livarno-lux', 'silvercrest-kitchen-tools',
  'schildkrot', 'nike', 'kappa', 'champion', 'mexx', 'tom-tailor',
  'lee', 'mustang', 'tennispoint', 'active-touch',
  'rocktrail', 'ultimate-speed', 'powerfix', 'florabest',
  'grillmeister', 'auriol', 'zoofari', 'ordex',
  'miomare', 'aquapur', 'sensiplast', 'nevadent',
  'lifegoods', 'medisana', 'fisher-price', 'playtive',
  'lego', 'hot-wheels', 'barbie', 'chicco', 'nuk',
  'philips', 'braun', 'oral-b', 'gorenje', 'severin',
  'melitta-caffeo', 'delonghi', 'krups', 'kenwood',
  'sharp', 'toshiba', 'lenovo', 'hp-', 'canon',
  'samsung', 'lg-', 'grundig', 'karcher', 'kaercher',
  'makita', 'einhell', 'stanley', 'dewalt', 'metabo',
  'gardena', 'weber', 'campingaz', 'coleman',
  'casa-royale', 'home-creation', 'meradiso', 'dreamtex',
  'eleganza', 'my-living-style', 'livarno-living',
  'cien-sun', 'w5-', 'formil',
  'high-peak', 'mckinley', 'crane', 'newletics',
  'auriol-next', 'stihl', 'festool',
  'peppa-pig', 'paw-patrol', 'disney-',
  'switch-on', 'stunt-scooter',
  'hg-', 'tesa-', 'uhu-', 'pattex',
];

// Additional non-food keywords that appear in URL slugs
const NON_FOOD_KEYWORDS = [
  'stofzuiger', 'boormachine', 'schroefmachine', 'slijper',
  'werkbroek', 'werkschoen', 'werkhandschoen',
  'fiets', 'fietsband', 'fietslamp', 'fietsslot',
  'tent', 'slaapzak', 'luchtbed', 'campingstoel',
  'dames-', 'heren-', 'kinder-', 'baby-', 'meisjes-', 'jongens-',
  'jas-', 'broek-', 'shirt-', 'jurk-', 'rok-', 'trui-',
  'schoen', 'sneaker', 'laars', 'sandaal', 'slipper',
  'ondergoed', 'sokken', 'bh-', 'hipster', 'boxer',
  'handdoek-set', 'badhanddoek', 'washandje',
  'dekbed-', 'kussen-', 'hoeslaken', 'laken-',
  'gordijn', 'vitrage', 'rolgordijn', 'plisse',
  'vloerkleed', 'tapijt', 'mat-',
  'lamp-', 'ledlamp', 'buitenlamp', 'tafellamp', 'staande-lamp',
  'accu-', 'batterij-', 'oplader', 'adapter',
  'kinderwagen', 'autostoel', 'kinderstoel',
  'speelgoed', 'puzzel-', 'bordspel',
  'gereedschap', 'zaag-', 'hamer-', 'tang-',
  'tuinmeubel', 'tuinstoel', 'tuintafel', 'parasol',
  'loungeset', 'ligstoel', 'hangmat',
  'plantenbak', 'bloempot', 'tuinslang',
  'opbergbox', 'opbergmand', 'opbergkast',
  'boekenplank', 'stellingkast', 'kast-',
  'spiegel-', 'fotolijst', 'wanddecoratie',
  'bloeddrukmeter', 'thermometer-', 'weegschaal-',
  'koptelefoon', 'oordop', 'luidspreker', 'speaker',
  'powerbank', 'usb-', 'hdmi-', 'kabel-',
  'printer', 'scanner', 'monitor-',
  'koffer', 'rugzak-', 'tas-',
  'horloge', 'sieraad', 'armband-', 'ketting-',
  'zonnebril', 'leesbril',
  'paraplu', 'regenpak',
  'verfrol', 'kwast-', 'verf-',
  'behang', 'laminaat', 'pvc-vloer',
  'douchekop', 'kraan-', 'douchegordijn',
  'toiletbril', 'wc-borstel',
  'strijkijzer', 'strijkplank',
  'waslijn', 'droogrek', 'droogmolen',
  'bezem', 'dweil-', 'emmer-',
  'prullenbak', 'pedaalemmer',
  'brievenbus', 'huisnummer',
  'rookmelder', 'brandmelder',
  'slot-', 'hangslot', 'deurslot',
  'tv-meubel', 'wandmeubel', 'dressoir',
  'eettafel', 'stoel-', 'kruk-', 'bank-',
  'matras-', 'lattenbodem', 'bedframe',
  'sierkussen', 'plaid-', 'deken-',
  'kaars-', 'geurkaars', 'waxinelicht',
  'vaas-', 'bloemenvaas',
  'kookpan', 'braadpan', 'koekenpan', 'wok-pan',
  'ovenschaal', 'bakvorm', 'springvorm',
  'messenset', 'koksmes', 'broodmes',
  'snijplank', 'hakblok',
  'bestek-', 'lepel-', 'vork-', 'mes-set',
  'bord-set', 'servies', 'kommetje',
  'wijnglas', 'bierglas', 'waterglas', 'mok-',
  'thermosfles', 'drinkfles', 'bidon',
  'lunchbox', 'broodtrommel',
  'bbq-', 'barbecue', 'houtskool',
  'zwemband', 'zwembad-', 'zwembril',
  'fitness-', 'halter-', 'yogamat',
  'springtouw', 'weerstandsband',
  'voetbal-', 'basketbal-', 'tennis-',
  'skateboard', 'step-', 'inline-',
  'duikbril', 'snorkel',
  'ski-', 'snowboard',
];

function isFoodProduct(slug) {
  const lower = slug.toLowerCase();
  for (const prefix of NON_FOOD_PREFIXES) {
    if (lower.startsWith(prefix)) return false;
  }
  for (const kw of NON_FOOD_KEYWORDS) {
    if (lower.includes(kw)) return false;
  }
  return true;
}

// Category mapping based on common food keywords in URL slugs
const CATEGORY_KEYWORDS = {
  'Zuivel, plantaardig & eieren': [
    'melk', 'yoghurt', 'kwark', 'skyr', 'vla', 'pudding', 'room',
    'boter', 'margarine', 'kaas', 'ei-', 'eieren',
    'zuivel', 'cottage-cheese', 'creme-fraiche', 'slagroom',
    'karnemelk', 'buttermilk', 'kefir', 'halvarine',
    'mascarpone', 'ricotta', 'mozzarella', 'burrata',
    'tofu', 'tempeh', 'soja-', 'haver-', 'amandel-', 'kokos-',
    'plantaardig', 'vegan-melk', 'lactosevrij',
  ],
  'Groente & fruit': [
    'paprika', 'tomaat', 'tomat', 'komkommer', 'sla-', 'salade',
    'ui-', 'uien', 'aardappel', 'wortel', 'peen',
    'broccoli', 'bloemkool', 'spinazie', 'andijvie',
    'courgette', 'aubergine', 'champignon', 'paddenstoel',
    'prei', 'selderij', 'venkel', 'radijs',
    'appel', 'peer', 'banaan', 'sinaasappel', 'mandarijn',
    'citroen', 'limoen', 'druif', 'druiven', 'aardbei', 'framboz',
    'bosbes', 'blauwe-bes', 'kers', 'perzik', 'nectarine',
    'pruim', 'mango', 'ananas', 'meloen', 'watermeloen',
    'kiwi', 'avocado', 'granaatappel',
    'groente', 'fruit', 'soepgroente', 'roerbak', 'wokgroente',
    'sperzieboon', 'snijboon', 'doperwt', 'mais-',
    'knoflook', 'gember', 'rode-kool', 'witte-kool',
    'spruit', 'boerenkool', 'snij-',
  ],
  'Vers vlees, vis & vega': [
    'kip-', 'kipfilet', 'kipdrumstick', 'kippenpoot', 'kippenbouten',
    'gehakt', 'rundergehakt', 'half-om-half', 'tartaar',
    'biefstuk', 'entrecote', 'rosbief', 'rib-eye', 'bavette',
    'varkensvlees', 'schnitzel', 'karbonade', 'speklapjes',
    'worst-', 'braadworst', 'rookworst',
    'lam-', 'lamsvlees', 'lamsrack',
    'zalm', 'tonijn', 'kabeljauw', 'pangasius', 'garnaal',
    'haring', 'makreel', 'forel', 'tilapia',
    'vis-', 'visfilet', 'visstick',
    'vega-', 'vegetarisch', 'vegaburger', 'vegan-',
    'filetlapjes', 'stoofvlees', 'sucadelapjes',
    'hamburger', 'slavink', 'frikandel', 'kroket',
    'shoarma', 'gyros', 'kebab',
    'sparerib', 'pulled-pork', 'bbq-vlees',
    'gemarineer',
  ],
  'Vleeswaren & beleg': [
    'ham-', 'achterham', 'boterhamworst', 'cervelaat',
    'salami', 'chorizo', 'pepperoni', 'mortadella',
    'rookvlees', 'rosbief-beleg', 'kipfilet-beleg',
    'leverworst', 'paté', 'pate-', 'leverpastei',
    'beleg', 'vleeswaren', 'plakken',
    'pindakaas', 'hagelslag', 'vlokken', 'gestampte-muisjes',
    'jam-', 'marmelade', 'stroop', 'honing',
    'chocoladepasta', 'hazelnootpasta', 'speculoospasta',
    'appelstroop', 'rinse-appelstroop',
    'sandwichspread', 'smeerkaas', 'zuivelspread',
  ],
  'Kaas': [
    'kaas', 'gouda', 'edammer', 'leidse', 'boerenkaas',
    'oude-kaas', 'jonge-kaas', 'belegen',
    'brie', 'camembert', 'geitenkaas', 'schapenkaas',
    'parmezaan', 'gruyere', 'emmentaler', 'cheddar',
    'raclette', 'fondue-kaas',
    'feta', 'halloumi', 'haloumi',
    'roomkaas', 'cream-cheese',
    'geraspte-kaas', 'kaasplak', 'kaasblokjes',
    'tapas-kaas',
  ],
  'Brood & bakkerij': [
    'brood', 'volkoren', 'witbrood', 'meergranen', 'rogge',
    'croissant', 'pistolet', 'bolletje', 'kaiserbrood',
    'stokbrood', 'ciabatta', 'focaccia', 'baguette',
    'knackebrod', 'cracker', 'beschuit', 'toast',
    'wrap', 'tortilla', 'pita', 'naan',
    'cake', 'taart', 'gebak', 'muffin', 'donut',
    'pannenkoek', 'poffertjes', 'wafel',
    'bakmix', 'bloem', 'gist', 'bakpoeder',
    'suiker', 'vanillesuiker', 'poedersuiker',
    'bakproduct',
  ],
  'Ontbijt & cereals': [
    'muesli', 'granola', 'havermout', 'ontbijtgranen',
    'cornflakes', 'cruesli', 'ontbijt',
    'havervlokken', 'overnight-oats',
    'pancake-mix', 'pannenkoekenmix',
    'fruitreep', 'mueslireep', 'ontbijtkoek',
    'cereals', 'chia-', 'lijnzaad',
  ],
  'Pasta, rijst & wereldkeuken': [
    'pasta', 'spaghetti', 'penne', 'fusilli', 'macaroni',
    'tagliatelle', 'farfalle', 'rigatoni', 'linguine',
    'lasagne', 'tortelloni', 'ravioli', 'gnocchi',
    'noodle', 'mie-', 'bami-', 'ramen',
    'rijst', 'basmati', 'jasmijn', 'risotto',
    'couscous', 'bulgur', 'quinoa',
    'taco', 'nacho', 'burrito', 'enchilada',
    'woksaus', 'ketjap', 'sambal', 'sriracha',
    'sojasaus', 'oestersaus', 'hoisin',
    'curry', 'tandoori', 'tikka-masala',
    'kroepoek', 'loempia',
  ],
  'Sauzen, kruiden & olie': [
    'saus', 'ketchup', 'mayonaise', 'mayo', 'mosterd',
    'dressing', 'vinaigrette',
    'tomatensaus', 'pastasaus', 'pesto',
    'kruiden', 'specerij', 'peper', 'zout-', 'paprikapoeder',
    'oregano', 'basilicum', 'tijm', 'rozemarijn', 'kaneel',
    'bouillon', 'fond', 'jus',
    'olijfolie', 'zonnebloemolie', 'olie-', 'azijn',
    'balsamico', 'wijnazijn',
    'tabasco', 'worcestershire',
  ],
  'Conserven & soepen': [
    'conserv', 'blik-', 'ingeblik',
    'tomatenblok', 'tomatenpuree', 'passata', 'gepelde-tomat',
    'kikkererwt', 'kidney', 'bruine-bon', 'witte-bon',
    'linzen', 'kappertjes', 'olijven',
    'soep-', 'bouillon-', 'cup-a-soup',
    'tonijn-blik', 'sardine', 'ansjovis',
    'augurk', 'zilverui', 'zuurkool',
    'mais-blik', 'doperwten-blik',
    'compote', 'vruchten-op-siroop',
  ],
  'Diepvries': [
    'diepvries', 'vriezer',
    'pizza-diep', 'oven-frites', 'friet', 'kroketten-diep',
    'ijsje', 'magnum', 'cornetto', 'raket',
    'diepvries-groente', 'diepvries-fruit',
    'visstick', 'fish-finger',
    'oven-', 'airfryer-',
  ],
  'Snacks, koeken & noten': [
    'chips', 'chip-', 'paprika-chips', 'naturel-chips',
    'bugles', 'doritos', 'pringles', 'lays',
    'popcorn', 'pretzel', 'sticks',
    'noten', 'pinda', 'cashew', 'amandel', 'walnoot', 'pistachio',
    'nootjes', 'notenmix', 'studentenhaver',
    'koek', 'biscuit', 'speculaas', 'stroopwafel',
    'gevulde-koek', 'eierkoek', 'bastogne',
    'cracker-snack', 'rijstwafel', 'maiswaf',
    'onion-ring', 'borrel', 'snack-',
    'fruitreep', 'energiereep', 'proteinereep',
    'macadamia', 'pecan',
  ],
  'Snoep & chocolade': [
    'snoep', 'drop', 'winegum', 'lolly',
    'chocolade', 'chocola', 'bonbon', 'praline',
    'haribo', 'katja', 'venco',
    'reep-', 'tablet-choco', 'melkchocolade',
    'gummi', 'toffee', 'karamel-snoep',
    'zuurtje', 'pepermunt', 'menthos',
    'salmiak', 'honingdrop',
    'choco-', 'duetti',
  ],
  'Frisdrank, sap & water': [
    'frisdrank', 'cola', 'fanta', 'sprite', 'pepsi',
    'limonade', 'sinas', 'cassis', 'ice-tea',
    'energy-drink', 'sportdrank', 'isotonisch',
    'sap-', 'sinaasappelsap', 'appelsap', 'tomatensap',
    'smoothie', 'multivitamine',
    'water-', 'mineraalwater', 'bronwater', 'bruiswater',
    'siroop', 'ranja', 'diksap', 'limonadesiroop',
    'tonic', 'bitter-lemon', 'ginger-ale',
    'vruchtenmix', 'vruchtensap', 'solevita',
    'verse-sap',
  ],
  'Koffie & thee': [
    'koffie', 'espresso', 'cappuccino', 'latte',
    'koffieboon', 'koffiepad', 'koffiecup', 'koffiecapsule',
    'filterkoffie', 'oploskoffie', 'instant-koffie',
    'thee-', 'groene-thee', 'zwarte-thee', 'kruidenthee',
    'rooibos', 'earl-grey', 'kamille', 'munt-thee',
    'cacao', 'chocolademelk', 'chocomel',
  ],
  'Bier & wijn': [
    'bier', 'pils', 'weizen', 'ipa-', 'lager', 'ale-',
    'radler', 'alcoholvrij-bier',
    'wijn', 'rode-wijn', 'witte-wijn', 'rose',
    'prosecco', 'champagne', 'cava', 'mousserende',
    'port', 'sherry',
  ],
  'Huishouden & schoonmaak': [
    'afwasmiddel', 'vaatwasmiddel', 'vaatwas',
    'wasmiddel', 'wasverzachter', 'vlekverwijderaar',
    'allesreiniger', 'glasreiniger', 'sanitairreiniger',
    'schoonmaak', 'ontkalker', 'bleek',
    'toiletblok', 'gootsteenontstopper',
    'vuilniszak', 'pedaalemmerzak',
    'keukenpapier', 'keukenrol', 'toiletpapier', 'zakdoek',
    'huishoudfolie', 'bakpapier', 'aluminiumfolie', 'clingfilm',
    'luier', 'billendoekje',
    'kattenbak', 'kattenvoer', 'hondenvoer', 'diervoer',
    'waxinelichtje',
  ],
  'Verzorging': [
    'shampoo', 'douchegel', 'zeep', 'handzeep',
    'tandpasta', 'tandenborstel', 'mondwater',
    'deodorant', 'deo-', 'bodylotion', 'handcreme',
    'gezichtscreme', 'dagcreme', 'nachtcreme',
    'scheermesje', 'scheerschuim', 'aftershave',
    'haarlak', 'haargel', 'conditioner',
    'make-up', 'mascara', 'lippenstift',
    'zonnecreme', 'zonnebrand', 'aftersun',
    'cien-', 'cien ',
    'maandverband', 'tampon',
    'pleisters', 'verband',
    'vitamines', 'supplement',
  ],
  'Verse maaltijden & pizza': [
    'pizza', 'verse-pizza', 'verse-pasta',
    'maaltijd', 'kant-en-klaar',
    'saladeschotel', 'lunchsalade',
    'hummus', 'tzatziki', 'guacamole',
    'tapas', 'antipasti',
    'wrap-maaltijd', 'sushi',
    'soep-vers',
  ],
};

function categorizeProduct(slug, name) {
  const text = `${slug} ${name}`.toLowerCase();
  for (const [category, keywords] of Object.entries(CATEGORY_KEYWORDS)) {
    for (const kw of keywords) {
      if (text.includes(kw.replace('-', ''))) return category;
      if (text.includes(kw)) return category;
    }
  }
  return null; // Unknown — will try to get from page
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
        console.log(`  Rate limited, waiting ${(i + 1) * 5}s...`);
        await new Promise(r => setTimeout(r, (i + 1) * 5000));
        continue;
      }
      return null;
    } catch {
      if (i < retries - 1) await new Promise(r => setTimeout(r, 2000));
    }
  }
  return null;
}

function extractJsonLd(html) {
  const match = html.match(/<script[^>]*type="application\/ld\+json"[^>]*>([\s\S]*?)<\/script>/);
  if (!match) return null;
  try {
    const data = JSON.parse(match[1]);
    if (data['@type'] === 'Product') return data;
    if (Array.isArray(data)) return data.find(d => d['@type'] === 'Product');
    return null;
  } catch {
    return null;
  }
}

function extractBrandFromPage(html, productName) {
  // Try meta tag
  const metaMatch = html.match(/<meta[^>]*property="product:brand"[^>]*content="([^"]+)"/);
  if (metaMatch) return metaMatch[1];
  // Try og:brand
  const ogMatch = html.match(/<meta[^>]*property="og:brand"[^>]*content="([^"]+)"/);
  if (ogMatch) return ogMatch[1];
  // Try data attribute
  const dataMatch = html.match(/data-brand="([^"]+)"/);
  if (dataMatch) return dataMatch[1];

  // Extract from product image alt text — Lidl often puts "Brand ProductName" in alt
  const altMatches = html.matchAll(/<img[^>]*alt="([^"]+)"[^>]*>/g);
  for (const m of altMatches) {
    const alt = m[1].trim();
    // Skip generic alts
    if (!alt || alt.length < 3 || alt === productName) continue;
    // If alt starts with a capitalized word that isn't in the product name, it's likely the brand
    if (productName && alt.toLowerCase().includes(productName.toLowerCase().slice(0, 10))) {
      const altLower = alt.toLowerCase();
      const nameLower = productName.toLowerCase();
      // Brand is the part of alt that isn't in the product name
      const firstWord = alt.split(/\s+/)[0].replace(/[®™.,!]/g, '');
      if (firstWord.length >= 2 && !nameLower.startsWith(firstWord.toLowerCase())) {
        return firstWord;
      }
    }
  }

  return null;
}

function extractCategory(html) {
  // Try to find category from breadcrumb or meta tags
  const breadcrumbMatch = html.match(/"breadcrumb"[^}]*"itemListElement"\s*:\s*\[([\s\S]*?)\]/);
  if (breadcrumbMatch) {
    try {
      const items = JSON.parse(`[${breadcrumbMatch[1]}]`);
      // Find the category level (usually 2nd or 3rd item)
      for (const item of items) {
        const name = item?.name || item?.item?.name || '';
        if (name && !name.includes('Home') && !name.includes('Assortiment') && !name.includes('Producten')) {
          return name;
        }
      }
    } catch { /* ignore */ }
  }
  return null;
}

function slugToName(slug) {
  return slug
    .split('-')
    .map(w => w.charAt(0).toUpperCase() + w.slice(1))
    .join(' ');
}

async function main() {
  console.log('🔄 Downloading product sitemap...');
  const sitemapRes = await fetch(SITEMAP_URL);
  const sitemapGz = Buffer.from(await sitemapRes.arrayBuffer());
  const sitemapXml = gunzipSync(sitemapGz).toString('utf-8');

  // Extract all product URLs
  const urlMatches = sitemapXml.match(/https:\/\/www\.lidl\.nl\/p\/[^<]+/g) || [];
  console.log(`📦 Found ${urlMatches.length} total products in sitemap`);

  // Parse URLs into structured data
  const allProducts = urlMatches.map(url => {
    const match = url.match(/\/p\/(.+?)\/p(\d+)$/);
    if (!match) return null;
    return { url, slug: match[1], id: match[2] };
  }).filter(Boolean);

  // Filter for food products
  const foodProducts = allProducts.filter(p => isFoodProduct(p.slug));
  console.log(`🍎 Filtered to ${foodProducts.length} potential food products`);

  // Pre-categorize what we can from slugs
  let preCategorized = 0;
  for (const p of foodProducts) {
    p.category = categorizeProduct(p.slug, '');
    if (p.category) preCategorized++;
  }
  console.log(`📁 Pre-categorized ${preCategorized}/${foodProducts.length} from URL slugs`);

  // Scrape product pages for details
  const BATCH_SIZE = 10;
  const DELAY = 300; // ms between batches
  let scraped = 0;
  let failed = 0;

  console.log(`\n🌐 Scraping ${foodProducts.length} product pages (this may take a while)...\n`);

  for (let i = 0; i < foodProducts.length; i += BATCH_SIZE) {
    const batch = foodProducts.slice(i, i + BATCH_SIZE);
    const results = await Promise.all(batch.map(async (product) => {
      const html = await fetchWithRetry(product.url);
      if (!html) {
        failed++;
        product.name = slugToName(product.slug);
        return;
      }

      const jsonLd = extractJsonLd(html);
      if (jsonLd) {
        product.name = jsonLd.name || slugToName(product.slug);
        product.image = jsonLd.image?.[0] || jsonLd.image || null;
        product.brand = jsonLd.brand?.name || extractBrandFromPage(html, product.name) || null;
      } else {
        product.name = slugToName(product.slug);
        product.brand = extractBrandFromPage(html, product.name) || null;
      }

      // Try to get category from page if not already categorized
      if (!product.category) {
        const pageCategory = extractCategory(html);
        if (pageCategory) {
          product.category = pageCategory;
        } else {
          product.category = categorizeProduct(product.slug, product.name);
        }
      }

      scraped++;
    }));

    const progress = Math.min(i + BATCH_SIZE, foodProducts.length);
    const pct = ((progress / foodProducts.length) * 100).toFixed(1);
    process.stdout.write(`\r  Progress: ${progress}/${foodProducts.length} (${pct}%) — scraped: ${scraped}, failed: ${failed}`);

    await new Promise(r => setTimeout(r, DELAY));
  }

  console.log('\n');

  // Organize by category
  const categoryMap = {};
  let uncategorized = 0;

  for (const p of foodProducts) {
    if (!p.name) continue;
    const cat = p.category || 'Overig';
    if (cat === 'Overig') uncategorized++;
    if (!categoryMap[cat]) categoryMap[cat] = [];
    categoryMap[cat].push({
      name: p.name,
      brand: p.brand || null,
      image: p.image || null,
      url: p.url,
    });
  }

  // Sort categories and products
  const categories = Object.entries(categoryMap)
    .sort(([a], [b]) => {
      if (a === 'Overig') return 1;
      if (b === 'Overig') return -1;
      return a.localeCompare(b, 'nl');
    })
    .map(([name, products]) => ({
      name,
      products: products.sort((a, b) => a.name.localeCompare(b.name, 'nl')),
    }));

  const totalProducts = categories.reduce((sum, c) => sum + c.products.length, 0);

  const output = { categories };
  writeFileSync('products.json', JSON.stringify(output, null, 2), 'utf-8');

  console.log('✅ Done!\n');
  console.log(`📊 Summary:`);
  console.log(`   Total products: ${totalProducts}`);
  console.log(`   Categories: ${categories.length}`);
  console.log(`   Uncategorized: ${uncategorized}`);
  console.log(`   Failed to scrape: ${failed}\n`);
  console.log('Categories:');
  for (const cat of categories) {
    console.log(`   ${cat.name}: ${cat.products.length} products`);
  }
  console.log(`\n📄 Saved to products.json`);
}

main().catch(console.error);
