# Boodschappen voor iPhone, iPad en Mac

Een echte app (SwiftUI) met dezelfde functies als de web-app, maar dan:

- **iCloud-synchronisatie**: je lijst, favorieten en varianten zijn hetzelfde op je iPhone, iPad en Mac.
- **Winkelvolgorde**: de lijst is gegroepeerd per afdeling (groente, brood, vlees, …), in de volgorde waarin je door de Lidl loopt.
- **Afvinken met een veeg** (of een tik), afgevinkte producten schuiven naar “In je mandje”.
- **Snel toevoegen**: de productkiezer blijft open, zodat je meerdere producten achter elkaar kunt toevoegen. Staat iets niet in de catalogus, dan voeg je het toe als eigen product.
- **Nieuw bij Lidl**: producten die de afgelopen drie weken nieuw in het assortiment zijn.
- **Automatisch nieuwe producten**: de app haalt de nieuwste productlijst van GitHub, je hoeft de app daarvoor niet opnieuw te installeren.
- **Mac en iPad**: categorieën, producten en je lijst naast elkaar.
- Zegeltjes-scherm met voorleesknop, lijst delen via Berichten/WhatsApp, donkere modus.

## Installeren

Je hebt een Mac met **Xcode 16 of nieuwer** nodig (gratis in de App Store).

1. Open `apple/Boodschappen.xcodeproj` in Xcode.
2. Klik links op het blauwe projecticoon **Boodschappen**, kies het target **Boodschappen** en open het tabblad **Signing & Capabilities**.
3. Kies bij **Team** je Apple-account (voeg het zo nodig toe via *Xcode → Settings → Accounts*).
4. Is de *Bundle Identifier* `nl.joelvalentijn.Boodschappen` al bezet? Verander hem dan in iets unieks, en verander de iCloud-container mee (zie hieronder).
5. **iPhone**: sluit je iPhone aan, kies hem bovenin als bestemming en druk op ▶︎ (⌘R).
   De eerste keer moet je op de iPhone *Ontwikkelaarsmodus* aanzetten (Instellingen → Privacy en beveiliging) en de ontwikkelaar vertrouwen (Instellingen → Algemeen → VPN en apparaatbeheer).
6. **Mac**: kies **My Mac** als bestemming en druk op ▶︎. Wil je de app in je map Programma's? Kies *Product → Archive → Distribute App → Custom → Copy App*.

## iCloud-synchronisatie

iCloud (CloudKit) werkt alleen met een **betaald Apple Developer-account** (€ 99 per jaar).

- **Met een betaald account**: bij *Signing & Capabilities → iCloud* staat de container `iCloud.nl.joelvalentijn.Boodschappen`. Vink hem aan (of klik op **+** om hem aan te maken; gebruik dezelfde naam als in `Config/Boodschappen-iOS.entitlements` en `Config/Boodschappen-macOS.entitlements`). Installeer de app op iPhone en Mac met hetzelfde Apple-account en je lijst synchroniseert vanzelf.
- **Met een gratis Apple ID**: iCloud is dan niet beschikbaar. Ga naar *Build Settings*, zoek **Code Signing Entitlements** en maak de waarden leeg. De app werkt dan gewoon, alleen bewaart elk apparaat zijn eigen lijst. Let op: met een gratis account verloopt de app op je iPhone na 7 dagen; installeer hem dan opnieuw vanuit Xcode.

Ga je de app via TestFlight of de App Store verspreiden, zet dan in het [CloudKit-dashboard](https://icloud.developer.apple.com) het schema over naar *Production*.

## Je lijst overzetten vanuit de web-app

1. Open de web-app in Safari en tik onderaan op **Overzetten naar iPhone/Mac-app**.
2. Open de app, ga naar **Instellingen** (⋯-menu rechtsboven) en tik op **Plak** bij *Overzetten vanuit de web-app*.

## Hoe het werkt

| Onderdeel | Waar |
| --- | --- |
| Lijst, favorieten, varianten | SwiftData met CloudKit (`Model/Models.swift`) |
| Productcatalogus | `products.json` zit in de app; `Model/CatalogStore.swift` haalt elke 6 uur de nieuwste versie van GitHub |
| Nieuwe producten | De GitHub Action *Nieuwe Lidl-producten ophalen* draait elke maandag `scraper.mjs` |
| Schermen | `Views/` — iPhone gebruikt `PhoneRootView`, iPad en Mac `SplitRootView` |

Minimaal iOS 17 en macOS 14 (Sonoma).

Bij elke wijziging in `apple/` bouwt GitHub de app voor iPhone en Mac (*iPhone- en Mac-app bouwen*). Screenshots nodig? Start *Actions → Screenshots van de app → Run workflow*; de afbeeldingen staan daarna als download onder de run. Debug-builds kun je met voorbeeldgegevens starten via het launch-argument `-demo YES` (zie `Model/DemoMode.swift`).
