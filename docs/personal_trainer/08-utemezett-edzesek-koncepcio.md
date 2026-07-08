# 08 — Ütemezett edzések: koncepció és folyamatok

Új funkció a személyi edző modulra építve: az edző **jövőbeli edzéseket ütemez** a kliensének — egyszerit vagy ismétlődőt (naponta / kiválasztott hétköznapokon), legfeljebb **3 hónapra** előre. A kliens mobiljában az edzés **felugró kártyán** jelenik meg, és az edzései közt egy új **"Közelgő" kategóriában** látszik — de csak **egy hétre előre**, akárhány hónapra ütemezett is az edző.

Előfeltétel: a személyi edző modul PT1–PT3 fázisai (kapcsolat, hozzárendelés/deep copy) — ez a funkció a **PT5** fázis.

## A központi döntés: az ütemezett edzés = előre létrehozott session

A felhasználói irány szerint az ütemezett edzések **`workout_sessions` sorok**, amelyek az edző sablonjából származnak és "közelgő" (upcoming) állapotúak:

- A `workout_sessions` tábla két új oszlopot kap: **`scheduled_for` (date)** és **`schedule_id`**; a `started_at` **nullázhatóvá** válik.
- Egy session állapota **származtatott**, nincs külön státusz-oszlop:

| Állapot | Feltétel |
|---|---|
| **KÖZELGŐ** (upcoming) | `scheduled_for` kitöltve, `started_at` üres, `scheduled_for >= ma`, nem törölt |
| **KIHAGYOTT** (missed) | `scheduled_for` kitöltve, `started_at` üres, `scheduled_for < ma`, nem törölt |
| **ELVÉGZETT / FOLYAMATBAN** | `started_at` kitöltve (a mai, normál session-viselkedés) |
| **LEMONDOTT** | soft delete (`deleted_at`) — edző vagy kliens törölte |

Miért ez, és nem külön "scheduled_workouts" nézet-tábla?

1. **A delta sync ingyen van.** A session `SyncableEntity` — a materializált közelgő sessionök a meglévő sync-csatornán mennek le a mobilra, offline is ott vannak, tombstone-nal törlődnek. Nem kell új sync-tábla, se polling végpont.
2. **A "Kezdés" flow természetes.** A kliens a közelgő sessiont indítja el: a meglévő "sablonból indítás" logika kitölti a `started_at`-ot és a tervezett gyakorlatokat — a sor **ugyanaz marad**, csak állapotot vált. Nincs "lebegő terv → session" konverziós lépés.
3. **Az edzőnek a compliance látszik.** A kihagyott edzés (múltbeli, el nem indított sor) az edző naptárában erős jelzés — pont ez a funkció edzői értéke.

Ára: a rendszer minden meglévő pontján, ahol "edzés" = "megtörtént edzés" (statisztika, előzmény-listák, dashboard), a lekérdezéseknek **ki kell zárniuk** a `started_at is null` sorokat. Ez auditált, tesztelt lépés — lásd `09-utemezett-edzesek-domain-backend.md` §"Elvégzett = started_at not null".

A közelgő session **könnyű**: csak fejléc-adat (kliens, dátum, sablon-hivatkozás + névsnapshot). A tervezett gyakorlatok **induláskor** töltődnek be a sablon-másolatból — így egy 3 hónapos napi sorozat sem hoz létre több ezer gyermek-sort, és a kliens mindig a sablon-másolat *aktuális* állapotával indít.

## Az ismétlődés modellje

Az ütemezés-definíció külön szülő-táblában él (`workout_schedules`), az előfordulások **létrehozáskor materializálódnak** session-sorokká:

| Típus | Jelentés | Példa |
|---|---|---|
| `ONCE` | egyetlen nap | 2026-07-10 |
| `DAILY` | minden nap a kezdő- és zárónap közt | 07-07 → 08-07, minden nap |
| `WEEKLY` | a kiválasztott hétköznapokon | minden hétfőn és csütörtökön, 3 hónapig |

Szabályok:

1. **Horizont:** `end_date <= start_date + 3 hónap`. `ONCE`-nál nincs zárónap (= kezdőnap). A kezdőnap nem lehet múltbeli.
2. **Felső korlát:** egy sorozat legfeljebb ~92 előfordulás (napi × 3 hónap) — a service 100-as sanity-cap-pel véd.
3. **Materializálás előre, egyben:** nincs görgetőablakos napi job — a létrehozás egyetlen tranzakcióban legenerálja az összes session-sort. A lemondás így szimmetrikus: a jövőbeli, el nem kezdett sorok soft delete-je. (A görgetőablak kevesebb sort szinkronizálna, de napi jobot és bonyolultabb lemondást hozna — nem éri meg.)
4. **Nap + opcionális időpont:** az ütemezés naptári napra szól (`date`), és a sorozat kaphat egy **opcionális napon belüli időpontot** (pl. 18:00), amely minden előfordulására öröklődik. Az időpont **fali óra szerinti** (wall-clock) idő, időzóna nélkül tárolva — jelentése: "a kliens órája szerint 18:00", bárhol is van; így nincs időzóna-konverzió sehol. Az időpont megjelenítést és sorrendet ad (a kliens látja, mikorra tervezte az edző) — a **kihagyottá válást továbbra is a nap eltelte dönti el**, nem az óra: a 18:00-s edzés 19:00-kor még aznapi közelgő, csak másnap válik kihagyottá.
5. **Egy napon több edzés is lehet** (két sorozat átfedhet) — nincs ütközés-tiltás, a web UI legfeljebb jelzi.

## Az egyhetes láthatóság

A kliens **csak a következő 7 napot** látja (ma + 6 nap), hiába van 3 hónapra ütemezve:

- Ez **megjelenítési szabály, nem sync-szűrés**: a delta sync az összes materializált sessiont leviszi (a sync-szemantika — updated_at kurzor — nem tűrné, hogy sorok "később jelenjenek meg" változás nélkül), a mobil UI szűr a 7 napos ablakra.
- Előny: offline is pontos a heti nézet, és az edzői lemondás tombstone-ja azonnal érvényesül.
- Az edző a webes felületen természetesen a **teljes** ütemtervet látja.

## Folyamat — ütemezés (edző → kliens)

```
Edző (web /admin)                      Backend                              Kliens (mobil)
     │                                    │                                      │
     │ 1. kliens + sablon + ismétlődés    │                                      │
     │    (+ opcionális időpont)          │                                      │
     ├───────────────────────────────────►│                                      │
     │  POST /trainer/schedules           │ 2. kapcsolat-guard, validálás        │
     │                                    │ 3. sablon-másolat a kliensnél        │
     │                                    │    (meglévő élő másolat újrahasznált,│
     │                                    │     különben deep copy + assignment) │
     │                                    │ 4. előfordulások → workout_sessions  │
     │ 5. "N edzés ütemezve" + ütemterv   │    (scheduled_for, started_at=null)  │
     │◄───────────────────────────────────┤                                      │
     │                                    │        6. delta sync (app indul)     │
     │                                    │◄─────────────────────────────────────┤
     │                                    ├─────────────────────────────────────►│
     │                                    │ 7. felugró kártya ("Ma 18:00: Láb nap")│
     │                                    │      + "Közelgő" szekció (7 nap)     │
     │                                    │                                      │
     │                                    │   8. kliens elindítja → started_at   │
     │ 9. ütemtervben "elvégzett" ✓       │◄─────────────────────────────────────┤ (push sync)
     │◄───────────────────────────────────┤                                      │
```

A 3. lépés a meglévő hozzárendelés-modellre épül: ha a kliensnél már van **élő másolat** ebből a sablonból (`origin_trainer_id` + `origin_source_id` egyezik, nem törölt), azt használja; különben a `ContentAssignmentService` deep copy-ja fut le, `content_assignments` bejegyzéssel — az ütemezés tehát **implicit kiosztás is**.

## Folyamat — lemondás és bontás

1. **Edző lemond egy előfordulást:** az adott jövőbeli, el nem kezdett session soft delete → tombstone sync → eltűnik a kliens mobiljáról.
2. **Edző lemond egy teljes sorozatot:** a sorozat `cancelled_at`-ot kap, minden jövőbeli, el nem kezdett előfordulása soft delete. A múlt (elvégzett + kihagyott) **érintetlen** — az az előzmény.
3. **Kliens töröl egy közelgő edzést:** a session az övé — törölheti (a mobil meglévő session-törlés flow-ja). Az edző ütemtervében az előfordulás "kliens törölte" jelzést kap (soft delete + nincs started_at → származtatható).
4. **Kapcsolat bontása** (bármelyik oldalról, REVOKED): az edző–kliens pár **aktív sorozatai lemondódnak**, a jövőbeli el nem kezdett előfordulások törlődnek. A már elvégzett edzések és a sablon-másolat a kliensé marad (összhangban a modul elveivel). Ez a bontás-útvonal meglévő service-ébe kerül hook-ként.

## Kivétel az "edző soha nem ír" szabály alól

A modul eddigi elve: az edző a kliens adatát csak olvassa, a hozzárendelés is csak *másol*. Az ütemezés az **első eset, ahol az edző sorokat hoz létre a kliens fiókjában** (közelgő sessionök). A kivétel kontrollált:

- kizárólag **jövőbeli, üres** (el nem kezdett) sessionöket hozhat létre és törölhet;
- **soha nem módosít** meglévő kliens-adatot (elkezdett/elvégzett sessionhöz nem nyúlhat);
- a kliens a kapott sorok felett **teljes kontrollt** kap (törölheti, elindíthatja, figyelmen kívül hagyhatja);
- minden írás a `TrainerAccessService` ACTIVE-kapcsolat guardja mögött történik.

Ezt a kivételt a `01-koncepcio-es-folyamatok.md` 4. folyamatának "Írás soha" mondatánál és a `docs/06-development-rules.md`-ben dokumentálni kell a megvalósításkor.

## Mit lát a két oldal — összefoglaló

| | Edző (web) | Kliens (mobil) |
|---|---|---|
| Ütemterv-horizont | teljes (3 hónapig) | 7 nap (ma + 6) |
| Közelgő edzés | naptár/lista, sorozat-jelzéssel | "Közelgő" szekció + felugró kártya (aznapi) |
| Kihagyott edzés | ✅ látja (compliance) | nem hangsúlyos (eltűnik a közelgőből) |
| Elvégzett edzés | ✅ ütemtervben pipa + meglévő Edzések tab | normál session-előzmény |
| Lemondás | előfordulás vagy sorozat | saját közelgő session törlése |
