# Funkció-leltár — mi kerüljön a webre

A táblázatok a **meglévő backend végpontokból** indulnak ki (amit a Flutter app is használ). Minden funkciónál jelölve van, hogy mennyire való webre.

Jelölés:
- ✅ **Teljes** — weben ugyanúgy működik, mint mobilon.
- 🟡 **Részleges** — működik, de van mobil-specifikus rész (pl. kamera, szenzor).
- 📱 **Mobil-only** — eszközfüggő, weben nincs (vagy csak olvasható nézet).

---

## 1. Auth (`/api/v1/auth`)

| Funkció | Végpont | Web | Megjegyzés |
|---|---|---|---|
| Regisztráció | `POST /register` | ✅ | |
| Bejelentkezés | `POST /login` | ✅ | Web: refresh token httpOnly cookie-ba |
| Token frissítés | `POST /refresh` | ✅ | Automatikus, interceptorból |
| Kijelentkezés | `POST /logout` | ✅ | |
| Kijelentkezés minden eszközről | `POST /logout-all` | ✅ | Settings → eszközök/munkamenetek |

Szerepkörök ma: `ROLE_USER`, `ROLE_ADMIN`. (Bővíthető — lásd jövőbeli edző-rész.)

## 2. Dashboard (összevont nézet)

| Blokk | Forrás végpont(ok) | Web |
|---|---|---|
| Napi kalória összegzés | `meals`, `statistics/daily` | ✅ |
| Napi makró összegzés (kalória, fehérje) | `statistics/daily` | ✅ |
| Aktuális testsúly | `weights` | ✅ |
| Vízbevitel ma | `water-entries` | ✅ |
| Lépésszám ma | `steps` | 🟡 weben kézi/olvasható |
| Legutóbbi edzések | `workout-sessions` | ✅ |

## 3. Nutrition

| Funkció | Végpont | Web | Megjegyzés |
|---|---|---|---|
| Ételek (foods) CRUD | `/api/v1/foods` | ✅ | |
| Vonalkód keresés | `GET /foods/barcode/{barcode}` | 🟡 | Web: **kézi vonalkód-beírás**; kamerás szken mobilon marad |
| Étel rejtése | (food `hidden`) | ✅ | |
| Receptek CRUD | `/api/v1/recipes` | ✅ | |
| Recept kedvenc / adagszám | (recipe `favorite`, `servings`) | ✅ | |
| Étkezések naplózása | `/api/v1/meals` | ✅ | Nagy táblázatos UI-n weben kifejezetten kényelmes |

## 4. Workouts

| Funkció | Végpont | Web | Megjegyzés |
|---|---|---|---|
| Gyakorlatok CRUD | `/api/v1/exercises` | ✅ | kategória + eszköz szűrőkkel |
| Edzéssablonok CRUD | `/api/v1/workout-templates` | ✅ | cél-szettek, sorrend (drag&drop weben jól megy) |
| Edzés-munkamenetek | `/api/v1/workout-sessions` | ✅ | naplózás + előzmények |
| Edzés health mezők (pulzus stb.) | (session health fields) | 🟡 | Weben olvasható; a forrás (óra/health) mobil-only |

## 5. Testsúly / Víz / Lépés

| Funkció | Végpont | Web | Megjegyzés |
|---|---|---|---|
| Testsúly bevitel + előzmény | `/api/v1/weights` | ✅ | grafikon weben jól mutat |
| Vízbevitel + források | `/api/v1/water-entries`, `/water-sources` | ✅ | gyors gombok forrásonként |
| Napi lépésszám | `/api/v1/steps` | 🟡 | Web: kézi bevitel / megtekintés |

## 6. Statisztika (`/api/v1/statistics`)

| Funkció | Végpont | Web |
|---|---|---|
| Napi statisztika | `GET /daily` | ✅ |
| Heti statisztika | `GET /weekly` | ✅ |
| Havi statisztika | `GET /monthly` | ✅ |

> A statisztika a web egyik **legerősebb** része: nagy képernyőn több grafikon, szűrő, összehasonlítás fér el, mint mobilon.

## 7. Beállítások (`/api/v1/settings`)

| Funkció | Végpont | Web |
|---|---|---|
| Beállítások lekérése | `GET /settings` | ✅ |
| Beállítások mentése (nyelv, napi lépéscél stb.) | `PUT /settings` | ✅ |

---

## Mobil-only marad (weben nincs vagy csak olvasható)

- **Kamerás vonalkód-szkennelés** — weben helyette kézi beírás + `foods/barcode` lekérés.
- **Automatikus lépésszámlálás telefonszenzorból** — weben csak kézi bevitel.
- **Apple Health / HealthKit integráció** — eszközfüggő, mobil marad.
- **Offline-first / lokális DB szinkron** — a mobil app sajátja; a web online-first.

---

## Jövőbeli rész — Személyi edző (röviden)

> Ez **csak vázlat** a tervbe; az 1. fázisban nem épül meg. Részletes lépések a fejlesztési terv 10. fázisában.

A backend auth már most is **szerepkör-alapú** (`ROLE_USER`, `ROLE_ADMIN`, bővíthetőre tervezve), ezért a kiterjesztés nem igényel teljes átépítést.

Új koncepciók, amik majd kellenek:
- **Új szerepkör:** `ROLE_TRAINER` (és opcionálisan `ROLE_CLIENT`).
- **Edző ↔ kliens kapcsolat:** új tábla (Flyway migráció), meghívó/elfogadás flow.
- **Megosztási/jogosultsági modell:** az edző **csak a hozzárendelt kliensei** adatait láthatja (read), a meglévő „minden entitás egy userhez tartozik" szabály kiterjesztése.
- **Terv-hozzárendelés:** edző edzéssablont / étrendet rendel a klienshez.
- **Web RBAC:** szerepkör-alapú útvonal-védelem (edző dashboard vs. saját dashboard).
