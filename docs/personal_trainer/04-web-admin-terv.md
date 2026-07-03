# 04 — Web admin felület terv (Next.js)

A meglévő `web/` appra épül (App Router, TanStack Query, shadcn/ui, next-intl — lásd `docs/web/02-development-plan.md`). Az admin **nem külön app**, hanem egy új route group + feature-mappa.

## Útvonalak

```
web/src/app/
  (app)/…                      # meglévő saját nézet — változatlan
  (admin)/admin/
    layout.tsx                 # admin shell: saját sidebar + guard + kliens-lista modal
    page.tsx                   # /admin → dashboard (kliens-kártyák)
    invites/page.tsx           # meghívók
    clients/[clientId]/
      page.tsx                 # kliens áttekintő (statisztika összefoglaló)
      statistics/page.tsx      # részletes statisztika
      steps/page.tsx           # lépések
      workouts/page.tsx        # edzés-előzmények + kiosztott sablonok fejlődése
    workouts/page.tsx          # SAJÁT sablonok + gyakorlatok (Add to user gombbal)
    nutrition/page.tsx         # SAJÁT ételek + receptek (recepten Add to user gomb)
    assignments/page.tsx       # kiosztott tartalmak listája (minden kliens)
  (superadmin)/superadmin/
    layout.tsx                 # minimál shell + ROLE_SUPER_ADMIN guard
    users/page.tsx             # user-lista + ROLE_TRAINER kiosztás/visszavonás
```

Döntés (a felhasználói kérdésre "URL vagy state"): **URL**. A `/admin` prefix linkelhető, frissítés-álló, a middleware-ben szerepkörrel védhető, és a "melyik nézetben vagyok" állapot nem tud elcsúszni.

## RBAC / guard

- `middleware.ts`: `/admin/**` → ha a session szerepkörei közt nincs `ROLE_TRAINER` → redirect `/dashboard`; `/superadmin/**` → `ROLE_SUPER_ADMIN` nélkül redirect `/dashboard`.
- A `useSession()` hook már ad szerepkört (JWT `roles` claim) — a top bar user-menüje csak akkor mutatja az **"Edző nézet"** menüpontot, ha van `ROLE_TRAINER`, és csak akkor a **"Rendszer"** menüpontot, ha van `ROLE_SUPER_ADMIN`. (A kettő független: a super admin nem feltétlenül edző, és fordítva.)
- Defense in depth: a backend úgyis 403-at ad — a frontend guard csak UX.

## Belépési élmény: kliens-lista modal

Az `/admin`-ra érkezéskor (per session egyszer) egy modal dobódik fel a kliensekkel:

- kliens-kártyák: avatar, név, utolsó aktivitás, "megnyitás" → `/admin/clients/{id}`;
- "Bezárás" → az admin dashboard marad alatta (ugyanezek a kártyák rácsban);
- ha **nincs még kliens** → a modal helyett üres állapot CTA-val: "Hívd meg az első kliensed" → `/admin/invites`;
- implementáció: `sessionStorage` flag (`adminClientModalShown`), hogy navigálgatás közben ne ugráljon fel újra.

## Feature-mappa

```
web/src/features/trainer/
  api.ts        # /trainer/* végpont-hívások
  hooks.ts      # useClients, useInvites, useClientStatistics(clientId), useAssignments, …
  schemas.ts    # inviteSchema (email), assignSchema
  types.ts
  components/
    ClientCard.tsx, ClientListModal.tsx, InviteForm.tsx, InviteList.tsx,
    AssignToClientDrawer.tsx, ClientStatsPanel.tsx, ReadOnlyBadge.tsx
```

## Képernyők és viselkedés

### 1. Admin dashboard (`/admin`)
- Kliens-kártya rács: avatar, név, utolsó aktivitás (utolsó edzés/mérés dátuma), kiosztott tervek száma, mini súlytrend sparkline.
- Kártya-akciók: megnyitás; "…" menü → kapcsolat bontása (confirm dialog).
- Jobb felső CTA: "+ Kliens meghívása".

### 2. Meghívók (`/admin/invites`)
- **Form:** egyetlen e-mail mező (teljes cím, Zod email-validáció) + "Meghívás" gomb.
- Hibaállapotok leképezése: 404 → "Nincs ilyen felhasználó"; 409 → "Már a kliensed"; 429 → "Erre a címre 24 órán belül már küldtél meghívót" ill. "Napi meghívó-keret elérve".
- **Függő meghívók listája:** e-mail, küldve, lejár (visszaszámláló badge, pl. "még 16 óra"), visszavonás gomb. Lejárt/elutasított meghívó **nem jelenik meg** (backend nem is adja vissza).

### 3. Saját edzés-tartalom (`/admin/workouts`)
- A meglévő saját-nézet workouts oldal komponenseinek újrahasznosítása (lista, sablon-szerkesztő) — **plusz** minden sablon-kártyán/sorban **"Add to user"** gomb.
- "Add to user" → **AssignToClientDrawer**: kliens-választó (kereshető lista), a kiválasztott sablon összefoglalója (gyakorlatok), figyelmeztetés ha ennek a kliensnek már ki volt osztva ("Újra kiosztod? Új másolat készül."), majd "Hozzárendelés".
- Gyakorlat-könyvtár rész: sima saját CRUD (nincs Add to user — gyakorlat önmagában nem osztható ki, csak sablonon keresztül utazik).

### 4. Saját nutrition-tartalom (`/admin/nutrition`)
- Saját ételek + receptek (meglévő komponensek). **Recepten "Add to user" gomb** → ugyanaz az AssignToClientDrawer, recept-összefoglalóval (hozzávalók, makrók).
- Ételeken nincs Add to user (food csak recepten keresztül utazik) — ha később kell, a drawer általánosítható.

### 5. Kliens-részletek (`/admin/clients/[clientId]`)
- Fejléc: avatar, név, e-mail, kapcsolat kezdete, "read-only" badge; tab-sor: **Áttekintés / Statisztika / Lépések / Edzések**.
- **Áttekintés:** heti kalória-átlag, aktuális súly + trend, e heti edzésszám, lépés-átlag; kiosztott tervek listája státusszal ("kiosztva ekkor", forrás-sablon neve).
- **Statisztika:** a meglévő statistics oldal komponensei, trainer-végpontokra kötve (napi/heti/havi váltó, kalória+makró trend, súlytrend, edzésvolumen). **Víz-grafikon nincs.**
- **Lépések:** napi lépések táblázat + trend grafikon.
- **Edzések:** lapozott session-lista; session-részlet (szettek, súlyok, ismétlések) — a kiosztott sablonból végzett edzésnél "📋 {sablonnév} alapján" jelölés (a session template-hivatkozásából).
- Minden nézet **szigorúan read-only** — nincs szerkesztés-gomb, nincs create.

### 6. Kiosztott tartalmak (`/admin/assignments`)
- Táblázat: mikor, kinek, mit (típus-ikon + név), forrás; szűrés kliensre/típusra.

### 7. Super admin — Felhasználók (`/superadmin/users`)

Külön, szándékosan **minimál** felület (nem az edző admin része — saját route group, saját shell, sidebar nélkül vagy egyetlen menüponttal):

- **User-táblázat:** avatar, e-mail, név, regisztráció dátuma, **szerepkör-badge-ek** (`USER` mindenkin; `TRAINER`/`ADMIN`/`SUPER_ADMIN` ha van). E-mail keresőmező felül, lapozás alul (backend pagination).
- **Soronkénti akció:** "Edzővé tétel" gomb, ha nincs TRAINER-e; "Edző visszavonása" ha van. Mindkettő **megerősítő dialoggal** (a dialog szövege elmagyarázza a következményt — lásd `01-koncepcio-es-folyamatok.md` 5. folyamat).
- **Nem létezik** ADMIN/SUPER_ADMIN kapcsoló a UI-ban — az API sem engedi, a UI fel sem kínálja.
- A saját sor akció-gombjai rejtettek (self-módosítás tiltott).
- Sor-részlet (expand vagy drawer): a user **szerepkör-audit történet** listája (`GET …/role-audit`): mikor, ki, mit.

```
web/src/features/superadmin/
  api.ts        # /superadmin/* hívások
  hooks.ts      # useUsers(search, page), useGrantTrainer, useRevokeTrainer, useRoleAudit
  components/
    UserTable.tsx, RoleBadges.tsx, GrantTrainerDialog.tsx, RoleAuditList.tsx
```

## Navigáció (admin sidebar)

| Menüpont | Ikon | Útvonal |
|---|---|---|
| Klienseim | users | `/admin` |
| Meghívók | mail-plus | `/admin/invites` |
| Edzésterveim | dumbbell | `/admin/workouts` |
| Ételeim & receptjeim | utensils | `/admin/nutrition` |
| Kiosztott tervek | clipboard-list | `/admin/assignments` |

**Nincs**: Víz (felhasználói döntés). A Statisztika/Lépések nem globális menüpont, hanem kliens-kontextusban él (`/admin/clients/[id]/…`) — edzőként ezek az adatok csak kliensenként értelmesek.

Vissza a saját nézetbe: a top bar user-menü "Saját nézet" pontja (és a sidebar alján egy váltó-link). A user-menü teljes nézetváltó készlete szerepkör-függő: **Saját nézet** (mindenkinek) / **Edző nézet** (`ROLE_TRAINER`) / **Rendszer** (`ROLE_SUPER_ADMIN`).

## i18n

Minden új szöveg next-intl kulcs (HU/EN), a meglévő `messages/` fájlokba `admin.*` névtér alatt.
