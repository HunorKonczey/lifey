# 05 — Mobil app terv (Flutter)

Alapelv: a kliens élménye **minimálisan változik**. A mobil appba három dolog kerül: a meghívó-kártya, az "edzőtől kapott" jelölés, és a Settings-be az "Edzőim" szekció.

## 1. Meghívó-értesítés (lebegő kártya)

Nincs push-infrastruktúra, ezért **polling**:

- Az app **indításkor és előtérbe kerüléskor** (`AppLifecycleState.resumed`) lekéri: `GET /api/v1/trainer-invites/pending`.
- Riverpod provider (`pendingInvitesProvider`), a meglévő session-refresh minták szerint; offline állapotban csendben kimarad (a meghívó úgyis 24 órás — a következő online indulásnál megjön).
- Ha van függő meghívó → a fő shell felett **lebegő, elutasítható kártya** jelenik meg (design: `06-design.md` §4):
  - szöveg: "**{Edző neve}** meghívott, hogy legyen a személyi edződ" + mennyi idő múlva jár le;
  - két gomb: **Elfogadom** / **Elutasítom** → `POST /trainer-invites/{id}/respond`;
  - a kártya "később" gombbal/elhúzással eltüntethető → a következő app-indulásnál újra megjelenik, amíg le nem jár vagy nem válaszol.
- Több függő meghívó esetén egymás után (stack), de ez ritka eset — MVP-ben elég az első + "még N meghívó" jelzés.
- Elfogadás után rövid megerősítés (snackbar): "Mostantól {név} a személyi edződ. A Beállításokban bármikor kiléphetsz."

## 2. Edzőtől kapott tartalom

A hozzárendelt sablon/recept **deep copy-ként, a normál delta sync-en keresztül** érkezik meg (lásd `03-backend-terv.md`) — a mobilnak **nem kell új sync-táblát** bevezetnie. Amit fel kell tenni:

- A `workout_templates`, `recipes`, `exercises`, `foods` sync DTO-k + drift táblák bővülnek az `origin_trainer_id` (+ opcionálisan `origin_source_id`) mezővel.
- UI: ha `origin_trainer_id != null` → kis **"Edzőtől" badge** a sablon-/recept-kártyán (ikon + tooltip/subtitle az edző nevével — az edző neve a `GET /my-trainers` válaszból cache-elhető).
- A kliens a másolatot **szabadon szerkesztheti/törölheti** — az az övé. (A badge szerkesztés után is marad; ez szándékos: a származást jelzi, nem a változatlanságot.)

## 3. Settings — "Edzőim" szekció

- `GET /api/v1/my-trainers` → lista: edző neve, avatar, kapcsolat kezdete.
- Soronként "Kilépés" akció (confirm dialog: "Az edződ többé nem látja az adataidat.") → `DELETE /my-trainers/{trainerId}`.
- Üres állapot: a szekció el is rejthető, ha nincs edző (kevesebb zaj).
- Ide kerül egy rövid adatmegosztási magyarázat is: "Az edződ látja: statisztikáid, lépéseid, testsúlyod, edzéseid. Nem látja: étkezési naplód, vízbeviteled."

## 4. Foods/exercises ownership átállás (⚠ kötelező app-frissítés)

A `V40` migráció (lásd `02-domain-es-migraciok.md`) miatt a foods/exercises **user-szűrt** lesz, és egyes id-k átíródnak:

- Az átállással egyidőben kiadott app-verzió **egyszeri kényszerített teljes újraszinkront** futtat a `foods` és `exercises` táblákra (sync cursor reset + lokális tábla-újratöltés), a `docs/16-delta-sync-rollout.md` mechanizmusaira építve.
- A backend és a mobil release **összehangolt** (előbb backend + migráció, utána azonnal app-frissítés; a régi app a régi cache-sel átmenetileg árva sorokat mutathat — elfogadott, rövid ablak).

## 5. Nem változik

- Navigáció, tabok, offline-first működés, meglévő képernyők.
- A kliens appban **nincs** edző-funkció (az edző a webet használja; a mobil app edző-nézete nem cél, még ha az edzőnek van is ROLE_TRAINER-e).

## Lokalizáció

Minden új szöveg ARB kulcs (EN + HU), a meglévő `flutter_intl` folyamat szerint — hardcode-olt string tilos.
