# Személyi edző modul — tervdokumentáció

Cél: a Lifey-be bekerül egy **személyi edző (trainer)** szerepkör. A kliens (sima user) **továbbra is a mobil appot használja, változatlanul** — az edző pedig egy **webes admin felületet** kap (`/admin` útvonal a meglévő Next.js web appban), ahol klienseket hív meg, saját tartalmat (edzéssablon, recept) rendel hozzájuk, és követi a fejlődésüket.

## Fájlok

| Fájl | Tartalom |
|---|---|
| [`01-koncepcio-es-folyamatok.md`](01-koncepcio-es-folyamatok.md) | Szerepkörök, fő felhasználói folyamatok (meghívás, elfogadás, hozzárendelés, admin-váltás), üzleti szabályok (24 órás meghívó-szabály) |
| [`02-domain-es-migraciok.md`](02-domain-es-migraciok.md) | Domain-modell változások, **foods/exercises user-ownership migráció**, új táblák, Flyway migrációk, delta sync hatások |
| [`03-backend-terv.md`](03-backend-terv.md) | Backend csomagok, végpontok, jogosultsági réteg, meghívó rate-limit, deep-copy hozzárendelő szolgáltatás |
| [`04-web-admin-terv.md`](04-web-admin-terv.md) | A webes admin felület terve: útvonalak, RBAC, képernyők, feature-mappák |
| [`05-mobil-terv.md`](05-mobil-terv.md) | Mobil app változások: lebegő meghívó-kártya, polling, edzőtől kapott tartalom jelölése |
| [`06-design.md`](06-design.md) | **Design terv**: admin felület layoutja és képernyői, kliens-választó modal, mobil meghívó-kártya — a meglévő brown-green design tokenekre építve |
| [`07-utemterv-es-kockazatok.md`](07-utemterv-es-kockazatok.md) | Fázisokra bontott ütemterv, mérföldkövek, kockázatok, nyitott kérdések |
| [`08-utemezett-edzesek-koncepcio.md`](08-utemezett-edzesek-koncepcio.md) | **Ütemezett edzések** (PT5): koncepció, folyamatok, üzleti szabályok (3 hónapos horizont, 7 napos kliens-láthatóság, ismétlődés) |
| [`09-utemezett-edzesek-domain-backend.md`](09-utemezett-edzesek-domain-backend.md) | Ütemezett edzések: V45 migráció, session-bővítés (`scheduled_for`), `WorkoutScheduleService`, végpontok, sync-hatás, tesztek |
| [`10-utemezett-edzesek-web-mobil.md`](10-utemezett-edzesek-web-mobil.md) | Ütemezett edzések: admin Ütemterv tab + ütemező drawer, mobil "Közelgő" szekció + felugró kártya, PT5 fázis — **frame-térkép az elkészült designhoz** |
| [`11-utemezett-edzesek-design-prompt.md`](11-utemezett-edzesek-design-prompt.md) | Ütemezett edzések: design prompt (archív) + a funkció **döntés-naplója** |
| [`design/Lifey Schedule.dc.html`](design/Lifey%20Schedule.dc.html) | **Ütemezett edzések — elkészült design** (5 frame: ütemterv tab, drawer, mobil közelgő, felugró kártya, állapotok) — a megvalósítás ebből dolgozik |

## A legfontosabb döntések (összefoglaló)

1. **Admin az URL-ben, nem state-ben:** az edző felület a web app `/admin/...` útvonalcsoportja. Linkelhető, a middleware szerepkör alapján védi, a "melyik nézetben vagyok" kérdés a route-ból egyértelmű.
2. **`ROLE_TRAINER` szerepkör, kézi kiosztással:** a meglévő szerepkör-modell (JWT `roles` claim) bővítése. Nincs önkiszolgáló "edzővé válok" flow — a kiosztást az új **`ROLE_SUPER_ADMIN`** végzi a saját webes felületén (`/superadmin/users`: user-lista, Edzővé tétel/visszavonás, audit-napló). A super admin szerepkör maga egyszeri kézi SQL bootstrap, API-ból nem osztható; API-ból kizárólag a `ROLE_TRAINER` kezelhető.
3. **Meghívó = e-mail alapú, 24 órás életciklussal:** egy edző egy adott e-mail címet **24 óránként legfeljebb egyszer** hívhat meg. A függő meghívó 24 óra után lejár, és **eltűnik mind az edző listájából, mind a mobil appból** — utána újra meghívható.
4. **Mobil értesítés = polling, nem push:** nincs push infrastruktúra; az app indításkor/előtérbe kerüléskor lekéri a függő meghívókat, és **lebegő kártyán** mutatja (elfogad / elutasít).
5. **`foods` és `exercises` user-tulajdonúvá válik:** a ma globális katalógusok minden meglévő user számára lemásolódnak, a hivatkozások átíródnak (Flyway migráció). Ez a modul **előfeltétele** és egyben a legnagyobb kockázatú lépése (delta sync!).
6. **Hozzárendelés = deep copy provenance-szel:** amikor az edző sablont/receptet rendel a klienshez, a rendszer **átmásolja** a kliens fiókjába a sablont/receptet **és a hivatkozott gyakorlatokat/ételeket is**. A másolat őrzi a származást (`origin_source_id`, `origin_trainer_id`), így a mobil jelezheti, hogy "edzőtől kapott", és az újra-hozzárendelés nem duplikál.
7. **Edző olvasási jog = kapcsolat-alapú:** az edző kizárólag az **aktív** kliensei adatait éri el, **csak olvasásra**: statisztika, lépések, testsúly, edzés-előzmények. **Víz nem** (a felhasználói döntés szerint kimarad az adminból).

## Kapcsolódó meglévő dokumentumok

- `docs/web/01-feature-inventory.md` §"Jövőbeli rész — Személyi edző" — az itteni terv ezt bontja ki
- `docs/web/02-development-plan.md` F10 — ezt a fázist részletezi ez a mappa
- `docs/16-delta-sync-rollout.md` — a foods/exercises ownership migrációt ehhez kell igazítani
- `docs/design/18-design-system-prompt.md` — design tokenek forrása a `06-design.md`-hez
