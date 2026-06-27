# Lifey Web — Backend-hiányosságok és szükséges változtatások

> A web a meglévő API-t fogyasztja, de a design néhány eleme **a jelenlegi backenddel nem
> valósítható meg teljesen**. Ez a fájl egy helyre gyűjti ezeket: mindegyikhez **döntés**,
> **javasolt szerződés/migráció** és **elfogadási kritérium**. A backend-szabályok kötik:
> Flyway-migráció minden DB-változáshoz, feature-alapú csomagolás, Service-interfész + Impl,
> minden entitás userhez kötött, REST only, Java 24/Maven.

Prioritás-jelölés: 🔴 blokkoló (F0–F1) · 🟠 fontos (a teljes élményhez) · 🟢 nice-to-have.

---

## 1. 🔴 CORS + refresh-token cookie (F0 előfeltétel)

**Probléma:** a web más originről (`localhost:3000`, prod domain) hívja az API-t → CORS kell.
A refresh token ma a **válasz body-ban** jön; weben biztonságosabb httpOnly cookie.

**Javaslat:**
- **CORS:** Spring Security `CorsConfigurationSource` — engedélyezett originek (dev + prod),
  `allowCredentials=true`, engedélyezett metódusok/headerek. Konfigból (env), ne bedrótozva.
- **Refresh cookie (A opció, ajánlott):** a `/auth/login` és `/auth/refresh` válasz `Set-Cookie`-val
  küldi a refresh tokent (`HttpOnly; Secure; SameSite=Strict|Lax; Path=/api/v1/auth; Max-Age=...`).
  A `/auth/refresh` és `/auth/logout` **a cookie-ból** olvassa a tokent (a body marad opcionális a
  mobilnak → visszafelé kompatibilis). Al-domain elrendezésnél a `SameSite`/`Domain` egyeztetése.
- **B opció (gyors start):** marad a body, a web `sessionStorage`-ban tárol. Nincs backend-munka,
  de XSS-érzékenyebb — csak átmenetnek.

**Elfogadás:** a web be tud jelentkezni CORS-hiba nélkül; lapfrissítés után a refresh-ciklus
helyreállítja a sessiont; logout/logout-all visszavonja a tokent.

---

## 2. 🔴 Statisztika idősor (a trend-grafikonok feltétele)

**Probléma:** a `StatisticsResponse` **egyetlen aggregált skalár-halmaz** (összes kcal/protein/…,
workoutCount, latestWeight, totalWater) a daily/weekly/monthly időszakra. A statisztika-oldal
(mockup 10/11. frame) és a dashboard mini-grafikonjai **napi bontású idősort** várnak (kalória-trend,
súly-trend, heti volumen, vs. előző időszak).

**Javaslat (A — ajánlott): új idősoros végpont.**
```
GET /api/v1/statistics/series?from=yyyy-MM-dd&to=yyyy-MM-dd&metric=calories|protein|carbs|fat|weight|water|steps|volume&bucket=day|week
→ { metric, bucket, points: [ { date: LocalDate, value: number }, ... ] }
```
- Userhez kötött, ugyanazokból az adatokból aggregál, mint a meglévő statisztika.
- A „vs. előző időszak" delta a sorból vagy két tartomány lekéréséből számolható kliensoldalon.
- Új `StatisticsSeriesService` (interfész + Impl), nincs DB-séma változás (lekérdezés-aggregáció).

**Javaslat (B — átmenet): kliensoldali aggregálás.** A web N db `GET /statistics/daily?date=...`
hívással építi a sort. **Hátrány:** sok kérés, lassú, terheli a backendet — csak amíg A nincs kész.

**Elfogadás:** a statisztika-oldal valós napi pontokból rajzol trendet a kiválasztott időszakra, és
mutatja a vs.-előző deltát; egy időszak ≤ 1–2 kéréssel betölt.

---

## 3. 🟠 Lista-lapozás (pagination)

**Probléma:** a `GET /foods`, `/meals`, `/exercises`, `/recipes`, `/workout-sessions`, `/weights`,
`/water-entries`, `/steps` **teljes `List`-et** ad vissza. A design lapozott táblázatokat mutat
(„1–4 of 128"), és sok adatnál a teljes lista lassú. Lásd `docs/14-pagination-plan.md`.

**Javaslat:** ahol a lista nőhet (elsősorban **foods**, **meals**, **workout-sessions**), vezess be
Spring Data `Pageable`-t:
```
GET /api/v1/foods?page=0&size=25&sort=name,asc&query=...&hidden=false
→ Page<FoodResponse>  (content, totalElements, totalPages, number, size)
```
- Visszafelé kompatibilitás: vagy új query-paraméterek mellett megtartott teljes-lista default,
  vagy verziózott. A mobil hatását egyeztetni (lásd `docs/14-pagination-plan.md`).
- A web `<DataTable pagination>` már erre felkészítve (06 §6.4) — átkapcsolás API-szinten.

**Elfogadás:** a foods/meals/sessions lista oldalanként tölt, a táblázat lapozója a `Page`
metaadatból dolgozik; nagy adathalmaznál is gyors első festés.

---

## 4. 🟠 Szerver-oldali keresés/szűrés

**Probléma:** a topbar-kereső és a foods/exercises szűrők ma **kliensoldaliak** (teljes lista letöltve).
Lapozással ez nem működik (csak az adott oldalon keresne).

**Javaslat:** a 3. ponttal együtt — `?query=` (név `ILIKE`), foods `?hidden=`, exercises
`?category=&equipment=`. Ezek a meglévő repository-kba illeszthető szűrők, séma-változás nélkül.

**Elfogadás:** a kereső/szűrő a teljes adathalmazon dolgozik a backendben, nem csak a betöltött oldalon.

---

## 5. 🟠 Napi szűrés a naplókra (`?date`)

**Probléma:** a `meals`/`water-entries` nincs dátumra szűrve — a web a teljes listát kéri, és
kliensoldalon szűri a kiválasztott lokál-napra. Ez a lista növekedésével pazarló.

**Javaslat:** `GET /api/v1/meals?date=yyyy-MM-dd` és `/water-entries?date=yyyy-MM-dd`, ahol a backend
a hívó lokál-napjára szűr (ugyanaz a nap-határ logika, mint a statisztikánál). Egyszerű
repository-lekérdezés, nincs séma-változás.

**Elfogadás:** a Meals/Water oldal egy nap adatát egy szűrt lekéréssel kapja.

---

## 6. 🟢 Weight upsert / azonos napra

**Probléma:** a `weights` nem ad PUT-ot; nem definiált, mi történik **azonos napra** küldött új POST
esetén (felülír / hibázik / duplikál). A Weight-oldal javítás-folyamata ettől függ.

**Javaslat:** definiáld a viselkedést — vagy **upsert dátumra** (egy súly/nap), vagy `PUT /weights/{id}`.
Dokumentáld; a `WeightRequest.date` egyediségét DB-szinten is érdemes (unique a (user, date)-re,
Flyway-migráció), ha az „egy súly/nap" a kívánt modell.

**Elfogadás:** a web egyértelműen tud súlyt javítani anélkül, hogy duplikátum keletkezne.

---

## 7. 🟢 Profil-szerkesztés és jelszóváltás

**Probléma:** a Settings „Profile" és „Security" szekció szerkesztést sugall, de ma csak
`UserResponse` (olvasás) és `logout-all` van; nincs profil-update / jelszóváltó végpont.

**Javaslat:** ha kell, `PUT /api/v1/users/me` (profil) és `POST /api/v1/auth/change-password`
(régi+új jelszó). Amíg nincs, ezek a UI-mezők **olvashatók/letiltottak**, és a Security csak a
logout-all-t kínálja.

**Elfogadás:** a Settings nem ígér olyan akciót, amihez nincs végpont (vagy megépül a végpont).

---

## 8. 🟢 OpenAPI → TS típusgenerálás

**Probléma:** a DTO-szerződéseket ma kézzel képezzük le Zod/TS-re → elcsúszhat a backendtől.

**Javaslat:** a backend már springdoc-openapi-t használ (`OpenApiConfig`). Generálj TS-típusokat az
OpenAPI sémából (pl. `openapi-typescript`) build-lépésként, és a Zod sémák ezekhez igazodjanak (vagy
`zod`-ot generálj). Így a `05` szerződés-eltérés CI-ben kibukik.

**Elfogadás:** API-séma változás → típushiba a webes buildben (nem néma futásidejű törés).

---

## Összegző döntési lista (a fejlesztés indítása előtt)

| # | Téma | Döntés szükséges | Ajánlás |
|---|---|---|---|
| 1 | CORS + refresh | cookie (A) vs. body (B) | **A** |
| 2 | Statisztika idősor | új végpont (A) vs. kliens-aggregálás (B) | **A** |
| 3 | Lapozás | mely listák, séma | foods/meals/sessions először |
| 4 | Keresés/szűrés szerveren | igen/nem | igen, a 3-mal együtt |
| 5 | Napi `?date` szűrő | igen/nem | igen |
| 6 | Weight upsert | upsert vs. PUT | upsert (egy súly/nap) |
| 7 | Profil/jelszó végpont | most vagy később | később, addig olvasható UI |
| 8 | OpenAPI→TS | igen/nem | igen |

> Az 1. és 2. pont **blokkoló** a teljes első körhöz (auth + statisztika-oldal). A 3–5. a lista-élmény
> minőségét adja; a 6–8. fokozatosan. A web úgy épül, hogy a 3–5. backend-oldali bevezetésekor a
> kliens minimális változással átkapcsoljon (lásd 06 §6.4, 04 §3).
