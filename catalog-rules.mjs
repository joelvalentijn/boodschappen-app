// Regels om Lidl-producten op te schonen: non-food eruit, merknamen
// rechtzetten en elk product in een categorie plaatsen.
// Wordt gebruikt door scraper.mjs.

// Categorieën in winkelvolgorde, met emoji voor de app en de website.
export const CATEGORIES = [
  { name: 'Groente & fruit', emoji: '🥦' },
  { name: 'Brood & bakkerij', emoji: '🍞' },
  { name: 'Vers vlees, vis & vega', emoji: '🥩' },
  { name: 'Vleeswaren & beleg', emoji: '🥪' },
  { name: 'Kaas', emoji: '🧀' },
  { name: 'Zuivel, plantaardig & eieren', emoji: '🥛' },
  { name: 'Verse maaltijden & pizza', emoji: '🍕' },
  { name: 'Pasta, rijst & wereldkeuken', emoji: '🍝' },
  { name: 'Sauzen, kruiden & olie', emoji: '🫒' },
  { name: 'Conserven & soepen', emoji: '🥫' },
  { name: 'Ontbijt & cereals', emoji: '🥣' },
  { name: 'Koffie & thee', emoji: '☕' },
  { name: 'Snoep & chocolade', emoji: '🍫' },
  { name: 'Snacks, koeken & noten', emoji: '🍪' },
  { name: 'Frisdrank, sap & water', emoji: '🥤' },
  { name: 'Bier & wijn', emoji: '🍷' },
  { name: 'Diepvries', emoji: '🧊' },
  { name: 'Huishouden & schoonmaak', emoji: '🧹' },
  { name: 'Verzorging', emoji: '🧴' },
  { name: 'Huisdieren', emoji: '🐾' },
  { name: 'Bloemen & planten', emoji: '💐' },
  { name: 'Overig', emoji: '📦' },
];

// Producten uit de Lidl-webshop (e-bikes, lampen, gereedschap...) hebben een
// product-id van 9 of meer cijfers. Winkelproducten hebben kortere id's.
export function isOnlineShopId(id) {
  return String(id).length >= 9;
}

// Tekst normaliseren: kleine letters, zonder accenten, alleen letters/cijfers.
export function normalize(text) {
  return ` ${String(text || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[‘’'`´]/g, '')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()} `;
}

// Volgorde is belangrijk: de eerste categorie die past wint. Specifieke
// categorieën (drank, beleg, zuivel) staan vóór groente & fruit, zodat
// "appelsap" of "aardbeienyoghurt" niet bij het fruit terechtkomt.
const RULES = [
  ['Huisdieren', [
    /\bhonden|\bhond\b|\bkatten|\bkat\b|\bpuppy|\bkitten/,
    /dierenvoer|vogelvoer|knaagdier|kauwbot|kauwstaaf|strooisel|kattengrit|\bvogelzaad/,
  ]],
  ['Verzorging', [
    /babydoekjes|voetencreme|manicure|creatine/,
    /scheermes|\bdeo|handgel|desinfect|haarmousse|flosdraad|tandenstoker|incontinentie|gezichtsdoekjes|cremespoeling|shower|collageen|\brxt\b|paracetamol|ibuprofen|gaviscon|strepsils|bisolvon|lenzenvloeistof|neusspray|aquafresh|sensodyne|parodontax|zuigtablet|kauwtablet|\bvitalhair|brillenpoets/,
    /shampoo|douche|zeep|handzeep|tandpasta|tandenborstel|tandzijde|mondwater|mondspoeling/,
    /deodorant|\bdeo\b|bodylotion|bodymilk|handcreme|dagcreme|nachtcreme|gezichtscreme|voetcreme|bodycreme|creme douche/,
    /\bscheer|aftershave|haarlak|haargel|haarverf|haarspray|conditioner|\bstyling|make up|mascara|lippenbalsem|lipbalsem|nagellak/,
    /zonnebrand|zonnecreme|aftersun|parfum|eau de toilette|maandverband|inlegkruisje|tampon|pleister|\bluier|billendoekje/,
    /wattenschijf|wattenstaaf|wattenstaafjes|micellair|gezichtsreiniging|reinigingsdoekje|serum|gezichtsmasker|badschuim|badzout/,
    /multivitamine tabl|vitamine [a-z0-9]+ tabl|\bvitamines\b|supplement|bruistablet|keelpastille|hoestbonbon|hoestsiroop/,
  ]],
  ['Huishouden & schoonmaak', [
    /afwasborstel|anti kalk|containerzak|huishouddoek|schuurmiddel|ontvetter|\bfinish\b|\bvanish\b|toiletreinig|\bdraagtas|melder\b/,
    /afwasmiddel|vaatwas|wasmiddel|wasverzachter|waspoeder|wascapsule|vlekverwijder|reiniger|schoonmaak|ontkalker|\bbleek\b|dikke bleek/,
    /toiletblok|\bwc |ontstopper|vuilniszak|afvalzak|pedaalemmerzak|keukenpapier|keukenrol|toiletpapier|\bzakdoek|tissues/,
    /huishoudfolie|vershoudfolie|aluminiumfolie|magnetronfolie|bakpapier|diepvrieszak|boterhamzak|sandwichzak|spons|vaatdoek|microvezel/,
    /\bkaars|waxinelicht|theelicht|batterij|lucifer|aansteker|luchtverfrisser|geurstok|geurzak|wasparfum|\bvochtig toiletpapier/,
    /\bw5\b|\bformil\b|\bfloralys\b|\bdenkmit\b/,
  ]],
  ['Bloemen & planten', [
    /fuchsia|klimplant|dipladenia|bloemenzaden/,
    /\bbloemen\b|\bboeket|\btulpen|\brozen\b|pioenrozen|orchidee|chrysant|hortensia|kamerplant|\bplant\b|\bplanten\b|\bpotgrond|\bcanna\b|\blelies|\bgerbera|bloembollen|\bvaste planten/,
  ]],
  ['Bier & wijn', [
    /aperitivo/,
    /stijl drank|paulaner|limoncello|liebfraumilch|veltliner|spatlese|zweigelt|valdepenas|vinho|appasimento|\bgrillo\b|bag in box|cocktails?\b|\btafelwijn|huiswijn/,
    /\bbier\b|bieren\b|\bpils|pilsener|weizen|witbier|\bipa\b|\blager\b|\bale\b|\bradler|tripel|dubbel bier|\bbock|\bstout\b|speciaalbier|\bkrat\b|\bamstel|heineken|hertog jan|grolsch|\bbavaria|\bleffe|affligem|la chouffe|\bduvel|hoegaarden|\bcorona\b|desperados|\bkordaat|perlenbacher|\bbrand bier|jupiler|texels|skuumkoppe|\bveltins/,
    /\bwijn(?!azijn)|wijn\b|\bwijnen\b|\brose\b|\bprosecco|champagne|\bcava\b|cremant|mousserend|\bport\b(?! salut)|\badvocaat\b|\bsherry|likeur|whisky|wodka|vodka|\brum\b|\bgin\b|jenever|cognac|brandy|\bamaretto\b|aperol|\bspritz|sangria|\bcider\b/,
    /chianti|merlot|cabernet|sauvignon|chardonnay|pinot|riesling|shiraz|syrah|tempranillo|\brioja|bordeaux|primitivo|montepulciano|malbec|grenache|chenin|zinfandel|\bgarnacha|\bverdejo|\bbeaujolais|\bbourgogne|\bmacon\b|\bmuscadet|\bsoave\b|\bvalpolicella|\bamarone|\bbarolo|\bchablis|\bcotes\b|\bcoteaux|\bchateau|\bcrianza|\breserva\b|\bbrut\b|\bcuvee|\bpays d oc|\bdoc\b|\bigp\b|\baoc\b|\bvin\b|\bvino\b|\bhugo\b/,
  ]],
  ['Frisdrank, sap & water', [
    /vruchtendrank|nekar\b|vitamin drink/,
    /shots?\b|\baa drink|\baa iso|\barizona|dubbeldrank|dubbelfris|fuze tea|\boasis\b|red ?bull|\brivella|schweppes|proteine drink/,
    /frisdrank|\bcola\b|coca cola|\bpepsi|\bfanta|\bsprite|\b7up|\bsinas\b|\bcassis\b|limonade|ice tea|\bicetea|ijsthee|energy drink|energydrink|\benergy\b|sportdrank|isotoon|isotonic/,
    /sap\b|sappen\b|\bnektar|\bnectar\b|smoothie|(?<!in )water\b|\bspa\b|chaudfontaine|siroop|\branja|diksap|\btonic\b|bitter lemon|ginger ale|ginger beer|kokoswater|\bdrinkpakje|\bfreeway\b|\bsolevita\b|\bsaskia\b|\bvittel|\bbcaa drink|cranberrydrink|\bkong strong/,
  ]],
  ['Koffie & thee', [
    /english blend|\bcafe\b|coffee/,
    /koffie|espresso|cappuccino|\blatte\b|\blungo|ristretto|capsules|\bcups\b|oploskoffie|filterkoffie|\bbonen koffie|koffiebonen|\bsenseo|nespresso|dolce gusto|\bbellarom|douwe egberts|\blor\b|nescafe/,
    /\bthee\b|thee\b|rooibos|earl grey|\bchai\b|\bcacao|chocolademelk|warme chocolade|\blord nelson|\bmatcha/,
  ]],
  ['Diepvries', [
    /sorbet|ijsklontjes|potatoes|chickenwings|minisnacks/,
    /diepvries|bevroren|\bijs\b|\bijsjes|roomijs|waterijs|schepijs|ijstaart|ijsblokjes|\bmagnum|cornetto|\braket|\bgelatelli|\bbon gelati|\bijshoorn/,
    /friet(?!saus)|\bfrites(?!saus)|\bpatat|ovenfriet|kreukelfriet|aardappelschijfjes|rosti|\bwedges|\bvissticks|bitterballen|kroketten|\bkroket\b|frikandel|\bsnacks mix|mini snacks|\bharvest basket/,
  ]],
  ['Verse maaltijden & pizza', [
    /pizza|piccolini|maaltijdsalade|(?<!fruit)salades?\b|\blasagne(?!bladen)/,
  ]],
  ['Kaas', [
    /babybel|bleu d|crefee|cambozola|fromage|roquefort|saint paulin|old amsterdam|groene hart|brie\b|brebis|\bmozarella|\beru\b|paturain|\brambol/,
    /(?<!pinda)kaas|\bgouda\b|goudse|edammer|\bleidse|boerenkaas|\bbrie\b|camembert|geitenkaas|\bfeta\b|halloumi|parmezaan|parmigiano|grana padano|gruyere|emmentaler|cheddar|raclette|fondue|mozzarella|burrata|mascarpone|ricotta|\bgorgonzola|\bmanchego|\bpecorino|\bcomte\b|port salut|\bpresident\b/,
  ]],
  ['Vleeswaren & beleg', [
    /bresaola|pekelvlees|prosciutto|\bjamon|schinken|kabbanossi|ossenworst|fijnproeversfilet|\bham(?!burger|lappen)|zuivelspread|veggiespread|metworst/,
    /pindakaas|hagelslag|\bvlokken\b|chocoladevlokken|muisjes|\bjam\b|(?<!a)jam\b|confiture|marmelade|appelstroop|schenkstroop|\bstroop\b|\bhoning|chocopasta|chocoladepasta|hazelnootpasta|speculoospasta|notenpasta|sandwichspread|boterhamkorrels|\bvruchtenhagel|\bchoco nussa|\bnutella|\bmaribel/,
    /\bham\b|ham\b|achterham|beenham|schouderham|cervelaat|salami|chorizo|pepperoni|mortadella|rookvlees|fricandeau|leverworst|\bpate\b|pate\b|leverpastei|boterhamworst|\bfilet americain|\bkipfilet beleg|\bgebraden gehakt|\bgebraden fricandeau|\bsnijworst|\bgekookte worst|\bgekookte ham|\bvleeswaren|\bbeleg\b|\brauwe ham|serrano|prosciutto crudo|\bpancetta|guanciale/,
  ]],
  ['Zuivel, plantaardig & eieren', [
    /fraiche|vla\b/,
    /actimel|yakult|kwark|dessert|room\b|zuivel|proviact|\bcroma\b|\bmild creamy/,
    /\bmelk\b|(?<!kokos)melk\b|halfvolle|volle melk|karnemelk|yoghurt|yogurt|\bkwark|\bskyr|\bvla\b|\bvla |pudding|\bslagroom|\bkookroom|\bzure room|creme fraiche|\broom\b|\bboter\b|roomboter(?!\s?(speculaas|krakeling|koek|cake|punt|croissant|amandel|kerst|stol|bol))|margarine|halvarine|\bbecel|\bblue band|\bkefir|\bdrinkyoghurt|\bchocomel|\bfristi|\bcampina|\bmilbona/,
    /\beieren\b|\bei\b|scharreleieren|\bvrije uitloop|\btofu\b|tempeh|sojadrink|haverdrink|amandeldrink|kokosdrink|rijstdrink|lactosevrij|\bvemondo bio drink|\bdesserts?\b|\bmousse\b|\btoetje|rijstepap|griesmeel|\bcottage cheese|\bhuttenkase/,
  ]],
  ['Ontbijt & cereals', [
    /kellogg|krokante mix/,
    /muesli|granola|havermout|\bcornflakes|cruesli|\bontbijt(?!spek)|\bcereals?\b|havervlokken|\boats\b|lijnzaad|chiazaad|\bpap\b|\bbrinta|\bquaker|\bcrownfield|\bmueslireep|\bchoco pops/,
  ]],
  ['Brood & bakkerij', [
    /kruimel|roggeblok|casino wit|meel\b/,
    /\bhalfje|tijger|volkoren\b|puntjes|bol\b|bollen\b|knackebrot|cronut|cake|bladerdeeg|pancakes|rietsuiker|stevia/,
    /brood|broodje|\bbolletjes|\bbollen\b|\bbol\b|croissant|pistolet|baguette|ciabatta|focaccia|knackebrod|crackers|beschuit|\btoast\b|melba toast|\bwraps?\b|tortilla|\bpita\b|\bnaan\b|\bcake\b|cakejes|\btaart|\bgebak|muffin|\bdonut|pannenkoek|poffertjes|(?<!roer)bakmix|\bmeel\b|\bbloem\b|tarwebloem|\bgist\b|bakpoeder|\bsuiker\b|kristalsuiker|basterdsuiker|poedersuiker|vanillesuiker|\bbelbake|\ble patissier|\bstol\b|kerststol|paasstol|\bschnecke|\bkrentenbol|\bappelflap|\bsaucijzen|\bworstenbrood|\bbagel|\bbrioche|\bstokbrood|\bbrownie|\bbrookie|\bcroissants/,
  ]],
  ['Snoep & chocolade', [
    /uitdeelzak/,
    /\bkinder\b|smint|maltesers|reese|ritter sport|chupa chups|smarties|schogetten|mini choco/,
    /snoep|\bdrop\b|dropjes|droppers|droppastille|winegum|\blolly|chocola|bonbon|praline|haribo|\bkatja|\bvenco|\bgummi|toffee|zuurtjes|pepermunt|\bmentos|marshmallow|spekjes|kauwgom|\bfin carre|\bmister choc|\bj d gross|\bjd gross|\bkitkat|\bm ms\b|\bsnickers|\btwix|\bmars\b|\bbounty|\bmilka|\bmerci\b|\bfondant|\bnougat|\bpaaseitjes|\bkerstkransjes|\bchocoladeletter|\bamanie|\bsweet corner|\bjetgum|\bsportlife/,
  ]],
  ['Snacks, koeken & noten', [
    /repen\b|reep\b|vingers\b|sticks\b|croky|\bbifi\b|sultana|scrocchi|\bpicos\b/,
    /cheetos|nibb it|onion rings|pom bar|huismix|pepitamix|partysticks|dippers|digestives|cookies|nutbar|grissini|torinesi|stengels|belvita|verkade|banket|spekknabbels|\bdortios|saladepitten|noten\b/,
    /chips|\bbugles|doritos|pringles|\blays\b|\bhamkas|popcorn|pretzel|\bzoutjes|rijstzoutjes|borrel|nootjes|\bnoten|notenmix|pinda|cashew|amandelen|walnoten|pistache|macadamia|pecannoten|hazelnoten|studentenhaver|\brozijnen|gedroogde(?! (kruiden|tomaten))|\bsnack day|\balesto\b|\bsnaqs/,
    /koek|koekjes|biscuit|speculaas|stroopwafel|wafels|eierkoek|bastogne|rijstwafel|maiswafel|\bmaiswaf|\bkrakeling|\bmacarons?|amaretti|cantuccini|\bspritsen|\bletterkoek|\bbanketstaaf|\bsondey|\btastino|\bmueslirepen|\bproteinereep|\benergiereep|\breep\b|\brepen\b|\btuc\b|\blu\b|\blotus/,
  ]],
  ['Verse maaltijden & pizza', [
    /flammkuchen|calzone|schotel\b|eenpansgerecht|fitmeals|stoofpot|wereldgerechten|\bbapao/,
    /pizza|maaltijd|kant en klaar|kant klaar|saladeschotel|\bsalade\b|lunchsalade|hummus|tzatziki|guacamole|\btapas|antipasti|\bsushi|\bquiche|\bwrap maaltijd|ovenschotel|stamppot|\blasagne(?!bladen)|\bmacaroni schotel|\bchef select|\bverspakket|\bheat eat|\bpasta salade|\bpokebowl|\bbowl\b|\bspread\b|\bdip\b|\bdips\b/,
  ]],
  ['Conserven & soepen', [
    /cornichons|spliterwten|kapucijners/,
    /conserv|in blik|\bblik\b|tomatenblok|tomatenpuree|passata|gepelde tomat|gezeefde tomat|kikkererwt|kidney|bruine bonen|witte bonen|\bbonen\b|linzen|kappertjes|olijven|\bsoep\b|soep\b|\bcup a soup|augurk|zilveruitjes|zuurkool|compote|appelmoes|op siroop|champignonschijfjes|doperwten en wortel|\bfreshona|\bkania|\bbaresa/,
  ]],
  ['Vers vlees, vis & vega', [
    /\bplantaardige|spek\b/,
    /worst\b|worsten\b|burger|angus|kluifjes|vleugels|kippenborst|lappen\b|lapjes\b|steak|mergpijp|casseler|spiesjes|shashlick|gehakt|dorade|mosselen|kreeft|carpaccio|soepballetjes|\bkip/,
    /\bkip\b|kip\b|\bkip |kipfilet|kipdij|kippendij|drumstick|kippenpoot|kippenbout|kipburger|kipschnitzel|kipnugget|nuggets|\bgehakt|gehaktbal|half om half|tartaar|biefstuk|entrecote|rosbief|rib eye|ribeye|bavette|\bsteak|steaks\b|ossenhaas|runder|varkens|schnitzel|karbonade|speklap|spekreepjes|\bspek\b|\bworst\b|worstjes|braadworst|rookworst|\bbacon\b|\blam\b|lamsvlees|lamsrack|\bshoarma|\bgyros|\bkebab|spareribs|sparerib|pulled pork|\bhamburger|slavink|\bcordon bleu|\bstoofvlees|sucadelapjes|poulet|\bkalkoen|\beend\b|\bvlees\b|\bvleesbal|\bsate\b|\bsaucijs|\bculinea|\bzwagerman/,
    /zalm|tonijn|kabeljauw|pangasius|garnalen|garnaal|haring|makreel|\bforel|tilapia|\bvis\b|visfilet|\bmosselen|\bkibbeling|lekkerbek|\bscampi|\bsurimi|\bkrab|\binktvis|\bcalamares|\bpaling|\bschol\b|\bkoolvis|\bheek\b|\bsardines?\b|\bansjovis|\bnixe\b|\bocean\b|\bjohn west/,
    /\bvega\b|\bvegan|vegetarisch|vegaburger|\bplantaardige burger|\bvemondo|\bfalafel|\bseitan|\bvegetarische/,
  ]],
  ['Pasta, rijst & wereldkeuken', [
    /vermicelli|\bwakame/,
    /pasta|spaghetti|penne|fusilli|macaroni|tagliatelle|farfalle|rigatoni|linguine|tortellini|tortelloni|ravioli|gnocchi|\bnoodles?|\bmie\b|mienestjes|\bbami|\bnasi|\bramen\b|rijst|basmati|jasmijn|risotto|couscous|bulgur|quinoa|\btaco|\bnacho|burrito|enchilada|woksaus|ketjap|sambal|sriracha|sojasaus|oestersaus|hoisin|\bcurry|tandoori|tikka|kroepoek|loempia|\bbizbiz|\bitaliamo|\bcombino|\bgolden sun|\bwok\b|\bboemboe|\bmiso\b|\bsate saus|\bkokosmelk/,
  ]],
  ['Sauzen, kruiden & olie', [
    /poeder\b|yogonaise|chilivlokken/,
    /\bjus|zout|molen\b|tomato frito/,
    /saus|sauzen|ketchup|mayonaise|\bmayo\b|mosterd|dressing|vinaigrette|pesto|kruiden|specerij|\bpeper\b|\bzout\b|zeezout|paprikapoeder|oregano|basilicum|\btijm\b|rozemarijn|kaneel|nootmuskaat|komijn|kurkuma|\bgember poeder|kerrie|bouillon|\bfond\b|\bjus\b|olijfolie|zonnebloemolie|\bolie\b|azijn|balsamico|tabasco|worcestershire|\bmarinade|\bprimadonna|\bvita d or|\bcalve|\bheinz/,
  ]],
  ['Groente & fruit', [
    /kriel|peen\b|sla\b|slamelange|witlof|tauge|sugar snaps|\bpeulen|haricots|kool\b|pompoen|shiitake|zwammen|jalapeno|habanero|snackboontjes|minneola|pomelo|appels\b/,
    /paprika|tomaat|tomaten|komkommer|\bsla\b|ijsbergsla|rucola|veldsla|\bspinazie|andijvie|\bui\b|\buien|sjalot|aardappel|krieler|wortel|\bpeen|winterpeen|broccoli|bloemkool|courgette|aubergine|champignon|paddenstoel|\bprei\b|selderij|venkel|radijs|\bbiet|bietjes|\bkool\b|spruit|boerenkool|sperziebonen|snijbonen|doperwt|\bmais\b|maiskolf|knoflook|\bgember\b|\bpompoen|asperge|\bpastinaak|\bpeterselie|\bbieslook|\bkoriander|\bmunt\b|\bkruidenpot|\broerbak|\bwokgroente|soepgroente|\bgroente|\bsalademix|\bslamix|\bsnoeptomaat|\bavocado|\bedamame|\bpaksoi/,
    /\bappel|\bappels\b|\bpeer\b|peren\b|banaan|bananen|sinaasappel|mandarijn|clementine|citroen|limoen|druif|druiven|aardbei|framboos|frambozen|bosbes|blauwe bes|braam|bramen|\bkersen|perzik|nectarine|pruim|mango|ananas|meloen|watermeloen|\bkiwi|granaatappel|\bvijg|\bdadel|\bpassievrucht|\bgrapefruit|\blychee|\bpapaya|\bfruit|fruitsalade|\bbessen/,
  ]],
];

// Merken die we herkennen als ze in de productnaam of slug staan, maar ook
// als categorie-tip wanneer de naam niets zegt.
const BRAND_CATEGORY = {
  'Bellarom': 'Koffie & thee',
  'Lord Nelson': 'Koffie & thee',
  'Solevita': 'Frisdrank, sap & water',
  'Freeway': 'Frisdrank, sap & water',
  'Saskia': 'Frisdrank, sap & water',
  'Kong Strong': 'Frisdrank, sap & water',
  'Milbona': 'Zuivel, plantaardig & eieren',
  'Cien': 'Verzorging',
  'G. Bellini': 'Verzorging',
  'Suddenly': 'Verzorging',
  'Dentalux': 'Verzorging',
  'W5': 'Huishouden & schoonmaak',
  'Formil': 'Huishouden & schoonmaak',
  'Floralys': 'Huishouden & schoonmaak',
  'Orlando': 'Huisdieren',
  'Coshida': 'Huisdieren',
  'Gelatelli': 'Diepvries',
  'BON Gelati': 'Diepvries',
  'Harvest Basket': 'Diepvries',
  'Snack Day': 'Snacks, koeken & noten',
  'Alesto': 'Snacks, koeken & noten',
  'Sondey': 'Snacks, koeken & noten',
  'Tastino': 'Snacks, koeken & noten',
  'Sweet Corner': 'Snoep & chocolade',
  'Mister Choc': 'Snoep & chocolade',
  'Fin Carré': 'Snoep & chocolade',
  'J.D. Gross': 'Snoep & chocolade',
  'Amanie': 'Snoep & chocolade',
  'Crownfield': 'Ontbijt & cereals',
  'Belbake': 'Brood & bakkerij',
  'Le Patissier': 'Brood & bakkerij',
  'Maribel': 'Vleeswaren & beleg',
  'Dulano': 'Vleeswaren & beleg',
  'Zwagerman': 'Vleeswaren & beleg',
  'Chef Select': 'Verse maaltijden & pizza',
  'Culinea': 'Vers vlees, vis & vega',
  'Nixe': 'Vers vlees, vis & vega',
  'Ocean Sea': 'Vers vlees, vis & vega',
  'Vemondo': 'Vers vlees, vis & vega',
  'Italiamo': 'Pasta, rijst & wereldkeuken',
  'Combino': 'Pasta, rijst & wereldkeuken',
  'Golden Sun': 'Pasta, rijst & wereldkeuken',
  'BizBiz': 'Pasta, rijst & wereldkeuken',
  'Primadonna': 'Sauzen, kruiden & olie',
  "Vita D'or": 'Sauzen, kruiden & olie',
  'Kania': 'Conserven & soepen',
  'Freshona': 'Conserven & soepen',
  'Baresa': 'Pasta, rijst & wereldkeuken',
  'Kordaat': 'Bier & wijn',
  'Perlenbacher': 'Bier & wijn',
  'Gerardus': 'Bier & wijn',
  'Cimarossa': 'Bier & wijn',
  'Chevalier': 'Bier & wijn',
  'Healthy Fit': 'Snacks, koeken & noten',
};

export function categorize(name, slug = '', brand = null) {
  const byName = matchRules(normalize(name));
  if (byName) return byName;
  if (brand && BRAND_CATEGORY[brand]) return BRAND_CATEGORY[brand];
  const bySlug = matchRules(normalize(slug.replace(/-/g, ' ')));
  if (bySlug) return bySlug;
  return 'Overig';
}

function matchRules(text) {
  for (const [category, patterns] of RULES) {
    if (patterns.some((re) => re.test(text))) return category;
  }
  return null;
}

// --- Merknamen ---

// Lidl-huismerken en andere merken die vaak voorkomen, met de juiste
// schrijfwijze. Varianten met een typefout worden hierop gecorrigeerd.
const KNOWN_BRANDS = [
  'Milbona', 'Vemondo', 'Sondey', 'Italiamo', 'Chef Select', 'Snack Day',
  'Bellarom', 'Cien', 'Belbake', 'Solevita', 'Sweet Corner', 'Maribel',
  'Freshona', 'Kania', 'Freeway', 'Alesto', "Vita D'or", 'Healthy Fit',
  'Orlando', 'Zwagerman', 'Le Patissier', 'BizBiz', 'Gerardus', 'Gelatelli',
  'Lord Nelson', 'Crownfield', 'Saskia', 'Coshida', 'W5', 'Tastino',
  'Kordaat', 'BON Gelati', 'G. Bellini', 'Suddenly', 'Mister Choc', 'Amanie',
  'Perlenbacher', 'Way To Go!', 'Primadonna', 'Harvest Basket', 'Golden Sun',
  'Fin Carré', 'Cimarossa', 'Baresa', 'Floralys', 'Fairglobe', 'Culinea',
  'Chogal', 'Nixe', 'Linessa', 'Dentalux', 'Formil', 'Combino', 'Dulano',
  'J.D. Gross', 'Chevalier', 'Kong Strong', 'Sportyfeel', 'Deluxe',
  'Ocean Sea', 'Chêne d’Argent', 'Giulio', 'Douwe Egberts', 'Senseo',
];

// Losse woorden die de oude scraper ten onrechte als merk zag.
const NOT_A_BRAND = new Set([
  'een', 'twee', 'drie', 'vier', 'vijf', 'zes', 'tien', 'fles', 'zak', 'zakje',
  'zakjes', 'verpakking', 'verpakkingen', 'verpakte', 'verpakt', 'verse', 'pot',
  'potje', 'doos', 'pak', 'pakjes', 'pakketten', 'rol', 'gesneden', 'heele',
  'hele', 'heel', 'heelde', 'heul', 'gemarineerde', 'gerookte', 'gemalen',
  'rund', 'scharrelkip', 'beter', 'snack', 'stapel', 'het', 'meerdere',
  'hollandse', 'rijpe', 'fries', 'duitse', 'spaanse', 'rode', 'gouden',
  'knoflook', 'knoflookbol', 'kaiserbroodjes', 'afbak', 'mehr', 'chocolade',
  'lidl', 'gebak', 'assortiment', 'diepvries', 'blik', 'select', 'asia', 'so',
  'betaal', 'trossen', 'confiserie', 'speel', 'air', 'sweet', 'bella', 'xxl',
  'rxt', 'asc', 'inproba', 'twinkels', 'avocados', 'broodje', 'varkensbraadworsten',
  'varkensschouderfiletsteaks', 'komijnkaasblokjes', 'wakamesalade',
  'paddenstoelenmix', 'klene', 'ulien', 'karig', 'lupilu', 'roze', 'bonot',
  'trattoria', 'siempre', 'aromata', 'hampstead', 'massari', 'mezquiriz',
  'borgovenisio', 'paolo', 'alfredo', 'zwanenberg',
]);

const BRAND_ALIASES = {
  'chef': 'Chef Select',
  'lord': 'Lord Nelson',
  'fin': 'Fin Carré',
  'mister': 'Mister Choc',
  'golden': 'Golden Sun',
  'harvest': 'Harvest Basket',
  'jd': 'J.D. Gross',
  'jdgross': 'J.D. Gross',
  'kanig': 'Kania',
  'kanja': 'Kania',
  'kanis': 'Kania',
  'ocean': 'Ocean Sea',
  'chene': 'Chêne d’Argent',
  'wc blok': null,
  'uhu5': null,
};

function brandKey(text) {
  return normalize(text).trim();
}

const KNOWN_BY_KEY = new Map(KNOWN_BRANDS.map((b) => [brandKey(b), b]));

function levenshtein(a, b) {
  const dp = Array.from({ length: a.length + 1 }, (_, i) => [i]);
  for (let j = 1; j <= b.length; j++) dp[0][j] = j;
  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      dp[i][j] = Math.min(
        dp[i - 1][j] + 1,
        dp[i][j - 1] + 1,
        dp[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1),
      );
    }
  }
  return dp[a.length][b.length];
}

function decodeEntities(text) {
  return text
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)))
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"');
}

// Geeft een opgeschoonde merknaam terug, of null als het geen echt merk is.
export function cleanBrand(rawBrand, slug = '') {
  if (!rawBrand) return null;
  const brand = decodeEntities(String(rawBrand)).replace(/[:\-\s]+$/, '').trim();
  const key = brandKey(brand);
  if (!key || /^\d/.test(key) || NOT_A_BRAND.has(key)) return null;
  if (key in BRAND_ALIASES) return BRAND_ALIASES[key];
  if (KNOWN_BY_KEY.has(key)) return KNOWN_BY_KEY.get(key);

  // Typefouten zoals "Freshohna" of "Zwaggerman" rechtzetten.
  if (key.length >= 5) {
    for (const [knownKey, known] of KNOWN_BY_KEY) {
      if (knownKey[0] !== key[0] || Math.abs(knownKey.length - key.length) > 2) continue;
      if (levenshtein(knownKey, key) <= 2) return known;
    }
  }

  // Onbekend merk: alleen houden als het ook in de productlink staat.
  const slugText = normalize(slug.replace(/-/g, ' '));
  if (slugText.includes(` ${key} `)) return brand;
  return null;
}

// Productnaam netjes maken: HTML-entiteiten weg, eerste letter hoofdletter,
// en schreeuwende HOOFDLETTERNAMEN omzetten.
export function cleanName(rawName) {
  let name = decodeEntities(String(rawName || '')).replace(/\s+/g, ' ').trim();
  const letters = name.replace(/[^A-Za-z]/g, '');
  if (letters.length > 6 && letters === letters.toUpperCase()) {
    name = name.toLowerCase();
  }
  return name.charAt(0).toUpperCase() + name.slice(1);
}
