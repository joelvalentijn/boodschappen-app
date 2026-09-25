# Boodschappenlijst voor de Lidl

Een boodschappenlijst met het hele Lidl-assortiment: kies producten per afdeling, maak favorieten en eigen varianten (zoals “Halfvol” of “Aardbei”), en vink af in de winkel.

## Onderdelen

- **Web-app** — `index.html`. Werkt in elke browser; op de iPhone kun je hem via *Deel → Zet op beginscherm* als app gebruiken.
- **iPhone-, iPad- en Mac-app** — map [`apple/`](apple/README.md). Native SwiftUI-app met iCloud-synchronisatie, winkelvolgorde en een “Nieuw bij Lidl”-overzicht. Zie [apple/README.md](apple/README.md) voor installatie.
- **Productcatalogus** — `products.json`, gemaakt door `scraper.mjs` met de regels uit `catalog-rules.mjs`.

## Productcatalogus bijwerken

De GitHub Action **Nieuwe Lidl-producten ophalen** draait elke maandag en zet nieuwe producten automatisch in `products.json`. De app en de web-app laten ze drie weken zien onder “Nieuw bij Lidl”. Je kunt hem ook met de hand starten via *Actions → Nieuwe Lidl-producten ophalen → Run workflow*.

Zelf draaien (Node.js 22):

```sh
node scraper.mjs            # nieuwe producten ophalen
node scraper.mjs --full     # alle productpagina's opnieuw ophalen
node scraper.mjs --offline  # alleen opnieuw indelen, zonder internet
```

De scraper slaat webshop-artikelen (fietsen, lampen, gereedschap) over, corrigeert merknamen en verdeelt producten over 22 afdelingen in winkelvolgorde. Staat een product in de verkeerde categorie, pas dan de regels in `catalog-rules.mjs` aan en draai `node scraper.mjs --offline`.
