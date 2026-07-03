# 03 — Backend terv (Spring Boot)

## Csomagstruktúra (feature-alapú, a meglévő konvenciók szerint)

```
com.lifey.trainer/
  TrainerClient.java              # entity (trainer_clients)
  ContentAssignment.java          # entity (content_assignments)  → 2+ entity esetén entity/ alcsomag
  TrainerClientRepository.java
  ContentAssignmentRepository.java # → 2+ repo esetén repository/ alcsomag
  TrainerInviteController.java    # meghívó végpontok (edző oldal)
  TrainerClientController.java    # kliens-lista, kliens-adat olvasó végpontok
  ClientInviteController.java     # a KLIENS (mobil) oldali végpontok
  AssignmentController.java
  service/
    TrainerInviteService(+Impl)   # meghívó életciklus + rate limit
    TrainerAccessService(+Impl)   # kapcsolat-ellenőrzés (authorizáció)
    ContentAssignmentService(+Impl) # deep copy + dedupe
    TrainerClientQueryService(+Impl) # kliens-adatok read-only aggregálása
  exception/
    InviteRateLimitedException, InviteNotFoundException,
    NotYourClientException, AlreadyClientException, UserNotFoundForInviteException
  dto/ …
  TrainerClientCleanupJob.java    # PENDING→EXPIRED átbillentés (PasswordResetTokenCleanupJob mintájára)
```

Konstruktor-injektálás, Service interface + Impl, minden a bejelentkezett userből (`CurrentUserProvider`) indul — a meglévő szabályok szerint.

Külön kis feature-csomag a szerepkör-kezelésnek:

```
com.lifey.superadmin/
  SuperAdminUserController.java   # user-lista + szerepkör grant/revoke
  RoleAuditLog.java               # entity (role_audit_log)
  RoleAuditLogRepository.java
  service/
    RoleManagementService(+Impl)  # szabályok (lásd lent) + audit-írás
  exception/
    RoleNotManageableException, CannotModifySelfException
  dto/ …
```

## Szerepkörök és security

- Új konstansok: `ROLE_TRAINER`, `ROLE_SUPER_ADMIN`. A JWT `roles` claim már listát hordoz — **nincs token-formátum változás**.
- SecurityConfig:
  - `/api/v1/trainer/**` → `hasRole('TRAINER')`
  - `/api/v1/superadmin/**` → `hasRole('SUPER_ADMIN')`
- A kliens-oldali végpontok (`/api/v1/trainer-invites/**`, kilépés) sima `ROLE_USER`-rel mennek.
- `ROLE_SUPER_ADMIN` bootstrap: egyszeri kézi SQL (lásd `02-domain-es-migraciok.md` V43 megjegyzés).

### RoleManagementService szabályai

1. API-ból **kizárólag `ROLE_TRAINER`** adható és vonható vissza — a `ROLE_ADMIN` és `ROLE_SUPER_ADMIN` kezelése SQL-only (`RoleNotManageableException` → 400). Ez a whitelist kódban rögzített, nem konfig.
2. A super admin **saját magán nem módosíthat** szerepkört (`CannotModifySelfException` → 400).
3. Grant idempotens (már meglévő szerepkörre 200, nem hiba); revoke nemlétező szerepkörre 404.
4. Minden sikeres grant/revoke **egy tranzakcióban** ír a `user_roles`-ba és a `role_audit_log`-ba.
5. Revoke után a már kiadott access tokenek a lejáratukig (≤15 perc) még hordozzák a régi claimet — elfogadott ablak, nincs token-visszavonás. A refresh-nél már az új szerepkör-lista kerül a tokenbe.

### A userId-a-path-ban kivétel

A projektszabály ("controller sosem fogad userId-t") a **saját** adatokra vonatkozik. A trainer végpontok definíció szerint **másik** user adatáról szólnak, ezért ott a `{clientId}` path-változó legitim — de **minden** ilyen hívást a `TrainerAccessService.requireActiveClient(trainerId, clientId)` őriz, ami a `trainer_clients` táblában ACTIVE kapcsolatot követel, különben 403 (`NotYourClientException`). Ezt a kivételt a `docs/06-development-rules.md`-ben dokumentálni kell.

## Végpontok

### Edző oldal (web admin) — mind `ROLE_TRAINER` + kapcsolat-guard

| Metódus | Útvonal | Leírás |
|---|---|---|
| POST | `/api/v1/trainer/invites` | Meghívó küldése `{ "email": "..." }`. Hibák: 404 nincs ilyen user, 409 már aktív kliens, 429 rate-limit (24h / globális napi keret) |
| GET | `/api/v1/trainer/invites` | Függő (PENDING, nem lejárt) meghívók listája |
| DELETE | `/api/v1/trainer/invites/{id}` | Függő meghívó visszavonása |
| GET | `/api/v1/trainer/clients` | Aktív kliensek (név, avatar, e-mail, utolsó aktivitás, kiosztott tervek száma) |
| DELETE | `/api/v1/trainer/clients/{clientId}` | Kapcsolat bontása edző oldalról (REVOKED) |
| GET | `/api/v1/trainer/clients/{clientId}/statistics/daily|weekly|monthly` | A meglévő statistics service **újrahasznált** logikája, célzott userrel |
| GET | `/api/v1/trainer/clients/{clientId}/steps?from&to` | Kliens lépései |
| GET | `/api/v1/trainer/clients/{clientId}/weights?from&to` | Kliens testsúly-előzménye |
| GET | `/api/v1/trainer/clients/{clientId}/workout-sessions` (lapozott) | Kliens edzés-előzményei + részletek |
| GET | `/api/v1/trainer/clients/{clientId}/assignments` | Ennek a kliensnek kiosztott tartalmak |
| POST | `/api/v1/trainer/assignments` | Hozzárendelés: `{ clientId, contentType: TEMPLATE\|RECIPE, sourceId }` → deep copy |

A statistics/steps/weight/sessions olvasók implementációja: a meglévő service-ek **userId-paraméteres belső változatát** hívják (refaktor: a jelenlegi `getX()` → `getXForUser(userId)` + a publikus változat a current userrel delegál). Így nincs logika-duplikáció.

### Super admin oldal (web) — `ROLE_SUPER_ADMIN`

| Metódus | Útvonal | Leírás |
|---|---|---|
| GET | `/api/v1/superadmin/users?search=&page=` | Lapozott user-lista, e-mail részleges keresés; válasz: id, e-mail, név, avatar, szerepkörök, regisztráció ideje |
| POST | `/api/v1/superadmin/users/{userId}/roles` | `{ "role": "ROLE_TRAINER" }` — kiosztás (csak TRAINER engedett, lásd RoleManagementService) |
| DELETE | `/api/v1/superadmin/users/{userId}/roles/ROLE_TRAINER` | Visszavonás |
| GET | `/api/v1/superadmin/users/{userId}/role-audit` | Az adott user szerepkör-történetének audit-listája |

> Itt a `{userId}` path-változó ugyanazon logika mentén legitim, mint a trainer-végpontoknál: a super admin definíció szerint más userekről dönt, a jogosultságot a szerepkör (és a service-szabályok) adják.

### Kliens oldal (mobil) — `ROLE_USER`

| Metódus | Útvonal | Leírás |
|---|---|---|
| GET | `/api/v1/trainer-invites/pending` | A user függő, nem lejárt meghívói: `[{ id, trainerName, trainerAvatarUrl, invitedAt, expiresAt }]` |
| POST | `/api/v1/trainer-invites/{id}/respond` | `{ "accept": true\|false }` → ACTIVE vagy DECLINED |
| GET | `/api/v1/my-trainers` | Aktív edzőim (Settings-be: lista + kilépés) |
| DELETE | `/api/v1/my-trainers/{trainerId}` | Kilépés a kapcsolatból kliens oldalról (REVOKED) |

## TrainerInviteService — szabályok implementálása

```
invite(trainerEmailInput):
  client = userRepository.findByEmailIgnoreCase(email) ?: throw UserNotFound
  if client == trainer → 400
  if exists ACTIVE (trainer, client) → 409 AlreadyClient
  if exists sor (trainer, client) created_at > now()-24h → 429 InviteRateLimited
  if count(trainer meghívói ma) >= 20 → 429 (globális napi keret)
  insert PENDING, expires_at = now()+24h
```

- A lejárat **olvasáskor** érvényesül (a query-k `status='PENDING' and expires_at > now()`-t szűrnek); a `TrainerClientCleanupJob` (napi egyszer) billenti át `EXPIRED`-re a lejártakat — így a rendszer akkor is helyes, ha a job nem fut.
- Válaszkor (`respond`): csak a saját, PENDING, nem lejárt meghívóra; különben 404/410.

## ContentAssignmentService — deep copy

```
assign(trainerId, clientId, TEMPLATE, sourceId):
  requireActiveClient(trainerId, clientId)
  template = sajátjaim közül (ownership check!)                # 404, ha nem az edzőé
  @Transactional:
    for exercise in template gyakorlatai:
      copy = kliens meglévő másolata (origin_trainer_id=trainer és origin_source_id=exercise.id, él)
             ?: új Exercise a kliensnek (mezők másolása + origin_* beállítás)
    newTemplate = Template másolat a kliensnek (origin_* + target set-ek, sorrend)
    template_exercises átkötése a másolt exercise id-kra
    insert content_assignments (TEMPLATE, sourceId, newTemplate.id)
```

Recept ugyanez: `recipe_ingredients` → hivatkozott `foods` másolása/dedupe → átkötés. A másolatok `SyncableEntity`-k, `updated_at` beáll → a kliens mobilja a **következő delta sync-nél automatikusan megkapja** — külön push/értesítés nélkül is megjelenik nála.

Újra-hozzárendelésnél a service nem tiltja a duplikátumot (a UI figyelmeztet), de a válaszban visszaadja, hogy volt-e korábbi assignment ugyanarra a source-ra.

## Tesztek

- **Migrációs teszt (Testcontainers):** V40 több userrel, kereszthivatkozásokkal — a remap után minden user meal/recipe/template/session hivatkozása a saját food/exercise soraira mutat.
- **TrainerInviteServiceTest:** rate-limit ablak, lejárat, duplikátum, self-invite, respond állapotgép.
- **TrainerAccessServiceTest:** idegen kliens → 403; bontott kapcsolat → 403.
- **ContentAssignmentServiceTest:** deep copy teljessége, dedupe (két sablon közös gyakorlattal → egy kliens-oldali másolat), tranzakciós rollback.
- **Controller-teszt:** `ROLE_USER` a `/trainer/**`-re → 403; `ROLE_TRAINER` a `/superadmin/**`-re → 403.
- **RoleManagementServiceTest:** csak TRAINER kezelhető (ADMIN/SUPER_ADMIN grant → 400), self-módosítás tiltva, grant+audit egy tranzakcióban, idempotens grant.
