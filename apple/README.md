# Boodschappen voor iPhone, iPad en Mac

Een echte app (SwiftUI) met dezelfde functies als de web-app, maar dan:

- **iCloud-synchronisatie binnen een paar seconden**: je lijst, favorieten en varianten zijn hetzelfde op je iPhone, iPad en Mac. Zolang de app open is, staat een wijziging binnen enkele seconden op je andere apparaten; trek de lijst omlaag om meteen te synchroniseren.
- **Winkelvolgorde**: de lijst is gegroepeerd per afdeling (groente, brood, vlees, …), in de volgorde waarin je door de Lidl loopt.
- **Afvinken** met het rondje of een veeg naar rechts; afgevinkte producten schuiven naar “In je mandje”.
- **Meer informatie**: tik op een product voor een grote foto, het aantal, en prijs, beschrijving en EAN-code van de productpagina op lidl.nl, plus een knop naar de volledige pagina.
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

### Synchroniseert het niet?

Open in de app **Instellingen → iCloud** (op de Mac: *Boodschappen → Instellingen…*). Daar staat of iCloud werkt en zo niet, waarom. Onder **Technische details** zie je de laatste synchronisatiestappen en kun je met **Deel diagnose** een verslag versturen. Loop daarnaast deze punten na:

1. **“iCloud staat niet aan in deze versie van de app”**: de app is gebouwd zonder iCloud-rechten. Dat gebeurt met een gratis Apple ID, of als *Code Signing Entitlements* leeg is gemaakt. Je hebt een betaald ontwikkelaarsaccount nodig.
2. **De container moet bij je account horen.** Kijk in Xcode bij *Signing & Capabilities* of er geen rode foutmelding staat, zowel met je iPhone als met **My Mac** als bestemming (de Mac gebruikt een eigen entitlements-bestand). Staat de container er niet goed bij, maak hem dan zelf aan op [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list/cloudContainer):
   - *Identifiers → iCloud Containers → +* → `iCloud.nl.joelvalentijn.Boodschappen`
   - *Identifiers → App IDs → nl.joelvalentijn.Boodschappen → iCloud → Configure* → vink de container aan
   - Bouw de app daarna opnieuw op beide apparaten.
3. **Zelfde Apple-account, iCloud aan voor de app.** Op de iPhone: *Instellingen → [je naam] → iCloud → Apps die iCloud gebruiken → Boodschappen* aan. Op de Mac: *Systeeminstellingen → [je naam] → iCloud*.
4. **Allebei vanuit Xcode geïnstalleerd.** Een versie uit Xcode praat met de *ontwikkel*-database van iCloud, een TestFlight- of App Store-versie met de *productie*-database. Die zien elkaars gegevens niet.
5. **De app moet open zijn.** Zolang de app open is (op de Mac mag het venster achter andere vensters staan), kijkt hij elke 3 seconden of er iets veranderd is. Is de app dicht, dan komen de wijzigingen binnen zodra je hem opent. Trek de lijst omlaag of tik in Instellingen op *Nu synchroniseren* om direct te synchroniseren.
6. **Niet in de simulator.** iCloud werkt alleen in een installatie op een echt apparaat die met je ontwikkelaarsaccount is ondertekend.
7. **Controleren in het CloudKit-dashboard.** Op [icloud.developer.apple.com](https://icloud.developer.apple.com) → je container → *Development* → *Records* (zone `Boodschappen`, typen `Item`, `Favorite` en `Variant`) zie je of er gegevens aankomen.

## Je lijst overzetten vanuit de web-app

1. Open de web-app in Safari en tik onderaan op **Overzetten naar iPhone/Mac-app**.
2. Open de app, ga naar **Instellingen** (⋯-menu rechtsboven) en tik op **Plak** bij *Overzetten vanuit de web-app*.

## Hoe het werkt

| Onderdeel | Waar |
| --- | --- |
| Lijst, favorieten, varianten | Lokaal in SwiftData (`Model/Models.swift`), gesynchroniseerd met `CKSyncEngine` (`Model/CloudSync.swift`) |
| Productcatalogus | `products.json` zit in de app; `Model/CatalogStore.swift` haalt elke 6 uur de nieuwste versie van GitHub |
| Nieuwe producten | De GitHub Action *Nieuwe Lidl-producten ophalen* draait elke maandag `scraper.mjs` |
| Schermen | `Views/` — iPhone gebruikt `PhoneRootView`, iPad en Mac `SplitRootView` |

Minimaal iOS 17 en macOS 14 (Sonoma).

Bij elke wijziging in `apple/` bouwt GitHub de app voor iPhone en Mac (*iPhone- en Mac-app bouwen*). Screenshots nodig? Start *Actions → Screenshots van de app → Run workflow*; de afbeeldingen staan daarna als download onder de run. Debug-builds kun je met voorbeeldgegevens starten via het launch-argument `-demo YES` (zie `Model/DemoMode.swift`).
