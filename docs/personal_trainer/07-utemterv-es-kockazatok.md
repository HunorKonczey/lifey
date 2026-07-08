# 07 — Ütemterv, mérföldkövek, kockázatok

## Fázisok

A sorrend elve: előbb a **fundamentum** (ownership), aztán a **kapcsolat**, aztán az **érték** (kiosztás + fejlődés-követés). Minden fázis önállóan szállítható.

### PT0 — Foods/exercises ownership (fundamentum, ⚠ a legkockázatosabb)
1. `V40__foods_exercises_ownership.sql` (oszlopok, per-user duplikálás + remap, indexek, updated_at bump).
2. `Food`/`Exercise` entity + service + repo user-szűrés; barcode lookup user-scope.
3. Regisztrációs starter-katalógus seed (`StarterCatalogListener`).
4. Testcontainers migrációs teszt (több user, kereszthivatkozások).
5. Mobil: kényszerített foods/exercises újraszinkron az átálláshoz kötött app-verzióban.
6. Összehangolt release: backend+migráció → azonnal mobil app frissítés.

**Kész, ha:** két külön user külön food/exercise katalógust lát, a meglévő adatok (meals, receptek, sablonok, sessionök) hiánytalanul helyesek, a mobil sync zöld.

### PT1 — Szerepkörök, kapcsolat és meghívó
7. `V41__trainer_clients.sql` + entity/repo; `V43__role_audit_log.sql`.
8. `ROLE_TRAINER` + `ROLE_SUPER_ADMIN` konstansok, SecurityConfig szabályok (`/trainer/**`, `/superadmin/**`); super admin bootstrap kézi SQL-lel; `RoleManagementService` + `/superadmin/users` végpontok.
8b. Web: `/superadmin/users` felület (user-lista, keresés, Edzővé tétel/visszavonás, audit-történet) — innentől a `ROLE_TRAINER` kiosztás már felületről megy, nem SQL-lel.
9. `TrainerInviteService` (rate-limit, lejárat, állapotgép) + edző- és kliens-oldali controller-ök + cleanup job.
10. Mobil: pending-invite polling + lebegő kártya + respond; Settings "Edzőim" + kilépés.
11. Web: `/admin` route group + middleware guard + admin shell (sidebar, EDZŐ chip) + kliens-lista modal + dashboard + meghívó oldal.

**Kész, ha:** super adminként felületről edzővé teszek egy usert; edzőként webről meghívok egy usert e-maillel, a mobilján feljön a kártya, elfogadja, megjelenik a kliens-listámban; a 24 órás szabályok érvényesülnek.

### PT2 — Kliens-fejlődés (read-only)
12. Statistics/steps/weight/sessions service-ek `forUser(userId)` refaktora.
13. `TrainerAccessService` + `/trainer/clients/{id}/...` olvasó végpontok.
14. Web: kliens-részletek (Áttekintés / Statisztika / Lépések / Edzések tabok, read-only badge).

**Kész, ha:** edzőként látom egy aktív kliensem statisztikáit és lépéseit, egy idegen userét pedig 403-mal nem.

### PT3 — Tartalom-kiosztás (a "csavar")
15. `V42__content_assignments.sql` + provenance oszlopok (recipes, workout_templates).
16. `ContentAssignmentService` deep copy + dedupe + tesztek.
17. Web: saját workouts/nutrition oldalak admin alatt + "Add to user" gomb + AssignToClientDrawer + `/admin/assignments` lista.
18. Mobil: `origin_trainer_id` a sync DTO-kban + drift táblákban + "Edzőtől" badge.

**Kész, ha:** kiosztok egy sablont és egy receptet, a kliens mobilján sync után megjelennek "Edzőtől" jelöléssel, offline is használhatók, és az edzései visszakövethetők a kliens-részletek Edzések tabján.

### PT4 — Csiszolás

✅ **Kész (2026-07-08).** PT0–PT5 mind megvalósultak (migrációk `V40`–`V47`); a csiszolás alábbi három pontja is lezárva:

19. ✅ E2E (Playwright): meghívás → elfogadás (API-szimulált) → kiosztás → kliens-statisztika (`web/e2e/trainer-flow.spec.ts`) — kiegészítve az ütemezés lépésével (drawer → időrendi státusz "upcoming" a kliens idővonalán).
20. ✅ i18n átnézés (HU/EN, ARB + next-intl): teljes kulcs-egyezés mindkét oldalon (`web/messages/en.json`↔`hu.json`, `mobile/lib/l10n/app_en.arb`↔`app_hu.arb`), valódi (nem placeholder) magyar fordításokkal; üres/hiba/loading állapotok lefedve (`Skeleton`/`EmptyState`/`ErrorState` a web oldalon, a mobil "Közelgő" szekció egyszerűen eltűnik üresen, nincs saját hiba/loading állapota, mert helyi drift-cache-ből olvas); nincs hardkódolt szín, minden CSS-token/`ColorScheme` alapú (dark/light automatikusan követi).
21. ✅ Dokumentáció-frissítés: `docs/03-domain-model.md` (a `WorkoutSession` bővítése + új `WorkoutSchedule` entitás), `docs/06-development-rules.md` (a trainer-kivétel a userId-szabály alól, kiegészítve az edző-írás és a trainerId-alapú (nem clientId-alapú) tulajdonjog-ellenőrzés eseteivel), `docs/web/01-feature-inventory.md` és `docs/web/02-development-plan.md` (a "csak vázlat" F10-jelzés frissítve a tényleges státuszra).

## Kockázatok és ellenszerek

| Kockázat | Súly | Ellenszer |
|---|---|---|
| **V40 remap hibásan köt át hivatkozást** → csendes adatromlás (rossz étel a naplóban) | magas | Testcontainers-teszt kereszthivatkozásokkal; éles előtt teljes DB backup; darabolt ellenőrző query-k (count-egyezés userenként) |
| **Delta sync elcsúszás** a mobil régi cache-ével | magas | kényszerített újraszinkron az app-verzióban; rövid, összehangolt release-ablak; a régi app-verzió API-szinten továbbra is működik (csak árva sorokat mutathat) |
| E-mail enumeráció a meghívón keresztül | közepes | pontos-egyezés only, napi globális meghívó-keret, semmilyen user-adat a válaszban |
| Jogosultsági rés a trainer-olvasókon | magas | minden `/trainer/clients/{id}/**` hívás kötelezően `TrainerAccessService`-en át; controller-teszt 403-ra; a `{clientId}`-kivétel dokumentálva |
| Deep copy félbeszakad → fél-sablon a kliensnél | közepes | egyetlen `@Transactional` egység; tesztelt rollback |
| Duplikált katalógus-elemek felhalmozódása a kliensnél (többszöri kiosztás) | alacsony | origin-alapú dedupe a gyakorlat/étel szinten; sablon/recept szinten UI-figyelmeztetés |
| GDPR / adatláthatóság | közepes | explicit lista a mobil Settingsben, hogy mit lát az edző; kilépés bármikor; edző csak ACTIVE kapcsolat alatt olvas |
| Privilege escalation a szerepkör-kezelő API-n | magas | API-ból kizárólag `ROLE_TRAINER` kezelhető (kódban rögzített whitelist); `SUPER_ADMIN`/`ADMIN` SQL-only; self-módosítás tiltva; append-only audit-napló (V43) |

## Eldöntött kérdések

1. ~~**ROLE_TRAINER kiosztás** hosszú távon: marad kézi, vagy legyen önkiszolgáló flow?~~ → **Eldöntve (2026-07-03): kézi marad**, de nem SQL-lel: új `ROLE_SUPER_ADMIN` szerepkör kapja a kiosztó felületet (`/superadmin/users`). Részletek: `01-koncepcio-es-folyamatok.md` §Szerepkör-szabályozás és 5. folyamat, `03-backend-terv.md` §RoleManagementService, `04-web-admin-terv.md` §7, `06-design.md` §3.6.

## Nyitott kérdések (döntést igényel, de nem blokkoló)

2. **Étkezési napló láthatósága** az edzőnek: MVP-ben nem — később opt-in a kliens oldaláról?
3. **Meghívó e-mail** is menjen a mobil-kártya mellett (Resend infra adott)? MVP-ben nem kell — a 24 órás lejárat miatt viszont hasznos lehet, ha a kliens ritkán nyitja az appot.
4. Ha a kliens **törli** az edzőtől kapott másolatot, az edzőnél a "kiosztott tervek" mit mutasson? (Javaslat: assignment megmarad "kliens törölte" jelzéssel — v2.)
5. Sablon-**verziókövetés** (újra-kiosztás új másolat helyett update-tel): tudatosan elhalasztva, a jelenlegi modell nem zárja ki.
