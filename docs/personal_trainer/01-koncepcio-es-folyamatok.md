# 01 — Koncepció és folyamatok

## Szerepkörök

| Szerepkör | Ki kapja | Mit csinál |
|---|---|---|
| `ROLE_USER` | minden regisztrált user (ma is) | mobil app, saját adatok — **változatlan** |
| `ROLE_TRAINER` | a **super admin** osztja ki a webes felületén (lásd 5. folyamat) | a web `/admin` felület; kliensek meghívása, tartalom-hozzárendelés, kliens-fejlődés megtekintése |
| `ROLE_ADMIN` | meglévő, változatlan | rendszer-adminisztráció (jelenlegi funkciók) |
| `ROLE_SUPER_ADMIN` | **egyszeri SQL bootstrap** (a rendszer tulajdonosa); API-n keresztül nem osztható | user-lista megtekintése, `ROLE_TRAINER` kiosztása/visszavonása a web `/superadmin` felületén |

### Szerepkör-szabályozás (governance)

- **`ROLE_TRAINER` kiosztása kézi marad** — nincs önkiszolgáló "edzővé válok" flow. A kiosztást a super admin végzi a webes felületről.
- A `ROLE_SUPER_ADMIN` **nem osztható és nem vonható vissza API-ból** — kizárólag közvetlen SQL-lel (privilege-escalation védelem). Ugyanígy a `ROLE_ADMIN` sem kezelhető a super admin felületről: az API-ból **egyedül a `ROLE_TRAINER`** adható/vonható.
- A super admin **a saját szerepkörét nem módosíthatja** (self-lockout és self-escalation kizárva).
- Minden szerepkör-változás **audit-naplóba** kerül (ki, kinek, mit, mikor — lásd `02-domain-es-migraciok.md` V43).
- **`ROLE_TRAINER` visszavonásakor** az edző–kliens kapcsolatok a DB-ben `ACTIVE` maradnak, de az edző-végpontok a szerepkör hiánya miatt azonnal 403-at adnak → a hozzáférés azonnal megszűnik, újra-kiosztásnál pedig helyreáll, a kapcsolatok újraépítése nélkül. A kliensnél lévő másolt tartalmak (edzőtől kapott sablonok/receptek) érintetlenek — azok a kliens tulajdona.

Fontos: az edző **egyben sima user is** — saját ételei, receptjei, sablonjai, gyakorlatai ugyanúgy vannak, mint bárki másnak (a foods/exercises ownership után; lásd `02-domain-es-migraciok.md`). Az admin felületen a "saját tartalom" pontosan ugyanaz az adat, amit a mobil appjában is látna. **Nincs külön "edzői tartalomtár"** — ettől marad egyszerű a modell.

Egy kliensnek **több edzője is lehet** (a séma megengedi); az MVP UI-ban ezt nem kell külön kezelni, de nem is tiltjuk.

---

## 1. folyamat — Meghívás (edző → kliens)

```
Edző (web /admin/invites)                Backend                        Kliens (mobil)
       │                                    │                                │
       │ 1. e-mail cím beírása (pontos)     │                                │
       ├───────────────────────────────────►│                                │
       │    POST /trainer/invites           │                                │
       │                                    │ 2. user létezik? rate-limit ok?│
       │                                    │    → invite (PENDING, 24h)     │
       │ 3. "Meghívó elküldve" + listában   │                                │
       │◄───────────────────────────────────┤                                │
       │                                    │      4. app indul/előtérbe jön │
       │                                    │◄───────────────────────────────┤
       │                                    │  GET /trainer-invites/pending  │
       │                                    ├───────────────────────────────►│
       │                                    │     5. lebegő kártya az appban │
       │                                    │        [Elfogadom] [Elutasítom]│
       │                                    │◄───────────────────────────────┤
       │                                    │ POST /trainer-invites/{id}/respond
       │ 6. kliens megjelenik/eltűnik       │                                │
       │◄───────────────────────────────────┤                                │
```

### Üzleti szabályok (meghívó)

1. **Csak létező usert lehet meghívni.** Az edző a **teljes, pontos e-mail címet** adja meg — nincs részleges keresés / autocomplete (e-mail enumeráció elleni védelem, lásd lentebb).
2. **24 órás rate-limit:** egy edző egy adott e-mail címre **24 óránként legfeljebb egy** meghívót küldhet. A számítás az utolsó meghívó `created_at`-jétől megy, az eredménytől függetlenül (lejárt, elutasított — mindegy: 24 órán belül nincs újraküldés).
3. **24 órás érvényesség:** a meghívó `expires_at = created_at + 24 óra`. Lejárat után:
   - **nem listázódik** az edzőnek (a függő meghívók listájából eltűnik),
   - **nem jelenik meg** a kliens appjában,
   - az edző **újra meghívhatja** ugyanazt a címet (a rate-limit is épp ekkor jár le — a két szabály szándékosan ugyanaz az időablak).
4. **Duplikátum-védelem:** nem küldhető meghívó olyan usernek, akivel az edzőnek már **aktív** kapcsolata van.
5. **Elfogadás:** a kapcsolat `ACTIVE` lesz, a kliens felkerül az edző kliens-listájára.
6. **Elutasítás:** a meghívó `DECLINED`, eltűnik mindkét oldalról. Az edző a 24 órás ablak letelte után újra próbálkozhat.
7. **Bontás:** az edző bármikor eltávolíthatja a klienst, és a kliens is bármikor kiléphet a kapcsolatból (mobil Settings). Státusz: `REVOKED`. Bontás után a meghívási szabályok elölről érvényesek.

### E-mail enumeráció / adatvédelem

A pontos-egyezéses keresés is elárulja, hogy egy e-mail cím regisztrált-e. Személyes projektként ez elfogadott kockázat, de:
- a meghívó végpont edzőnként **globálisan is rate-limitelt** (pl. max 20 meghívó / nap), hogy ne lehessen címlistát végigpróbálni;
- a válasz nem ad vissza semmilyen user-adatot az e-mail címen túl (nincs név, avatar a küldés előtt).

---

## 2. folyamat — Tartalom-hozzárendelés (a "csavar")

Az edző a **saját** edzéssablonjait és receptjeit rendelheti a klienseihez. A sablon a saját gyakorlataira, a recept a saját ételeire (food-id-k) hivatkozik — ezek a kliensnél nem léteznek, ezért a hozzárendelés **deep copy**:

```
Edző sablonja                          Kliens fiókja (másolat)
┌────────────────────┐    assign      ┌────────────────────────────┐
│ WorkoutTemplate #7 │ ─────────────► │ WorkoutTemplate #93        │
│  ├─ Exercise #12   │                │  ├─ Exercise #94 (másolat) │
│  └─ Exercise #15   │                │  └─ Exercise #95 (másolat) │
└────────────────────┘                │  origin_source_id = 7      │
                                      │  origin_trainer_id = edző  │
                                      └────────────────────────────┘
```

Szabályok:

1. **Minden másolat a kliens tulajdona lesz** — a meglévő ownership-modell nem sérül, a mobil delta sync automatikusan leviszi a kliens készülékére, offline is működik. A kliens szerkesztheti/törölheti a saját másolatát (az edzőét nem érinti).
2. **Provenance:** a másolt sorok őrzik a származást (`origin_source_id`, `origin_trainer_id`). Ebből tudja a mobil kirakni az "edzőtől kapott" jelölést, és ebből tud a másoló-szolgáltatás **deduplikálni**: ha az edző ugyanazt a gyakorlatot/ételt két sablonban/receptben is használja, a kliensnél csak egyszer jön létre.
3. **Újra-hozzárendelés:** ha az edző módosította a sablonját és újra hozzárendeli, **új másolat** készül (verziózás helyett — egyszerűbb, és a kliens korábbi másolatán lévő előzmények nem vesznek el). A UI figyelmeztet, hogy már van korábbi hozzárendelés.
4. **Recept hozzárendelése** ugyanígy: recept + a hozzávalók által hivatkozott foods másolása + `recipe_ingredients` átkötése a másolt food-id-kra.
5. A hozzárendelés ténye a `content_assignments` táblába kerül (ki, kinek, mit, mikor) — ez az edző "kiosztott tervek" nézetének a forrása.

---

## 3. folyamat — Admin nézetváltás (web)

1. Az edző a weben a top bar user-menüjéből vált: **"Edző nézet"** → `/admin` útvonal.
2. Az `/admin`-ba lépéskor **feldobódik a kliens-lista modal** (a felhasználói igény szerint): az edző rögtön látja a klienseit, és egy kattintással beugorhat egy kliens részleteibe — vagy bezárja, és az admin dashboardon marad.
3. A `/admin/**` útvonalakat a Next.js middleware védi: `ROLE_TRAINER` nélkül redirect a sima dashboardra.
4. Vissza: user-menü → "Saját nézet" → `/dashboard`.

---

## 4. folyamat — Kliens-fejlődés megtekintése

Az edző a kliens adataiból **csak olvasva**, kapcsolat-ellenőrzés után látja:

| Adat | Látható? | Megjegyzés |
|---|---|---|
| Statisztika (kalória/makró trend, súlytrend, edzésvolumen) | ✅ | a meglévő statistics végpontok trainer-változata |
| Lépések | ✅ | napi lépésszám, trend |
| Testsúly | ✅ | a statisztika része + előzmény |
| Edzés-munkamenetek | ✅ | előzmény + részletek (szettek, súlyok) — a kiosztott sablon fejlődés-követéséhez |
| Étkezés-napló (meals) | ❌ MVP-ben nem | később megfontolható, adatvédelmileg érzékenyebb |
| Víz | ❌ | felhasználói döntés: nem kell az adminba |
| Beállítások, profil-részletek | ❌ | csak név/avatar/e-mail a kliens-kártyán |

Írás **soha**: az edző semmilyen kliens-adatot nem módosít közvetlenül — a hozzárendelés is a saját tartalom másolása, nem a kliens adatának szerkesztése.

---

## 5. folyamat — `ROLE_TRAINER` kiosztása (super admin)

1. A super admin a weben a user-menüből a **"Rendszer"** menüpontot választja → `/superadmin/users` (csak `ROLE_SUPER_ADMIN`-nal látható/elérhető).
2. **User-lista:** lapozott táblázat, e-mail szerinti kereséssel; soronként a user szerepkör-badge-ei.
3. **"Edzővé tétel":** a soron lévő kapcsoló/gomb → megerősítő dialog ("{email} mostantól edző lesz: elérheti az edző admin felületet és klienseket hívhat meg.") → `ROLE_TRAINER` hozzáadása.
4. **Visszavonás:** ugyanott, megerősítéssel ("Az edző-hozzáférése azonnal megszűnik; a kliens-kapcsolatai megmaradnak, ha később visszakapja a szerepkört.").
5. A változás **azonnal érvényes az új tokenekre**; a már kiadott access tokenben a régi `roles` claim él a lejáratáig (max 15 perc) — ez elfogadott ablak, nem kell token-visszavonási mechanizmus.
6. Az érintett usernek **nem megy értesítés** MVP-ben (a kiosztás személyes egyeztetés után történik); későbbi opció: e-mail a Resend-en át.
