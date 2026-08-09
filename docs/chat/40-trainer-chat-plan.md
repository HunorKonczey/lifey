# 40 – Edző ↔ kliens chat terv

> **Cél:** valós idejű, kétirányú szöveges kommunikáció az edző és a kliense között,
> olyan értesítéssel, ami akkor (és csak akkor) szól, ha a címzett **nem látta** az
> üzenetet.
>
> **Mobil (Flutter) mindkét szerepnek teljes értékű felület** — a kliens és az edző is
> mobilról chatel; a web (Next.js) az edzőnek asztali alternatíva, nem az egyetlen útja.
> Ez a döntés érdemben növeli a mobil munkát, mert a chat lesz **az első edzői felület a
> mobil appban** (ma nincs ilyen) — a következményeket a §6.1 és az I2 iteráció rögzíti.
>
> **Folytatás:** ez a terv a **v1** — a chat mindkét szerepkörnek mobilon. A ma csak
> weben elérhető többi edzői funkció mobilra vitelét a
> [41-trainer-mobile-v2-plan.md](41-trainer-mobile-v2-plan.md) tervezi meg.
>
> **Állapot (2026-08-06):** az **I1 (backend alap)**, az **I2 (mobil chat mindkét
> szerepkörben + push)**, az **I3 (edzői web)**, az **I4 (realtime)** és az
> **I5 (értesítés-finomhangolás)** kész — a chat ezzel funkcionálisan teljes.
> A leszállított szerződést és a tervtől való eltéréseket a
> **[§12 (I1)](#12-megvalósítási-napló--i1-backend-alap)**, a
> **[§13 (I2)](#13-megvalósítási-napló--i2-mobil--push)**, a
> **[§14 (I3)](#14-megvalósítási-napló--i3-edzői-web)**, a
> **[§15 (I4)](#15-megvalósítási-napló--i4-realtime-sse--jelenlét--pipák)** és a
> **[§16 (I5)](#16-megvalósítási-napló--i5-értesítés-finomhangolás)** rögzíti.
> **Az I6 mind a négy tétele kész**: üzenet-törlés
> (**[§17](#17-megvalósítási-napló--i61-üzenet-törlése)**), kép-csatolmány
> (**[§18](#18-megvalósítási-napló--i62-kép-csatolmány)**), gépelés-jelző
> (**[§19](#19-megvalósítási-napló--i63-gépelés-jelző)**) és keresés a szálban
> (**[§20](#20-megvalósítási-napló--i64-keresés-a-szálban)**).
> A törlésnél a leszállított munka valójában a törlés **átvitele a másik félhez**
> (`deleted` SSE frame) volt, mert a felület már az I2/I3-ban elkészült.
> **Az I7 (üzemeltetés és mérés) is kész**
> (**[§21](#21-megvalósítási-napló--i7-üzemeltetés-és-mérés)**) — **a terv ezzel
> végig van vezetve.** A napi üzemeltetés belépőpontja innentől nem ez a
> dokumentum, hanem a [devops/chat-operations.md](../../devops/chat-operations.md)
> runbook; a §12–§21 a *miért*-eket őrzi, a [§10](#10-design) pedig a
> design-forrásokat**
> ([42-chat-design-prompt.md](42-chat-design-prompt.md) és
> [design/Lifey Chat.dc.html](design/Lifey%20Chat.dc.html)) — minden UI-munka azokból
> dolgozik.
>
> Kapcsolódó dokumentumok: [30-push-notifications-plan.md](30-push-notifications-plan.md)
> (push infrastruktúra), [31-session-feedback-loop-plan.md](31-session-feedback-loop-plan.md)
> (edzői megjegyzés – a chat "ősváltozata"),
> [personal_trainer/03-backend-terv.md](personal_trainer/03-backend-terv.md) (edző-kliens
> kapcsolat), [15-delta-sync.md](15-delta-sync.md) (mobil szinkron),
> [web/04-frontend-architecture.md](web/04-frontend-architecture.md).

---

## 0. Jelenlegi állapot (amire építünk)

| Meglévő elem | Hol | Mit ad a chatnek |
|---|---|---|
| `TrainerClient` entitás, `ACTIVE` státusz | `backend/.../trainer/entity/TrainerClient.java` | a **jogosultsági alap**: csak aktív kapcsolatban lehet chat |
| `TrainerAccessService.requireActiveClient()` | `backend/.../trainer/service` | kész guard, újrahasznosítjuk |
| `PushService.sendToUser(userId, PushMessage)` | `backend/.../push/service` | APNs + FCM fan-out, invalid token pruning |
| `UserSettings` push-kapcsolók (`trainerCommentPushEnabled`, …) | `backend/.../settings/UserSettings.java` | minta a `chatPushEnabled` kapcsolóhoz |
| `PushTapHandler` deep-link routing | `mobile/lib/core/push/push_tap_handler.dart` | új `type=chat_message` ág ide kerül |
| Drift lokális DB + outbox | `mobile/lib/core/local_db`, `mobile/lib/core/sync` | offline üzenetküldés mintája |
| TanStack Query + Zod API réteg | `web/src/lib/api` | edzői web chat adatréteg |
| `SessionCommentServiceImpl` | `backend/.../trainer/service` | pontos minta: entitás írás → settings ellenőrzés → nyelvfüggő push |
| `GET /api/v1/trainer/clients` | `TrainerClientController` | kész kliens-lista az edzői "új beszélgetés" választóhoz |
| `decodeJwtPayload` (`roles` claim) | `mobile/lib/core/network/jwt_decoder.dart` | szerepkör-felismerés mobilon, új végpont nélkül |

Ami **nincs** meg: semmilyen üzenet-entitás, semmilyen perzisztens kapcsolat
(WebSocket/SSE), semmilyen "elolvasottság" fogalom.

És egy fontos hiányzó, ami közvetlenül a scope-ot érinti: **a mobil appban ma nulla
edzői felület van.** A `features/my_trainers` a *kliens* oldala (kinek az edzője vagyok →
nincs ilyen képernyő; kik az edzőim → van), a `ROLE_TRAINER` string nem fordul elő a
`mobile/lib` alatt sehol, a `MainShell` navigációja pedig öt fix ágra van szabva
(dashboard / nutrition / workouts / weight / statistics). Az edzői mobil chat tehát nem
"még egy képernyő", hanem **az első szerepkör-függő felület** — ennek a tervezését a
§6.1 kezeli.

---

## 1. Termékdöntések (mit építünk, mit nem)

### 1.1 Scope – v1

- **1:1 beszélgetés**, pontosan egy edző–kliens kapcsolatra. Nincs csoportos chat.
- Szöveges üzenet (max 2000 karakter), sima szöveg, nincs markdown/HTML render.
- Üzenet-állapotok a küldőnek: *küldés alatt* → *elküldve* → *kézbesítve* → *elolvasva*.
- Olvasatlan darabszám: beszélgetésenként és globálisan (tab badge).
- Push értesítés, ha a címzett nem látta; egy beszélgetésre összevont ("3 új üzenet").
- Az edző több klienssel is chatel → **beszélgetés-lista** képernyő az edzőnek,
  **mobilon és weben egyaránt**, ugyanazzal az API-val és ugyanazokkal az
  értesítési szabályokkal (a push az edzőnek is jár, nem csak a kliensnek).

### 1.2 Nem cél v1-ben

Hang-/videóhívás, csoportos szál, üzenet-reakciók, üzenet-szerkesztés, üzenet-továbbítás,
végponti titkosítás, kereső a szálban, chatbot/AI válaszjavaslat. (Kép-csatolmány és
gépelés-jelző az I6 iterációban, ha addig kell.)

### 1.3 Fontos termékszabályok

1. **A kapcsolat halálakor a szál nem tűnik el.** Ha a `TrainerClient` `REVOKED`/lejárt,
   a beszélgetés **archív** lesz: olvasható, de nem írható (`409 CONVERSATION_ARCHIVED`).
   Indok: a kliensnek joga van a saját előzményéhez; a törlés GDPR-igény, nem UI-gomb.
2. **Csak a saját üzenetét törölheti bárki**, és az is *tombstone* ("Az üzenetet törölték"),
   nem fizikai törlés — különben a másik fél kontextus nélkül maradna a saját válaszával.
3. **Az edző nem indíthat chatet nem-aktív klienssel**, és fordítva sem.
4. **Csendes órák**: a kliens beállíthat egy időintervallumot, amiben nem kap chat pusht
   (az üzenet attól még megérkezik). Alapértelmezés: nincs csendes óra.

---

## 2. Architektúra-döntés: hogyan legyen "valós idejű"?

Ez a terv legfontosabb döntése, ezért kifejtve. Négy reális opció:

| Opció | Előny | Hátrány | Új függőség? |
|---|---|---|---|
| **A. Csak polling** (pl. 10 mp) | triviális, semmi új | akkumulálódó terhelés, lassú, akkumulátor-zabáló | nincs |
| **B. SSE** (`SseEmitter`, Spring MVC beépített) | egyirányú stream pont erre való, HTTP/2-n multiplexált, auto-reconnect, proxy-barát, **nulla új dependency** | csak szerver→kliens; kliens→szerver marad REST | **nincs** |
| **C. WebSocket + STOMP** (`spring-boot-starter-websocket`) | kétirányú, "iparági alap" chatre | új starter + STOMP réteg + saját auth-handshake; a `CLAUDE.md` szerint új framework indoklást igényel; sticky session / broker-relay kell skálázáskor | igen |
| **D. Csak push (FCM/APNs data message)** | nincs kapcsolatkezelés | weben nem működik a meglévő stackkel, kézbesítés nem garantált/nem sorrendhelyes, iOS-en fojtott | nincs |

**Döntés: B + D kombináció.**

- **Küldés (kliens → szerver): sima REST `POST`.** Egy chat-üzenet küldése ritka esemény
  (nem 60 FPS játékállapot); a POST idempotens `clientMessageId`-vel, offline sorba
  állítható, hibakezelése a meglévő Dio/TanStack mintába illik. Egy WebSocket-csatorna
  ehhez nem ad semmit, viszont elveszi az offline retry egyszerűségét.
- **Fogadás előtérben (szerver → kliens): SSE.** `GET /api/v1/chat/stream` egy hosszú
  életű `text/event-stream`, ami a bejelentkezett user **összes** beszélgetésének
  eseményeit tolja (üzenet, olvasás-nyugta, gépelés). Ez Spring MVC-ben `SseEmitter` —
  nincs új starter, nincs új protokoll.
- **Fogadás háttérben: push.** Az SSE-t a mobil **nem tartja nyitva háttérben** (az OS
  úgyis megöli); amint az app háttérbe megy, a stream lezárul, és onnantól a push a
  kézbesítési csatorna. Ez egyben *pontosan* az "értesítést kap, ha nem látta" logika
  természetes megvalósítása (lásd §5).

**Skálázási seam.** A `ChatEventBus` interfész mögé kerül a szórás:

```
publish(userId, ChatEvent) → in-memory registry (v1, egy instance)
                           → később: Postgres LISTEN/NOTIFY (nulla új infra)
                           → vagy Redis pub/sub (ha úgyis lesz Redis)
```

Egy instance-nál az in-memory `Map<Long, List<SseEmitter>>` elég. **Fontos:** ha több
backend instance fut load balancer mögött, a v1 chat *működik*, csak a realtime
kézbesítés instance-lokális lesz — a fallback (push + újratöltés fókuszba kerüléskor)
elfedi. A LISTEN/NOTIFY-ra váltás izolált, egy osztálynyi munka (I4 opcionális része).

**Mikor váltanánk WebSocketre?** Ha bejön (a) kétirányú, nagy frekvenciájú forgalom
(élő edzés-követés, gépelés-jelző mindkét irányban másodpercenként), vagy (b) bináris
streaming (hang). Addig a WebSocket csak plusz komplexitás. Ezt a döntést a
`ChatEventBus` + a "küldés = REST" séma nem zárja be: a transzport cseréje nem érinti a
domain- és értesítési logikát.

---

## 3. Domain- és adatmodell

### 3.1 Táblák (V63__chat.sql)

```sql
-- Egy beszélgetés = egy edző-kliens kapcsolat. 1:1, ezért unique.
create table chat_conversations (
    id                bigserial primary key,
    trainer_client_id bigint not null references trainer_clients(id),
    trainer_id        bigint not null references users(id),
    client_id         bigint not null references users(id),
    created_at        timestamptz not null default now(),
    last_message_at   timestamptz,          -- lista rendezéshez, denormalizált
    last_message_id   bigint,               -- lista előnézethez, denormalizált
    archived_at       timestamptz,          -- kapcsolat visszavonásakor töltődik
    constraint uq_chat_conversation_link unique (trainer_client_id)
);
create index idx_chat_conv_trainer on chat_conversations (trainer_id, last_message_at desc);
create index idx_chat_conv_client  on chat_conversations (client_id,  last_message_at desc);

create table chat_messages (
    id                bigserial primary key,
    conversation_id   bigint not null references chat_conversations(id),
    sender_id         bigint not null references users(id),
    body              text not null,
    client_message_id varchar(64) not null,  -- kliens által generált UUID, idempotencia
    created_at        timestamptz not null default now(),
    deleted_at        timestamptz,
    constraint uq_chat_message_client_id unique (conversation_id, client_message_id)
);
create index idx_chat_msg_conv on chat_messages (conversation_id, id desc);

-- Résztvevőnkénti olvasottsági állapot. Nem üzenetenkénti read flag!
create table chat_participants (
    id                   bigserial primary key,
    conversation_id      bigint not null references chat_conversations(id),
    user_id              bigint not null references users(id),
    last_read_message_id bigint,             -- eddig bezárólag olvasott
    last_read_at         timestamptz,
    last_delivered_message_id bigint,
    muted_until          timestamptz,
    last_notified_at     timestamptz,        -- push összevonás ablaka (§5.3)
    constraint uq_chat_participant unique (conversation_id, user_id)
);
create index idx_chat_participant_user on chat_participants (user_id);
```

**Miért nincs üzenetenkénti `read_at`?** 1:1 szálban az olvasottság monoton: ha valaki
elolvasta a 100. üzenetet, elolvasta az összes korábbit is. Egy `last_read_message_id`
kurzor O(1) írás olvasás-nyugtánként, szemben az N sor frissítésével, és belőle az
olvasatlan szám egyetlen `count(*) where id > cursor and sender_id <> me`.

**Miért denormalizált `last_message_at`/`last_message_id`?** Az edzői beszélgetés-lista
különben N+1 lekérdezés vagy egy csúnya lateral join lenne minden listázáskor.
Egy tranzakcióban íródik az üzenettel.

### 3.2 Settings (V64__user_settings_chat_push.sql)

```sql
alter table user_settings add column chat_push_enabled boolean not null default true;
alter table user_settings add column chat_quiet_hours_start time;  -- nullable = nincs
alter table user_settings add column chat_quiet_hours_end   time;
```

A `UserSettings` entitásba három mező, a beállítás-képernyő "Értesítések" blokkjába
egy kapcsoló + egy időintervallum-választó (a meglévő `trainerCommentPushEnabled`
mintájára, lásd [30-push-notifications-plan.md](30-push-notifications-plan.md) M5).

### 3.3 Backend csomagszerkezet

Feature-alapú, a meglévő konvenció szerint — **külön `com.lifey.chat` csomag**, nem a
`trainer` alá. Indok: a chat entitásai nem edző-specifikusak (később kliens↔kliens vagy
support-szál is ráülhet), és a `trainer` csomag már így is nagy.

```
backend/src/main/java/com/lifey/chat/
├── entity/           ChatConversation, ChatMessage, ChatParticipant
├── repository/       ChatConversationRepository, ChatMessageRepository, ChatParticipantRepository
├── dto/              ConversationResponse, MessageResponse, SendMessageRequest, ReadReceiptRequest, ChatEventPayload
├── controller/       ChatConversationController, ChatMessageController, ChatStreamController
├── service/          ChatService(+Impl), ChatNotificationService(+Impl), ChatEventBus(+InMemoryChatEventBus)
├── ChatMapper.java
├── ChatProperties.java          (@ConfigurationProperties: lifey.chat.*)
└── ChatUnreadReminderJob.java   (cron, §5.4)
```

---

## 4. REST API szerződés

Minden végpont `Authorization: Bearer <access token>` mögött, `/api/v1` prefixszel.
A jogosultság **mindig** a beszélgetés résztvevőségéből következik (nem a szerepkörből):
`conversation.trainerId == me || conversation.clientId == me`, különben `404` (nem `403` —
nem szivárogtatunk létezés-információt).

**A chat végpontok `/api/v1/chat/**` alatt vannak, nem `/api/v1/trainer/**` alatt** —
ez tudatos: a `SecurityConfig` a `trainer` prefixre `hasRole("TRAINER")`-t köt, a chatet
viszont mindkét fél használja. Ennek az a gyakorlati haszna, hogy **a mobil kliens
ugyanazt az adatréteget használja mindkét szerepben** — a beszélgetés-lista lekérdezés
edzőként a klienseit, kliensként az edzőit adja vissza, ugyanazzal a hívással, szerepkör-
elágazás nélkül. Az egyetlen szerepkör-függő végpont az edzői "új beszélgetés" választóé
(`GET /api/v1/trainer/clients`, már létezik).

### 4.1 Beszélgetések

```http
GET /api/v1/chat/conversations
```
```json
{
  "items": [
    {
      "id": 12,
      "peer": { "userId": 88, "displayName": "Kiss Anna", "avatarUrl": "…", "role": "CLIENT" },
      "lastMessage": { "id": 4310, "body": "Holnap 17:00 jó?", "senderId": 7, "createdAt": "2026-08-02T09:12:44Z" },
      "unreadCount": 2,
      "archivedAt": null
    }
  ]
}
```
Rendezés: `last_message_at desc nulls last`. Lapozás: v1-ben nincs (egy edzőnek
reálisan < 100 kliense van); a válasz `items`-be van csomagolva, hogy a lapozás
később additív legyen.

```http
POST /api/v1/chat/conversations   { "trainerClientId": 55 }
```
Lazy-create: ha már van, visszaadja a meglévőt (`200`), különben létrehozza (`201`).
Csak `ACTIVE` `TrainerClient`-re. Alternatív, kényelmesebb belépő a mobilnak:
`POST /api/v1/chat/conversations/with-user/{userId}` — ez megkeresi az aktív
kapcsolatot a két user között. **Mindkettőt megvalósítjuk**, mert az edzői web a
kliens-lapról a `trainerClientId`-t ismeri, a mobil a `userId`-t.

### 4.2 Üzenetek

```http
GET /api/v1/chat/conversations/{id}/messages?before=4310&limit=30
```
**Keyset lapozás id szerint csökkenő** (nem offset — a szál folyamatosan nő, az offset
duplikálna). Válasz `id desc`, a kliens fordítva rendereli. `before` nélkül a legfrissebb
`limit` darab. `after=<id>` is támogatott: ezt használja a kliens *hézagpótlásra*, ha
SSE-szakadás után újracsatlakozik.

```json
{ "items": [ { "id": 4310, "conversationId": 12, "senderId": 7,
               "body": "Holnap 17:00 jó?", "clientMessageId": "a3f…",
               "createdAt": "2026-08-02T09:12:44Z", "deletedAt": null } ],
  "hasMore": true }
```

```http
POST /api/v1/chat/conversations/{id}/messages
{ "body": "Persze!", "clientMessageId": "9c1e…" }
```
- **Idempotens**: ha a `(conversationId, clientMessageId)` már létezik, `200`-zal a
  meglévő üzenetet adja vissza (nem `409`). Ez teszi biztonságossá az offline retryt.
- `201` + `MessageResponse` egyébként.
- Validáció: `body` nem üres, trim után ≤ 2000 karakter; `clientMessageId` ≤ 64 karakter.
- Hibák: `409 CONVERSATION_ARCHIVED`, `429 RATE_LIMITED` (§7.2), `404`.

```http
DELETE /api/v1/chat/messages/{id}      → tombstone, csak a saját üzenetre
```

### 4.3 Olvasás-nyugta és jelenlét

```http
POST /api/v1/chat/conversations/{id}/read   { "lastReadMessageId": 4310 }
```
Monoton: csak akkor ír, ha nagyobb a tárolt kurzornál (a versenyhelyzet így ártalmatlan).
Eseményt szór a másik félnek (`read` esemény → pipa-jelzés).

```http
POST /api/v1/chat/presence   { "activeConversationId": 12 | null }
```
Ez mondja meg a szervernek, hogy a user **épp nézi** azt a szálat. Ez az az információ,
amiből a "látta-e" eldől (§5). A kliens hívja: szál megnyitásakor, bezárásakor, és
app-háttérbe kerüléskor `null`-lal. A jelenlét memóriában él (`ChatPresenceRegistry`,
TTL 2 perc), nem DB-ben — elveszíthető állapot, a rosszabbik ág (küldünk pusht) ártalmatlan.

### 4.4 SSE stream

```http
GET /api/v1/chat/stream        Accept: text/event-stream
```
- A `JwtAuthenticationFilter` hitelesíti (az `Authorization` fejléc miatt a webnek
  `fetch`-alapú SSE-olvasó kell, nem a natív `EventSource` — lásd §6.2).
- Timeout: 5 perc, utána a kliens újracsatlakozik (`Last-Event-ID`-vel). Heartbeat
  `: ping` komment 20 mp-enként, hogy a proxyk ne vágják el.
- Események:

```
event: message
data: {"conversationId":12,"message":{…MessageResponse…}}

event: read
data: {"conversationId":12,"userId":88,"lastReadMessageId":4310}

event: typing           (I6)
data: {"conversationId":12,"userId":88}
```

- **Minden esemény hordoz `id:`-t** (a `chat_messages.id`, illetve read-eknél egy monoton
  szekvencia), és újracsatlakozáskor a kliens a `Last-Event-ID` alapján kap hézagpótlást.
  Ha a szerver nem tudja kiszolgálni (túl régi), `event: resync`-et küld, amire a kliens
  teljes újratöltést csinál a REST-ből. **Az SSE soha nem az igazságforrás** — csak
  gyorsítás a REST fölött.

---

## 5. Az értesítési logika (a feladat lényege)

> "Értesítést küldjön, ha a kliens nem látta az appból az üzit."

Ez négy, egymásra épülő szabály:

### 5.1 Mit jelent az, hogy "látta"?

A címzett **látta**, ha a küldés pillanatában:
- van élő SSE kapcsolata (`ChatEventBus` szerint), **és**
- a jelenléte szerint `activeConversationId == az adott beszélgetés`, **és**
- az app előtérben van (ezt a `presence` hívás implikálja: háttérbe menéskor `null`-t küld).

Ebben az esetben a szerver az üzenet mentése után **azonnal olvasottnak jelöli** a
címzettnek (kurzor-előreléptetés), eseményt szór, és **nem küld pusht**.

Minden más esetben (nincs SSE, más szálat néz, vagy háttérben van) → **push út** (§5.2).

Ez a séma szándékosan "fail-open a push felé": ha bizonytalan az állapot, inkább kap egy
felesleges értesítést, mint hogy lemaradjon egy üzenetről.

### 5.2 A push út

Az üzenet mentése **után**, a tranzakció commitját követően
(`@TransactionalEventListener(phase = AFTER_COMMIT)` — így egy push-hiba sosem rollbackeli
az üzenetet, és sosem küldünk pusht nem-létező üzenetről):

```
ChatNotificationService.onMessageStored(message):
  1. címzett = a beszélgetés másik résztvevője
  2. ha a címzett "látta" (§5.1)                → kilép
  3. ha !settings.chatPushEnabled               → kilép
  4. ha csendes órában van (user helyi idő,
     users.utc_offset_minutes alapján)          → kilép (a §5.4 reminder majd elviszi)
  5. ha participant.mutedUntil > now            → kilép
  6. ha last_notified_at > now - coalesceWindow → kilép (§5.3)
  7. PushService.sendToUser(címzett, üzenet)
     data: { type: "chat_message", conversationId, messageId }
  8. last_notified_at = now
```

A push szövege a `SessionCommentServiceImpl` mintáját követi (nyelv a
`UserSettings.language`-ből, body 120 karakteren csonkolva):

| | HU | EN |
|---|---|---|
| title | `{feladó neve}` | `{sender name}` |
| body (1 db) | `{üzenet első 120 karaktere}` | ugyanaz |
| body (több) | `{n} új üzenet` | `{n} new messages` |

Koppintás → `PushTapHandler` új ága: `type == chat_message` → chat szál megnyitása
`conversationId`-vel (a Chat tab fölé pusholva), ha a szál lokálisan még nincs meg,
akkor megnyitás + azonnali REST-töltés.

### 5.3 Összevonás (coalescing)

Egy gyorsan gépelő edző 5 üzenete ne legyen 5 push. `lifey.chat.push-coalesce-window`
(**alap: 60 mp**) ablakon belül beszélgetésenként egy push megy ki; a következő push
szövege aggregált: *"3 új üzenet"* (az olvasatlan szám a `last_read_message_id`-ből
számolódik, nem az ablakból — így mindig pontos).

A push **collapse key** (`collapse_key` FCM / `apns-collapse-id`) = `chat-{conversationId}`,
így az OS is összecsukja őket egyetlen sorrá az értesítési középen.

### 5.4 "Még mindig nem olvasta" emlékeztető

`ChatUnreadReminderJob` (cron 5 percenként, a `PasswordResetTokenCleanupJob` mintájára):

- keresi azokat a `chat_participants` sorokat, ahol van olvasatlan üzenet, ami
  **> 30 perce** érkezett, és `last_notified_at` régebbi mint az üzenet ideje
  (azaz vagy nem ment ki push, mert csendes óra volt, vagy kiment, de nem hatott),
- felhasználónként **egy** összegző pusht küld (*"2 olvasatlan üzeneted van Kiss Annától"*),
- felhasználónként **naponta max 1** ilyen emlékeztető (`ChatProperties.reminderDailyCap`),
- csendes órában nem küld, hanem eltolja az órák végére.

Ez fedi le a "kikapcsolt telefon / elnyelt push / csendes óra" eseteket anélkül, hogy
spammelnénk.

### 5.5 E-mail fallback (opcionális, I5 végén, feature flag mögött)

Ha egy üzenet **24 órán** túl olvasatlan és a usernek nincs regisztrált push eszköze
(`push_devices` üres) → egy e-mail a meglévő `MailService`-szel. Alapból **kikapcsolva**
(`lifey.chat.email-fallback-enabled=false`), mert könnyen érzékelhető spamnek; az adat
(hány ilyen eset van) a bekapcsolás előtt megnézendő a metrikákból.

---

## 6. Kliensoldali terv

### 6.1 Mobil (Flutter) — mindkét szerepkörnek

```
mobile/lib/features/chat/
├── data/
│   ├── chat_repository.dart          REST + lokális DB + outbox
│   ├── chat_stream_client.dart       SSE olvasó Dio ResponseType.stream-mel
│   └── chat_dto.dart
├── application/
│   ├── conversation_list_controller.dart
│   ├── chat_thread_controller.dart   (AsyncNotifier, keyset lapozás felfelé)
│   ├── chat_presence_controller.dart (AppLifecycleState + route figyelés)
│   ├── new_conversation_controller.dart  (edzői kliens-választó)
│   └── unread_badge_provider.dart
└── presentation/
    ├── conversation_list_screen.dart
    ├── chat_thread_screen.dart
    ├── new_conversation_sheet.dart   (csak edzőnek látszik)
    └── widgets/ (message_bubble.dart, chat_composer.dart, day_divider.dart)

mobile/lib/core/auth/current_role_provider.dart    (JWT roles claim → szerepkör)
mobile/lib/core/local_db/tables/chat_tables.dart   (chat_conversations, chat_messages)
```

#### Szerepkör-kezelés: egy felület, nem "edző mód"

Mivel a `GET /api/v1/chat/conversations` szerepkörtől függetlenül a *saját* beszélgetéseket
adja vissza, **a chat képernyők 95%-a szerepkör-agnosztikus**. Nem építünk "edző módot",
nem duplikálunk képernyőt. A szerepkör pontosan három helyen számít:

| Hol | Kliensként | Edzőként |
|---|---|---|
| Beszélgetés-lista fejléc | „Edzőim” | „Klienseim” |
| „Új beszélgetés” gomb | **nincs** (a kliens nem választ edzőt — a szál a meghívás elfogadásakor jön létre) | van → `GET /api/v1/trainer/clients` alapú választó, aki még nem szerepel a listában |
| Üres állapot szövege | „Még nincs edződ – fogadj el egy meghívót” | „Még nincs kliensed” |

A szerepkör forrása a JWT `roles` claim, amit a meglévő `decodeJwtPayload`
(`mobile/lib/core/network/jwt_decoder.dart`) már ki tud olvasni — **nincs szükség új
backend végpontra vagy profil-hívásra**. Egy `currentRolesProvider` publikálja, és a
beszélgetés-lista `isTrainer` flagje ebből származik.

**Kettős szerep.** Egy user lehet egyszerre `ROLE_USER` és `ROLE_TRAINER` (az edzőnek is
van saját edzésnaplója, és lehet saját edzője is). Ezért a lista **nem szűr szerepkörre**:
egy edzőnek, akinek van saját edzője, egy listában jelenik meg a saját edzője és az összes
kliense. A `ConversationResponse.peer.role` mező (`TRAINER` / `CLIENT`) alapján a sorra
kerül egy diszkrét címke, hogy a két típus megkülönböztethető legyen. Ez a legegyszerűbb
megoldás, ami nem hazudik: nincs mód-váltó kapcsoló, nincs kétféle lista.

#### Belépési pont a navigációban

Ez a terv egyetlen invazív mobil döntése, ezért kifejtve. A `MainShell`
(`mobile/lib/shared/widgets/main_shell.dart`) **öt fix ágra** van szabva
(`StatefulShellBranch` × 5), a `ShellFab` és a `NavCollapseController` is a tabindexekre
épül. Három lehetőség:

1. **Hatodik nav-ág a chatnek** → az öt ikon már most sűrű; hatodik ikonnal a
   `AdaptiveBottomNav` elrendezése és a FAB-pozicionálás is újratervezendő. Nagy
   kockázat egy nem-mindenkinek-releváns funkcióért. **Elvetve.**
2. **Szerepkör-függő nav** (edzőnek más tabsor) → a `StatefulNavigationShell` ágait
   futásidőben cserélni GoRouterben törékeny (az ágak state-je a router konfigurációhoz
   kötött), és a kettős szerep miatt amúgy sem egyértelmű, mit mutassunk. **Elvetve.**
3. **Shell fölé pusholt önálló útvonal + ikon a fejlécben** → `/chat` és
   `/chat/:conversationId` top-level `GoRoute`-ként, pontosan úgy, ahogy a `/settings`
   és a `/recap` már ma is a shellen kívül él. A belépő egy **olvasatlan-badge-es
   chat ikon a dashboard app barjában**, mindkét szerepkörnek. **Ezt választjuk.**

További, kontextusból induló belépési pontok (mind ugyanarra a `/chat/:id` útvonalra
navigálnak, tehát nulla plusz UI-munka):
- kliensnek: „Edzőim” lista sorából (`features/my_trainers`) egy „Üzenet” gomb,
- edzőnek: az edzői kliens-lista hiánya miatt v1-ben **a beszélgetés-lista maga az edzői
  kliens-felület** — ez szándékos, lásd §9 „scope-csúszás” kockázat,
- push koppintás (`PushTapHandler`, `type == chat_message`) → `/chat/:conversationId`.

Az olvasatlan badge egyetlen `unreadBadgeProvider`-ből jön (a beszélgetés-lista
`unreadCount` összegéből), és a dashboard ikonon jelenik meg — a bottom nav érintetlen
marad.

**Lokális tárolás – döntés: külön táblák, a generikus `SyncEngine`-en kívül.**
A `PullEngine`/`OutboxWriter` full-pull + `updated_at`-alapú delta modellje rossz illesztés
a chatre: az üzenetek immutábilisak, kurzoros lapozásúak, kívülről (SSE/push) is
beérkeznek, és a "szál elejére vissza" scroll nem fér bele a "húzzunk le mindent" logikába.
Ehelyett:

- `chat_messages` drift tábla `syncState` oszloppal: `pending` | `sent` | `failed`.
- Küldés: **optimista** — a buborék azonnal megjelenik `pending`-ként, saját generált
  `clientMessageId`-vel; sikeres POST után a szerver `id`-jával frissül `sent`-re. Hiba
  esetén `failed` + "Újraküldés" gomb; az idempotens POST miatt a retry biztonságos.
- Kapcsolat visszatérésekor (`connectivityStatusProvider`, már létezik) a `pending` sorok
  automatikusan újraküldődnek, keletkezési sorrendben.
- Ez a `chat_messages` tábla **nem** kerül be az `entity_sync_config.dart`-ba.

**Életciklus és stream:**

| Esemény | Teendő |
|---|---|
| app előtérbe jön | SSE csatlakozás + `after=<utolsó lokális id>` hézagpótlás minden nyitott szálra |
| szál megnyitása | `presence(activeConversationId)`, `read` nyugta a legutolsó üzenetre |
| szál görgetése aljára | `read` nyugta (debounce 500 ms) |
| app háttérbe megy | `presence(null)`, SSE lezárás |
| push érkezik | csak lokális értesítés + badge; a tartalom a következő megnyitáskor töltődik |

Ezek a szabályok **szerepkörtől függetlenek**: az edző mobilja pontosan ugyanígy jelez
jelenlétet és kap (vagy nem kap) pusht, mint a kliensé. Egy edzőnél viszont a
beszélgetés-lista hosszabb, ezért a lista-képernyő az SSE `message` eseményre **nem tölt
újra listát**, csak az érintett sort mozgatja előre és lépteti az olvasatlan számlálót.

### 6.2 Web (Next.js, edzői felület)

A web az edzőnek **asztali alternatíva**, nem az elsődleges útja (a mobil az, lásd §6.1).
Ebből következik, hogy a webnek nem kell semmi olyat tudnia, amit a mobil nem: ugyanaz az
API, ugyanaz a modell, csak nagyobb képernyőre szabott elrendezés.

```
web/src/features/chat/            api.ts (Zod sémák), hooks.ts (TanStack Query), components/
web/src/app/(app)/chat/           page.tsx (lista + szál, két hasábos desktop layout)
web/src/lib/api/chat-stream.ts    fetch-alapú SSE olvasó
```

**Fontos technikai részlet: a natív `EventSource` nem tud `Authorization` fejlécet.**
Három lehetőség, ebből választunk:

1. token query paramban → **elvetve**: token kerülne URL-be (log, referer, history).
2. rövid életű "stream ticket" végpont → működik, de plusz végpont + plusz állapot.
3. **`fetch` + `ReadableStream` + saját SSE-parser** → fejlécezhető, `AbortController`-rel
   szabályosan zárható, ~60 sor. **Ezt választjuk.** Az újracsatlakozási backoff
   (1s → 2s → 5s → 15s, jitterrel) és a `Last-Event-ID` kezelése kézzel, ugyanabban a
   helperben.

A beérkező `message` esemény a TanStack Query cache-be íródik
(`queryClient.setQueryData(['chat','messages',conversationId], …)`), nem invalidálást
triggerel — így nincs fölösleges refetch minden üzenetnél. A conversation-lista viszont
invalidálódik (rendezés + unread változik).

**Web push:** a webes edzőnek v1-ben **nincs** push, csak in-app (böngésző-fül) jelzés:
cím-badge (`document.title` = `(3) Lifey`) és hangjelzés opcionálisan. A Web Push
(VAPID + service worker) külön, későbbi feladat — nem blokkolja a chatet.

---

## 7. Biztonság, visszaélés-védelem, adatvédelem

1. **Jogosultság minden végponton a résztvevőségből**, nem szerepkörből. Nem-résztvevőnek
   `404`. Külön integrációs teszt: idegen user nem éri el a szálat sem olvasásra,
   sem írásra, sem SSE-n.
2. **Rate limit**: userenként 30 üzenet / perc és 600 / nap (`ChatProperties`), in-memory
   token bucket (`Caffeine`-mentes, egyszerű `ConcurrentHashMap` + ablak). Túllépés: `429`.
   Egy instance-on ez elég; a limit itt visszaélés-védelem, nem elszámolás.
3. **Tartalom**: a `body` sima szövegként tárolódik és **sima szövegként renderelődik**
   mindkét kliensen (Flutter `Text`, React JSX szöveg-gyerek — nincs `dangerouslySetInnerHTML`).
   A linkeket a kliens ismeri fel és teszi kattinthatóvá (nem a szerver).
4. **Naplózás**: az üzenet **tartalma soha nem kerül logba** (csak `conversationId`,
   `messageId`, `senderId`). Ez a code review checklist tétele.
5. **GDPR / törlés**: user törlésekor az üzenetei anonimizálódnak (`sender_id` marad,
   de a user sor törlésével a név feloldhatatlan) — a beszélgetés a másik fél
   szempontjából olvasható marad. Az adatexportba a chat bekerül (ha van ilyen folyamat;
   ha nincs, ez a jövőbeli export scope-jának tétele).
6. **Az archív szál** (visszavont kapcsolat) olvasható marad mindkét félnek; új üzenet
   `409`. A `ScheduleCancellationListener` / `TrainerClientRevokedEvent` mintájára egy
   `ChatArchiveListener` állítja be az `archived_at`-et.

---

## 8. Iterációk

Minden iteráció **önmagában szállítható és tesztelhető**. Az iteráció végén a
`main`-be mergelhető állapot áll elő; a felhasználó felé a chat a
`lifey.chat.enabled` flag (backend) + egy klienses feature flag mögött van az **I2 végéig**.
Az I2 után a chat éles funkció mindkét szerepkörnek mobilon; az I3–I5 már élő funkciót
bővít, ezért mindegyik önállóan is halasztható a mögötte lévő igény szerint.

---

### I1 – Backend alap (domain + REST) · ~3 nap · ✅ KÉSZ

> **Állapot:** megvalósítva a `feature/chat-functionality` ágon. A tényleges
> szerződés-eltéréseket és a következő lépés belépőpontját a §12 „Megvalósítási napló”
> rögzíti — **az I2 azzal a szakasszal kezdődik, nem ezzel.**

**Cél:** működő, tesztelt chat API realtime nélkül. Postmannel végigjátszható egy
teljes beszélgetés.

Feladatok:
- `V63__chat.sql`, `V64__user_settings_chat_push.sql` migrációk.
- `com.lifey.chat` csomag: entitások, repositoryk, `ChatMapper`, DTO-k.
- `ChatServiceImpl`: `getConversations`, `openConversation`, `listMessages` (keyset),
  `sendMessage` (idempotens), `markRead`, `deleteMessage`.
- `ChatConversationController`, `ChatMessageController` a §4.1–4.3 szerződéssel.
- `TrainerAccessService` újrahasznosítás + résztvevőség-guard.
- `ChatProperties` (`lifey.chat.enabled`, `max-body-length`, rate limit értékek).
- `ChatArchiveListener` a `TrainerClientRevokedEvent`-re.
- Postman kollekció kiegészítés (`docs/postman`).

Tesztek:
- unit: idempotencia (ugyanaz a `clientMessageId` kétszer → egy sor), keyset lapozás
  határesetei, `markRead` monotonitása, archív szálra írás → `409`.
- integrációs (Testcontainers): teljes szál két user között, idegen user `404`-et kap
  minden végponton, unread szám helyessége.

**Kész, ha:** a Postman folyamat végigmegy, a tesztek zöldek, a migráció visszafelé is
konzisztens (`flyway:info` tiszta).

---

### I2 – Mobil chat mindkét szerepkörben + push értesítés · ~6 nap · ✅ KÉSZ

> **Állapot:** megvalósítva a `feature/chat-functionality` ágon. Az eltéréseket, a
> leszállított felületet és az I3/I4 belépőpontját a §13 rögzíti.

> **Belépőpont:** az I1 kész (§12), az API él. Mielőtt bármelyik képernyő elkezdődne,
> **a §10 két design-forrását kell elolvasni** — a `42-chat-design-prompt.md` briefjét és
> a `design/Lifey Chat.dc.html` vizuális tervet. A §6.1 alatti fájllista a *hol*, a
> design a *hogyan néz ki*; a kettő együtt a feladat. Az API tényleges alakját (mezőnevek,
> státuszkódok) a §12 tábláiból kell venni, nem a §4 vázlatából.

**Cél:** a kliens **és az edző** mobilon tud írni egymásnak, és **push jön, ha nem
látta**. Realtime még nincs — a szál megnyitása és az előtérbe kerülés tölt.

> Ez a terv legnagyobb egybefüggő darabja, mert itt születik meg az **első edzői felület
> a mobil appban** (§6.1). A képernyők közösek, a szerepkör csak három ponton ágazik el —
> de az útvonal-, badge- és jogosultság-infrastruktúra újonnan épül.

**a) Közös mag (mindkét szerep) — a munka ~70%-a**
- drift táblák + migráció (`chat_conversations`, `chat_messages` `syncState`-tel).
- `ChatRepository`: REST + lokális cache + optimista küldés (`pending`/`sent`/`failed`),
  keyset lapozás felfelé, kapcsolat-visszatéréskori automatikus újraküldés.
- `conversation_list_screen.dart`, `chat_thread_screen.dart`, `message_bubble.dart`,
  `chat_composer.dart`, `day_divider.dart` a design rendszer primitíveivel (§10).
- `/chat` és `/chat/:conversationId` top-level `GoRoute` a shellen kívül
  (`app_router.dart`), a `/settings` mintájára.
- `unreadBadgeProvider` + badge-es chat ikon a dashboard app barjában.
- `PushTapHandler`: `type == chat_message` ág → `/chat/:conversationId`.
- `l10n`: `app_hu.arb` / `app_en.arb` kulcsok (mindkét szerep szövegei).

**b) Szerepkör-kezelés — új infrastruktúra**
- `currentRolesProvider` a JWT `roles` claimből (`decodeJwtPayload` újrahasznosítás).
- A lista fejléce, üres állapota és az „Új beszélgetés” gomb láthatósága ebből.
- Kettős szerep (`ROLE_USER` + `ROLE_TRAINER`) kezelése: egy vegyes lista, `peer.role`
  címkével — lásd §6.1.

**c) Csak edzőnek**
- `new_conversation_sheet.dart`: `GET /api/v1/trainer/clients` alapú kereshető
  kliens-választó, azokra szűrve, akikkel még nincs szál; kiválasztás →
  `POST /chat/conversations/with-user/{userId}` → egyenesen a szálba navigál.
- A hosszabb listához: lista-sor előretolás SSE/refresh nélkül is helyes rendezéssel.

**d) Csak kliensnek**
- „Üzenet” gomb az „Edzőim” lista sorában (`features/my_trainers`).

**e) Backend**
- `ChatNotificationService` §5.2 szerint (jelenlét nélkül, egyelőre: **mindig push**,
  ha az üzenet olvasatlan és a settings engedi) — **mindkét irányban**, az edző is kap.
- `@TransactionalEventListener(AFTER_COMMIT)` bekötés.
- `chatPushEnabled` a settings API-ban + a mobil beállítás-képernyőn.

Tesztek:
- mobil widget: pending buborék → sikeres küldés → sent; hiba → failed + retry;
  a lista fejléce/gombja helyes edzőként, kliensként és **kettős szerepben**.
- mobil unit: repository idempotens újraküldés, keyset összefűzés hézag nélkül,
  `currentRolesProvider` a `roles` claim variánsaira.
- backend unit: push kihagyása kikapcsolt kapcsolónál, nyelvfüggő szöveg, edző→kliens
  és kliens→edző irány is.
- kézi: **három** eszköz/fiók (kliens, edző, kettős szerepű user), app bezárva → push
  érkezik, koppintás a helyes szálat nyitja.

**Kész, ha:** egy edzői és egy kliens fiók között végigmegy a küldés-fogadás-push-
koppintás kör **mindkét irányban**, az edző mobilról indít új beszélgetést egy addig
néma klienssel, és a repülő módban írt üzenet visszatéréskor magától kimegy.

---

### I3 – Edzői web felület · ~3 nap · ✅ KÉSZ

> **Állapot:** megvalósítva a `feature/chat-functionality` ágon. Az eltéréseket, a
> leszállított felületet és az I4 belépőpontját a §14 rögzíti.

**Cél:** az edző böngészőből is chatel — asztali alternatíva a mobil mellé (nem
helyettesíti, az I2 után az edző már teljesen elvan mobilról). Ez az iteráció ezért
**halasztható**, ha az I2 csúszik: nem blokkol semmit.

> A web edzői nézet elrendezését a §10 design-forrásai („web edző” blokk) írják le —
> ugyanaz a token-készlet, más renderelés. Ne tervezz új web-layoutot ehhez.

Feladatok:
- `web/src/features/chat`: Zod sémák, TanStack Query hookok, mutációk optimista update-tel.
- `/chat` oldal: bal hasáb beszélgetés-lista (keresővel), jobb hasáb szál.
- Belépés a kliens-részletező lapról ("Üzenet" gomb).
- Olvasatlan jelzés a fő navigációban + `document.title` badge.
- `hu.json` / `en.json` kulcsok, üres/skeleton/hiba állapotok (a web brief §2.9 szerint).
- Vitest a sémákra/hookokra, Playwright egy fő flow-ra (megnyit → küld → megjelenik).

**Kész, ha:** az edző weben, a kliens mobilon lefolytat egy beszélgetést (frissítés
gombbal / lapváltással, realtime még nincs).

---

### I4 – Realtime (SSE) + jelenlét + kézbesítési állapotok · ~4 nap · ✅ KÉSZ

> **Állapot:** megvalósítva a `feature/chat-functionality` ágon. Az eltéréseket, a
> leszállított szerződést és az I5 belépőpontját a §15 rögzíti.

**Cél:** az üzenet másodperceken belül megjelenik a másik oldalon; az olvasottság látszik.

Feladatok (backend):
- `ChatEventBus` interfész + `InMemoryChatEventBus` (`Map<Long, Set<SseEmitter>>`,
  szabályos `onCompletion`/`onTimeout`/`onError` takarítással).
- `ChatStreamController` (`SseEmitter`, heartbeat scheduler, `Last-Event-ID` hézagpótlás,
  `resync` esemény).
- `ChatPresenceRegistry` + `POST /chat/presence`; a §5.1 "látta" szabály bekötése a
  `ChatNotificationService`-be (innentől nincs push, ha nézi a szálat).
- `read` esemény szórása, `last_delivered_message_id` karbantartás.
- Terhelési sanity: 200 párhuzamos emitter memória-lábnyoma (kézi mérés, jegyzőkönyv).

Feladatok (kliens):
- mobil `ChatStreamClient` (Dio stream, backoff újracsatlakozás, app-életciklus kötés).
- web `chat-stream.ts` (fetch + ReadableStream parser, backoff, cache-írás).
- Pipa-jelzések a buborékokon (elküldve / kézbesítve / olvasva).

Tesztek:
- backend: emitter regisztráció/leiratkozás, hogy nincs szivárgás; hézagpótlás
  `Last-Event-ID`-vel; jelenlét-alapú push-kihagyás.
- kézi: hálózat elvétele-visszaadása közben nincs elveszett és nincs duplikált üzenet.

**Kész, ha:** két eszköz között < 2 mp a látszólagos kézbesítés, és a szálat néző félnek
**nem** jön push.

---

### I5 – Értesítés-finomhangolás · ~2 nap · ✅ KÉSZ

> **Állapot:** megvalósítva a `feature/chat-functionality` ágon. Az eltéréseket és a
> leszállított szerződést a §16 rögzíti.

Feladatok:
- Push összevonás (`push-coalesce-window`, collapse key, "N új üzenet" szöveg) — §5.3.
- `ChatUnreadReminderJob` — §5.4.
- Csendes órák (`chat_quiet_hours_*`) + a `users.utc_offset_minutes` alapú helyi idő
  számítás (a `WorkoutReminderJob` mintájára).
- Beszélgetés némítása (`muted_until`) a szál menüjéből.
- Beállítás-képernyő bővítés mobilon és weben.
- E-mail fallback flag mögött (alapból ki) — §5.5.

Tesztek: időzóna-határesetek (éjfélen átnyúló csendes óra), reminder napi cap,
összevonási ablak.

**Kész, ha:** 5 gyors üzenet = 1 push; olvasatlan üzenet 30 perc után egyszer emlékeztet;
csendes órában néma.

---

### I6 – Kiterjesztések (opcionális, igény szerint) · ~3 nap · ✅ KÉSZ

> **Állapot:** mind a négy tétel megvan — **üzenet törlése** (§17),
> **kép-csatolmány** (§18), **gépelés-jelző** (§19), **keresés a szálban** (§20).
> A tételek egymástól függetlenül készültek, ahogy a terv szánta őket.

- ~~**Kép-csatolmány**: a meglévő kép-pipeline (`common/image`, `Thumbnailator`,
  profilkép/recept minta) újrahasznosítása; `chat_messages.attachment_url` + `type`
  oszlop, kliensoldali feltöltés-progressz.~~ ✅ **kész — §18**
- ~~**Gépelés-jelző**: `POST /chat/typing` (throttle 3 mp) → `typing` SSE esemény, 5 mp TTL.
  Sose vált ki pusht.~~ ✅ **kész — §19**
- ~~**Üzenet törlése** UI-ból (a backend már tudja I1 óta).~~ ✅ **kész — §17**
- ~~**Keresés a szálban** (`ILIKE` + trigram index, ha kell).~~ ✅ **kész — §20**

### I7 – Üzemeltetés és mérés · ~1 nap · ✅ KÉSZ

> **Állapot:** megvalósítva, a részleteket a §21 rögzíti. A `PostgresChatEventBus`
> szándékosan **nem** készült el — a terv feltételhez kötötte („ha addig
> többinstance-os lesz a backend"), és a deploy egyinstance-os (§21.2).

- Metrikák (Actuator/Micrometer, már be van húzva): elküldött üzenetek, aktív SSE
  kapcsolatok, push kiküldés/kihagyás arány kihagyási okonként, reminder-találatok.
- Riasztás-küszöbök: SSE emitter szám elszállása (szivárgás-jelző), push hibaarány.
- `docs/devops` kiegészítés: mit kell tudni a chatről egy incidensnél
  (hogyan kapcsolható ki: `lifey.chat.enabled=false` → a kliensek olvasnak, de nem írnak).
- Ha addig többinstance-os lesz a backend: `PostgresChatEventBus` (LISTEN/NOTIFY).

---

## 9. Kockázatok és mérséklésük

| Kockázat | Hatás | Mérséklés |
|---|---|---|
| Több backend instance esetén az in-memory event bus instance-lokális | egyes üzenetek csak push/refresh után látszanak | dokumentált seam (`ChatEventBus`), LISTEN/NOTIFY implementáció I7-ben; addig egy instance |
| SSE emitter szivárgás (nem zárt kapcsolatok) | memória-növekedés, végül OOM | `onTimeout`/`onError`/`onCompletion` mindhárom takarít; metrika + riasztás; 5 perces kényszerített timeout |
| Reverse proxy pufferolja az SSE-t | "realtime" nem realtime | `X-Accel-Buffering: no` fejléc, heartbeat, deploy után kézi ellenőrzés |
| Push spam → a user kikapcsolja az összes értesítést | elveszítjük a többi értesítési csatornát is | összevonás + reminder-cap + csendes órák (I5) **még a széles bevezetés előtt** |
| iOS-en a háttér-push fojtása | késői értesítés | `apns-priority: 10` alert push (nem silent), collapse id; a reminder job mint biztonsági háló |
| A chat elviszi az edző-kliens kommunikációt az edzésnaplóból | a strukturált visszajelzés (31-es terv) elsorvad | a szálban az edzés-megjegyzés rendszer-üzenetként megjelenhet, linkkel a session-re (I6 jelölt) |
| **Scope-csúszás: a chat az első edzői mobil felület** → azonnal jön az igény a többire (kliens-lista, program-hozzárendelés, naptár mobilon) | az I2 felduzzad, a chat nem szállít | az I2 **kizárólag** chatet szállít; az edzői „kliens-felület” v1-ben maga a beszélgetés-lista. A többi edzői mobil képernyő a **v2** tárgya: [41-trainer-mobile-v2-plan.md](41-trainer-mobile-v2-plan.md) — az igény tehát nincs elutasítva, csak ütemezve |
| A `/chat` shellen kívüli útvonal miatt a chatből nincs alsó navigáció | „hogy megyek vissza” érzet | a szál és a lista is teljes értékű vissza-navigációval (`AppBar` back), a lista a dashboardra tér vissza — ugyanaz a minta, mint a `/settings`-nél, ami már bevált |
| Kettős szerepű user (edző, akinek van saját edzője) | zavaros lista, rossz jogosultság-feltételezés | egy vegyes lista `peer.role` címkével (§6.1); külön teszteset az I2-ben |
| Idempotencia hiánya offline retrynél | duplikált üzenetek | `clientMessageId` unique constraint már I1-ben, nem utólag |

---

## 10. Design

> ### ⚠️ A design forrása a további lépésekhez
>
> **Minden UI-t érintő iteráció (I2, I3, I5 beállítás-képernyők, I6) kötelezően ebből a
> két forrásból dolgozik:**
>
> 1. **[42-chat-design-prompt.md](42-chat-design-prompt.md)** — a chat design briefje:
>    képernyőnkénti anatómia (beszélgetés-lista, szál, buborék, composer, állapotok,
>    edzői „új beszélgetés” választó, push-előnézet), mobil kliens / mobil edző / web
>    edző nézetben. **Ez az elsődleges forrás**, a §2 döntés-naplója köti a designt
>    ehhez a tervhez.
> 2. **[design/Lifey Chat.dc.html](design/Lifey%20Chat.dc.html)** — a prompt alapján
>    elkészült, megnyitható vizuális terv. Ha a kettő eltér, a `.dc.html` a friss:
>    az a leszállított design, a prompt a hozzá tartozó szándék.
>
> Az edzői mobil felület szélesebb kontextusához (v2, chaten túli képernyők):
> [43-trainer-mobile-v2-design-prompt.md](43-trainer-mobile-v2-design-prompt.md) +
> [design/Lifey Trainer Mobile.dc.html](design/Lifey%20Trainer%20Mobile.dc.html).
>
> Gyakorlati szabály: **UI-kód írása előtt a fenti fájlokat kell elolvasni**, nem ezt a
> §-t vagy a §6-ot — a terv a viselkedést rögzíti, a design a megjelenést. Ha
> fejlesztés közben derül ki, hogy a design és a terv ütközik, a döntést **itt és a
> prompt §2-jében is** át kell vezetni, nem elég a kódban feloldani.

A képernyők (beszélgetés-lista **kliens- és edzőnézetben**, szál, composer, edzői
„új beszélgetés” választó, állapotok, push-előnézet) design promptja elkészült:
**[42-chat-design-prompt.md](42-chat-design-prompt.md)** — mobil kliens, mobil edző és
web edző felületre egyben, a 11-es/13-as prompt-dokumentumok szerkezetét követve.
A prompt §2 döntés-naplója ennek a tervnek a designt kötő döntéseit tartalmazza; ha itt
valami változik, ott is át kell vezetni.

Az **I1 (backend) szándékosan nem érinti a designt** — az API-szerződés (§4) az egyetlen
felület, amit szállít. A design innentől az I2 belépőpontja.

---

## 11. Nyitott kérdések

1. ~~Kell-e az edzőnek mobilon is teljes chat?~~ **Eldöntve: igen.** A mobil mindkét
   szerepnek teljes felület (I2), a web asztali alternatíva (I3, halasztható). Az ebből
   fakadó nyitott alkérdés: **kap-e az edző külön push-kapcsolót?** Javaslat: nem, a
   `chatPushEnabled` szerepkör-független — egy kapcsoló, egy mentális modell. Ha az
   edzőknek később mégis külön kell (pl. „csak munkaidőben”), arra a csendes órák (I5)
   már most is jó választ adnak.
2. **Legyen-e "rendszerüzenet" a szálban** (pl. "Az edződ új programot rendelt hozzád")?
   Olcsó (`type=SYSTEM` üzenet), és a szálat élővé teszi — de eldöntendő, hogy nem
   redundáns-e a meglévő pushokkal.
3. **Web push** (VAPID + service worker) mikor kell? Ha az edző böngészőben ül egész nap,
   a fül-badge elég lehet.
4. **Megőrzési idő**: tartsunk-e mindent örökre? Javaslat: igen v1-ben, mert az adatmennyiség
   elhanyagolható, és a törlési igény manuális folyamatként kezelhető.
5. **Peer avatar a chatben.** A profilkép ma csak a saját fiókra kérhető le
   (`GET /api/v1/users/me/avatar`) — nincs végpont *más* user képére, ezért a
   `ConversationResponse.peer` **nem tartalmaz `avatarUrl`-t** (§12). A design monogram-
   avatart használ, tehát ez ma nem blokkol semmit. Ha később kell a valódi kép, az egy
   önálló, résztvevőség-ellenőrzött végpont (`GET /api/v1/chat/conversations/{id}/peer/avatar`),
   nem a chat DTO bővítése — a jogosultság a szálhoz kötődik, nem a user-id-hez.

---

## 12. Megvalósítási napló — I1 (backend alap)

> **Ez a szakasz a következő lépések kiindulópontja.** Az I2/I3/I4 kliensmunka a
> **ténylegesen leszállított** szerződésből dolgozzon, nem a §4 tervvázlatából: ahol a
> kettő eltér, az alábbi táblák az igazak. A megjelenéshez pedig a **§10 design-forrásai**
> a kötelező bemenet.

### 12.1 Mi készült el

| Réteg | Fájlok |
|---|---|
| Migrációk | `V64__chat.sql`, `V65__user_settings_chat_push.sql` |
| Entitások | `com.lifey.chat.entity`: `ChatConversation`, `ChatMessage`, `ChatParticipant` |
| Repositoryk | `com.lifey.chat.repository`: `ChatConversationRepository`, `ChatMessageRepository` (+`ConversationUnreadCount` projekció), `ChatParticipantRepository` |
| DTO-k | `com.lifey.chat.dto`: `ConversationListResponse`, `ConversationResponse`, `ChatPeerResponse`, `ChatPeerRole`, `MessageListResponse`, `MessageResponse`, `SendMessageRequest`, `ReadReceiptRequest`, `OpenConversationRequest` |
| Szolgáltatás | `ChatService`/`ChatServiceImpl`, `ChatRateLimiter`, `OpenConversationResult`, `SendMessageResult` |
| Controllerek | `ChatConversationController`, `ChatMessageController` |
| Egyéb | `ChatMapper`, `ChatProperties`+`ChatConfig`, `ChatArchiveListener`, 4 kivétel + `GlobalExceptionHandler` ágak, `UserSettings` 3 új mező |
| Tesztek | `ChatServiceImplTest` (22), `ChatRateLimiterTest` (3), `ChatConversationControllerTest` (7), `ChatMessageControllerTest` (7), `ChatArchiveListenerTest` (2), `ChatFlowIntegrationTest` (14, Testcontainers) |
| Postman | `docs/postman` → új **Chat** mappa (9 kérés) + `conversationId`/`chatMessageId` változó |

A teljes backend suite zöld (703 teszt).

### 12.2 Eltérések a tervtől — ezekkel kell dolgozni

| Terv | Valóság | Miért |
|---|---|---|
| `V63__chat.sql`, `V64__user_settings_chat_push.sql` | **`V64__chat.sql`, `V65__user_settings_chat_push.sql`** | a V63-at időközben elvitte a `workout_session_exercise_target_sets` |
| `peer.avatarUrl` | **nincs**; helyette `peer.displayName` (név, hiányában e-mail) + `peer.email` | nincs cross-user avatar végpont (§11/5); a design monogramot használ |
| `lastMessage` szűkített előnézet-objektum | **teljes `MessageResponse`** | a kliens így egyetlen üzenet-alakot parse-ol mindenhol; additív, nem szűkítő |
| `chat_messages.body` `not null` | **nullable**, `check (deleted_at is not null or body is not null)` | a tombstone valóban törli a szöveget, nem csak elrejti; a kliens a saját lokalizált szövegét rendereli |
| `POST /messages` hibái: 409 / 429 / 404 | **+ 400** (üres vagy `max-body-length` fölötti body), **+ 503** (`lifey.chat.enabled=false`) | a kill switch nem kliens-hiba, ezért nem 4xx |
| — | `GET .../messages?limit=` felső határa **100** (`lifey.chat.max-page-size`), alap 30 | |
| — | `POST /read` **klampol** a szál legutolsó üzenet-id-jére | offline kliens előreszaladása normális, nem hiba |

### 12.3 Amit az I1 tudatosan nem szállít

`GET /chat/stream` (SSE), `POST /chat/presence`, gépelés-jelző, **push értesítés**,
`chatPushEnabled` a Settings API-ban, csendes órák logika. A `chat_participants`
`muted_until` / `last_notified_at` / `last_delivered_message_id` oszlopai és a
`user_settings.chat_*` mezők **léteznek, de még senki nem írja őket** — az I2 (push) és
az I5 (összevonás, csendes órák) tölti fel őket.

### 12.4 Amire a kliensoldalnak figyelnie kell

- **Idempotencia**: minden üzenethez egy `clientMessageId` (UUID), és **újraküldéskor
  ugyanaz** — a szerver ilyenkor 200-zal a már tárolt üzenetet adja vissza 201 helyett.
  Ez a §6.1 optimista outboxának a feltétele.
- **A saját üzenet sosem olvasatlan**: küldéskor a szerver előre lépteti a küldő
  kurzorát, tehát az `unreadCount` a listában nem ugrik meg a saját üzenettől.
- **A `peer.role` szerepkör-relatív**, nem globális: kettős szerepű usernél ugyanabban a
  listában lesz `TRAINER` és `CLIENT` címkéjű sor is (§6.1).
- **Egy párhoz több szál is tartozhat**: visszavonás után újra meghívott kliens **új**
  `trainer_clients` sort, tehát **új beszélgetést** kap; a régi archívként megmarad. A
  lista tehát mutathat két sort ugyanazzal a névvel, ahol az egyik `archivedAt != null`.
  A designnak (és az I2 lista-képernyőnek) ezt kezelnie kell.
- **404, nem 403**: nem-résztvevő minden végponton 404-et kap. A kliens ne
  „nincs jogosultságod” hibát mutasson erre, hanem „a beszélgetés nem érhető el”.

---

## 13. Megvalósítási napló — I2 (mobil + push)

> **Az I3 (edzői web) és az I4 (realtime) innen indul.** Az I3 ugyanazt az API-t
> fogyasztja, amit a mobil már használ; az I4 az itt leírt „mi hiányzik még” listát
> tölti fel. A megjelenéshez továbbra is a **§10 design-forrásai** a kötelező bemenet.

### 13.1 Mi készült el

**Mobil (Flutter)**

| Réteg | Fájlok |
|---|---|
| Lokális DB | `core/local_db/tables/chat_tables.dart` (`chat_conversations`, `chat_messages`), séma **v29** migráció + `user_settings.chat_push_enabled` |
| Domain | `features/chat/domain/`: `ChatConversation`, `ChatMessage` (+`ChatMessageState`), `ChatPeer` (+`ChatPeerRole`), `TrainerClientOption` |
| Data | `chat_repository.dart` (REST + lokális cache + optimista küldés + saját outbox), `trainer_clients_repository.dart` |
| Application | `conversation_list_controller.dart` (+`unreadBadgeProvider`), `chat_thread_controller.dart` (+`chatConversationProvider`), `new_conversation_controller.dart`, `core/auth/current_roles_provider.dart` |
| Presentation | `conversation_list_screen.dart`, `chat_thread_screen.dart`, `new_conversation_sheet.dart`, `widgets/`: `conversation_tile`, `message_bubble`, `chat_composer` (+`ArchivedComposerNotice`), `day_divider`, `chat_avatar` |
| Beépülés | `/chat` és `/chat/:conversationId` a shellen kívül (`app_router.dart`), badge-es chat ikon a dashboard app barban, `PushTapHandler` `chat_message` ág, „Üzenet” akció az „Edzőim” soron, `chatPushEnabled` kapcsoló az értesítés-beállításokon |
| l10n | 40 új kulcs `app_en.arb` / `app_hu.arb` (mindkét szerep szövegei) |

**Backend**

| Elem | Fájl |
|---|---|
| Push pipeline | `ChatMessageStoredEvent`, `ChatNotificationService`/`Impl` (`@TransactionalEventListener(AFTER_COMMIT)` + `REQUIRES_NEW`) |
| Settings API | `chatPushEnabled` a `SettingsRequest`/`SettingsResponse`/`SettingsMapper`-ben |
| Kliens-választó adat | `TrainerClientResponse` + `clientFirstName` / `clientLastName` |

Tesztek: mobil **568** zöld (ebből 45 új: repository, domain, szerepkör-provider,
buborék-widget, lista-képernyő), backend **713** zöld (ebből 9 új a push-ra).

### 13.2 Eltérések a tervtől — ezekkel kell dolgozni

| Terv | Valóság | Miért |
|---|---|---|
| `data/chat_dto.dart` külön DTO réteg | **nincs**; a `fromJson` a domain modelleken ül | a `my_trainers` már így csinálja; egy réteggel kevesebb, ugyanaz a szerződés |
| `ChatStreamClient`, jelenlét | **nincs** (I4) | SSE nélkül nincs mit olvasni |
| Buborék-állapotok: 4 állapot élesben | **`pending` / `sent` / `failed` fordul elő**; a `delivered` és `read` a widgetben kész, de adat nincs hozzá | a szerver a *másik fél* olvasás-kurzorát nem adja vissza I4-ig — a pipák bekötése ott egy sor |
| Szál-fejléc „online / utoljára aktív” alsor | **nincs** | nincs jelenlét-adat; a design kifejezetten tiltja a hamis jelzést |
| Buborék szövege `SelectableText` | **`Text`** + hosszan-nyomás menü „Másolás”-sal | a kijelölés és a menü ugyanazért a hosszan-nyomásért versengett; a menü nyert, mert a design azt írja le (a widget-teszt fogta meg) |
| Kép-csatolmány, gépelés-jelző, némítás | **nincs** (I6 / I5) | változatlanul későbbi fázis |
| Push összevonási ablak (`push-coalesce-window`) | **nincs**, de a törzs **már aggregál**: 1 olvasatlannál az üzenet, több olvasatlannál „N új üzenet” | a szám a `last_read_message_id`-ből jön, nem az ablakból, így az I5 ablak-logika ezt nem írja felül, csak ritkítja a kiküldést |
| `SettingsRequest` push-kapcsolói `@NotNull` | a `chatPushEnabled` **nullable**, hiánya = „hagyd a tárolt értéken” | a backend a mobil kiadás **előtt** megy ki; `@NotNull`-lal minden régebbi app-verzió beállítás-mentése 400-at kapna |

### 13.3 Amit az I2 tudatosan nem szállít

Realtime (SSE), jelenlét (`POST /chat/presence`), kézbesítve/olvasva pipa, gépelés-jelző,
némítás, csendes órák, push összevonási ablak és collapse key, e-mail fallback,
kép-csatolmány, rendszerüzenet a szálban. A `chat_participants` `muted_until` /
`last_notified_at` / `last_delivered_message_id` oszlopai és a
`user_settings.chat_quiet_hours_*` mezők továbbra is üresen állnak.

**Ami emiatt polling:** SSE nélkül az olvasatlan badge és a lista frissülését a
`ConnectivitySyncController` meglévő ütemezése hajtja (indulás, kapcsolat-visszatérés,
app előtérbe kerülés, 60 mp-es timer) — a push értesítést hoz, nem adatot. Az I4 ezt
váltja ki; a `refreshConversations()` hívás onnantól tartalék marad, nem az elsődleges út.

### 13.4 Architektúra-döntések, amik kötik a következő lépéseket

1. **A chat kimarad a generikus sync-ből.** Nincs `entity_sync_config` bejegyzés, a
   `PullEngine` nem nyúl hozzá; a `ChatRepository` maga kezeli a REST-et, a cache-t és a
   saját mini-outboxát (a `pending` sorok). Az I4 az SSE-t **ebbe** a repositoryba köti,
   nem a `SyncEngine`-be.
2. **Az idempotencia a kliens szerződése is.** Minden üzenet `clientMessageId`-t kap
   (`newClientId()`), és az újraküldés **ugyanazt** használja. Ez az egyetlen ok, amiért
   a `flushPending()` vakon újraküldhet mindent.
3. **A szerver echója felülírja az optimista sort** (`InsertMode.insertOrReplace` a
   `(conversationId, clientId)` kulcsra) — ettől lesz a `pending` buborékból valódi
   üzenet duplikálódás helyett.
4. **A szerepkör három ponton látszik, sehol máshol.** `isTrainerProvider` (JWT `roles`
   claim) → lista-cím, „Új beszélgetés” FAB, üres állapot szövege. A `peer.role` címke
   **csak vegyes listán** jelenik meg. Az I3 webnek ugyanezt kell tükröznie.
5. **A composer offline sem tiltott.** Ez a funkció lényegi üzenete; bármilyen későbbi
   „küldés letiltása” állapot (rate limit, kill switch) is csak visszajelzés lehet, nem
   a mező letiltása.

---

## 14. Megvalósítási napló — I3 (edzői web)

> **Az I4 (realtime) innen indul.** A web ugyanazt az API-t fogyasztja, amit a mobil
> már használ; új backend-végpont **nem** készült ehhez az iterációhoz. A megjelenéshez
> továbbra is a **§10 design-forrásai** a kötelező bemenet.

### 14.1 Mi készült el

| Réteg | Fájlok |
|---|---|
| Adatréteg | `web/src/features/chat/types.ts` (a `com.lifey.chat.dto` tükre + `ThreadMessage`), `api.ts` (`chatApi`), `queryKeys.chat.*` |
| Tiszta logika | `features/chat/thread.ts`: `mergeMessages`, `buildThreadItems` (nap-elválasztó + feladó-futamok), `sortConversations`, `filterConversations`, `hasMixedPeerRoles`, `totalUnread`, `titleWithUnread`, `unreadBadgeLabel`, `newClientMessageId`, body-validáció |
| Hookok | `features/chat/hooks.ts`: `useConversations`, `useUnreadTotal`, `useUnreadDocumentTitle` |
| Komponensek | `features/chat/components/`: `ConversationList` (kereső + sorok), `ChatThread` (fejléc, folyam, keyset lapozás felfelé, olvasás-nyugta, optimista küldés), `MessageBubble`, `ChatComposer` (+`ArchivedComposerNotice`), `ChatAvatar` |
| Oldal | `web/src/app/(admin)/admin/chat/page.tsx` — két hasáb, `?c=<id>` a nyitott szálra |
| Beépülés | `AdminSidebar` chat menüpont olvasatlan-badge-dzsel, `document.title` = `(3) Lifey`, „Üzenet” gomb a `ClientDetailHeader`-ben |
| i18n | 42 kulcs a `chat` névtérben (`messages/hu.json` / `en.json`) + `admin.nav.chat` |
| Tesztek | `features/chat/thread.test.ts` (18 eset), `e2e/trainer-chat.spec.ts` (Playwright: kliens-lapról nyitás → küldés Enterrel → a kliens API-n látja) |

Teljes web suite zöld (**131** vitest teszt, ebből 18 új), `lint` és `typecheck` tiszta.

### 14.2 Eltérések a tervtől — ezekkel kell dolgozni

| Terv | Valóság | Miért |
|---|---|---|
| `web/src/app/(app)/chat/page.tsx` | **`(admin)/admin/chat/page.tsx`** | az `(app)` a *kliens* héja; a design C1 az edzői shellt rajzolja ([EDZŐ] chip, bal sidebar), és a `(admin)` layout adja a `ROLE_TRAINER` guardot is |
| `features/chat/api.ts` **Zod sémákkal** | **TypeScript típusok** (`types.ts`), Zod nélkül | a webben a Zod ma kizárólag űrlap-validáció (`features/*/schemas.ts`); egyetlen API-válasz sincs runtime-validálva — a chat nem vezet be új mintát |
| `features/chat/hooks.ts` **+ mutációk hookokban** | `hooks.ts` csak a lista- és olvasatlan-hookokat tartja; a szál mutációi a `ChatThread`-ben ülnek | a repo konvenciója a komponensbe írt `useQuery`/`useMutation`; a `hooks.ts` az első ilyen fájl, és csak azért létezik, mert az olvasatlan számot a sidebar és az oldal is kéri |
| Sor-túlcsordulás „⋯” menü (némítás + kliens megnyitása) | **közvetlen „Kliens megnyitása” ikon-gomb** hoverre, menü nélkül | a némítás I5 (`chat_participants.muted_until` még üresen áll); egyetlen élő elemű legördülő rosszabb, mint maga a link |
| Szál-fejléc „online” alsor | **a peer e-mail-címe** | nincs jelenlét-adat I4-ig, és a design tiltja a hamis jelzést — az e-mail viszont valós és az edzőnek azonosít |
| Buborék-állapotok: 4 állapot | **`pending` / `sent` / `failed`** | ugyanaz az ok, mint mobilon (§13.2): a másik fél olvasás-kurzorát a szerver I4-ig nem adja vissza |
| — | **`?c=<id>` query paraméter** a kiválasztott szálra | a kliens-lapról érkező átadás és az újratöltés is ezen múlik; a kiválasztás nem komponens-state |

### 14.3 Amit az I3 tudatosan nem szállít

Realtime (SSE), jelenlét, kézbesítve/olvasva pipa, gépelés-jelző, némítás, web push
(VAPID + service worker), kép-csatolmány, üzenet-keresés a szálban. **Az edzőnek weben
nincs „új beszélgetés” indítója**: a szál a kliens-részletező lap „Üzenet” gombjából jön
létre (`POST /chat/conversations/with-user/{userId}`), ami ugyanaz a lazy-create, amit a
mobil alsó lapja használ — a webnek nincs szüksége külön kliens-választóra, mert a
kliens-lista maga a `/admin` főoldal.

**Ami emiatt polling:** a beszélgetés-lista és a nyitott szál is `refetchInterval`-lel
frissül (`CHAT_POLL_INTERVAL_MS`, 20 mp) plusz ablak-fókuszra. Egy következmény, amit az
I4 old meg: a **másik fél által törölt** üzenet tombstone-ja csak teljes újratöltéskor
jelenik meg, mert a szál-lekérdezés `after=<utolsó id>` hézagpótlást kér, ami régebbi
sorok változását nem hozza vissza. *(Utólag: az I4 ezt **nem** oldotta meg — a törléshez
saját frame kellett, amit végül az I6/1 szállított, lásd §17.)*

### 14.4 Architektúra-döntések, amik kötik a következő lépéseket

1. **A szál lekérdezése a saját eredményére épül.** A `ChatThread` `queryFn`-je kiolvassa
   a cache-t, és `after=<newestMessageId>`-vel csak a hézagot kéri le; ha nincs kurzor
   (első nyitás vagy kiürült cache), a legfrissebb oldalt. Az I4 SSE-je **ebbe a
   cache-be** ír (`queryClient.setQueryData` + `mergeMessages`), nem invalidál — különben
   minden üzenet egy teljes refetch-et váltana ki.
2. **`mergeMessages` a `clientMessageId`-re kulcsol**, nem a szerver id-re. Ettől lesz az
   optimista buborékból a szerver echója után ugyanaz a sor, és ez teszi az `mergeMessages`-t
   újrahasznosíthatóvá az SSE-eseményekre is.
3. **Az újraküldés ugyanazt a `clientMessageId`-t viszi.** A web `failed` buborékja a
   mobil `pending` outboxának a párja: nincs perzisztens sor (a böngészőben nincs Drift),
   de a retry ugyanúgy idempotens.
4. **A `ChatThread` a beszélgetés id-jére van kulcsolva** (`key={selected.id}`), ezért a
   szálváltás remount — a lapozási ablak és az olvasás-kurzor effekt nélkül áll vissza.
5. **Az olvasatlan jelzés egy forrásból jön.** `useConversations` → `totalUnread` → a
   sidebar badge és a fül-cím. Az I4 után ugyanez a hook kap SSE-frissítést, a badge-hez
   nem kell hozzányúlni.
6. **A web nem vezetett be új design tokent**, és nem talált ki új buborék-nyelvet: a
   `radius`/szín/állapot-ikon készlet a mobiléval azonos, csak nagyobb képernyőre
   (65ch max buborék-szélesség) lélegzik.

---

## 15. Megvalósítási napló — I4 (realtime: SSE + jelenlét + pipák)

> **Az I5 (értesítés-finomhangolás) innen indul.** A §5.2 létrájából a jelenlét-kapu
> már be van kötve; a maradék három (csendes órák, némítás, összevonási ablak) az I5.

### 15.1 Mi készült el

**Backend**

| Réteg | Fájlok |
|---|---|
| Transzport | `service/ChatEmitterRegistry` (élő emitterek + heartbeat + szivárgás-védelem), `service/ChatEventBus` + `service/InMemoryChatEventBus` |
| Stream | `service/ChatStreamService`/`Impl` (emitter nyitás, `Last-Event-ID` hézagpótlás, `resync`), `controller/ChatStreamController` (`GET /chat/stream`, `POST /chat/presence`) |
| Jelenlét | `service/ChatPresenceRegistry` (TTL-es, memóriában) |
| Nyugták | `service/ChatReceiptService`/`Impl` (delivered/read kurzor + `read` frame), `ChatStreamBroadcaster` (`AFTER_COMMIT` a `ChatMessageStoredEvent`-re és az új `ChatReadCursorEvent`-re) |
| DTO-k | `dto/ChatEvent`, `MessageEventPayload`, `ReadEventPayload`, `ResyncEventPayload`, `PresenceRequest`; `ConversationResponse` + `peerLastDeliveredMessageId` / `peerLastReadMessageId` |
| Egyéb | `ChatProperties` + `streamTimeout` / `streamCatchUpLimit` / `presenceTtl` (+ `lifey.chat.stream-heartbeat`), `ChatNotificationServiceImpl` jelenlét-kapu, `ChatMessageRepository.findAllForParticipantAfter`, `ChatParticipantRepository.findAllForUser` / `findPeerParticipants` |

**Web**

| Réteg | Fájlok |
|---|---|
| Transzport | `lib/api/chat-stream.ts` (fetch + `ReadableStream` parser, backoff jitterrel, `Last-Event-ID`, 401 → token-frissítés), `lib/api/client.ts` új `refreshAccessToken()` |
| Bekötés | `features/chat/hooks.ts`: `useChatStream` (az admin layoutban él, a cache-be ír), `usePresence` (`visibilitychange`-re is) |
| Pipák | `thread.ts` `receiptStateFor`, `MessageBubble` négy állapota (`read` = kitöltött, `primary`) |

**Mobil**

| Réteg | Fájlok |
|---|---|
| Transzport | `data/chat_stream_client.dart` (Dio stream, SSE parser, backoff, `Last-Event-ID`) |
| Bekötés | `application/chat_stream_controller.dart` (életciklus: előtérben nyitva, háttérben zárva + `presence(null)`), `app.dart` provider |
| Adat | `ChatRepository.applyIncomingMessage` / `applyReadReceipt` / `setPresence` / `newestServerIdAcrossThreads`, séma **v30** (`peerLastDeliveredMessageId`, `peerLastReadMessageId`) |
| Pipák | `receiptStateFor` a `chat_conversation.dart`-ban, `MessageBubble.receiptState` |

Tesztek: backend **751** zöld (ebből 38 új: emitter-regisztráció és -szivárgás, hézagpótlás
és `resync`, jelenlét TTL, kurzor-monotonitás, jelenlét-alapú push-kihagyás, integrációs
`peer*` mezők és `/chat/presence`), web **142** zöld (ebből 11 új: `receiptStateFor`,
SSE-frame parser), mobil **586** zöld (ebből 18 új: stream-frame parser, bejövő üzenet,
nyugta, reconnect-kurzor, `receiptStateFor`).

### 15.2 Eltérések a tervtől — ezekkel kell dolgozni

| Terv | Valóság | Miért |
|---|---|---|
| Az `id:` a `chat_messages.id`, a read-eknél **külön monoton szekvencia** | **csak a `message` frame hordoz `id:`-t**, a `read` és a `resync` nem | az SSE-ben egy `id:` nélküli frame nem mozdítja a `Last-Event-ID`-t, így a kurzor pontosan egy dolgot jelent: „a legfrissebb üzenet, amit már látok”. Két id-tér összekeverése a hézagpótló lekérdezést tette volna kétértelművé; a nyugta úgyis újraszámolható a lista-lekérésből |
| `read` esemény: `{conversationId, userId, lastReadMessageId}` | **+ `lastDeliveredMessageId`** ugyanabban a frame-ben | a pipa egyetlen háromfokú létra (elküldve → kézbesítve → olvasva); két frame-típusra bontva a kliensnek kellene újra összerakni |
| `ChatEventBus(+InMemoryChatEventBus)` egy osztálynyi seam | **`ChatEventBus` + `ChatEmitterRegistry` külön** | a socket nem osztható meg JVM-ek között: egy `LISTEN/NOTIFY` implementáció is ugyanezt a lokális registry-t hívná. Így a bus a cserélhető transzport, a registry nem |
| `last_delivered_message_id` üzenetenként karbantartva | **stream-csatlakozáskor szálanként a `last_message_id`-ig ugrik**, utána élő üzenetenként | az üzenetenkénti kézbesítés kliens-ackot igényelne; „a kliensed él, és amit még nincs meg neki, azt épp tölti” igaz a reconnect-ablakon belül, és egy körbejárás a user szálain |
| jelenlét TTL 2 perc, „a jelenlét memóriában él” | ugyanez, **plusz a `ChatEventBus.isConnected` együttes feltétel** a push-kihagyáshoz | egy kilőtt app után bent ragadt jelenlét-bejegyzés különben a TTL végéig elnémítaná a pusht — a kapcsolat megléte az, ami valóban „ott van” |
| „a `refreshConversations()` onnantól tartalék marad” | weben a `refetchInterval` **20 mp-ről 60 mp-re** lazult, nem szűnt meg | többinstance-os deployon az in-memory bus instance-lokális (§9); a lassú poll az, ami ezt elfedi |
| — | a stream **regisztrál, majd replayel** (nem fordítva) | a kettő között érkező üzenet így duplikálódhat (a kliens id szerint dedupál), nem veszik el — a fordított sorrend a lehetséges veszteséget választaná |

### 15.3 Amit az I4 tudatosan nem szállít

Gépelés-jelző (`typing`, I6), némítás (`muted_until`), csendes órák, push összevonási
ablak és collapse key, e-mail fallback, kép-csatolmány, rendszerüzenet a szálban,
**web push**. A `chat_participants.muted_until` / `last_notified_at` és a
`user_settings.chat_quiet_hours_*` továbbra is üresen áll — ezeket az I5 tölti fel.

**Egy instance.** A `PostgresChatEventBus` (LISTEN/NOTIFY) nem készült el: a §9 szerint
több instance esetén a chat *működik*, csak a realtime lesz instance-lokális, és a push +
a 60 mp-es poll elfedi. Ez az I7 tétele, és egy osztálynyi munka — a seam megvan.

### 15.4 Architektúra-döntések, amik kötik a következő lépéseket

1. **A stream soha nem igazságforrás.** Minden frame-nek van REST-megfelelője, és ha a
   szerver nem tud hézagot pótolni, `resync`-et küld, amire a kliens teljes újratöltést
   csinál. Bármi, ami az I6-ban a streamre kerül (gépelés-jelző), ugyanezt a szabályt
   kövesse: ne legyen olyan állapot, ami *csak* a streamen létezik.
2. **A pipák kurzorból származnak, nem üzenet-mezőből.** `receiptStateFor(message,
   peerDelivered, peerRead)` mindkét kliensen; a szerver két számot ad szálanként. Aki új
   üzenet-állapotot akar bevezetni, előbb döntse el, kurzor-e vagy sem.
3. **A jelenlét két helyről dől el.** `isConnected` (van élő stream) **és**
   `isViewing` (ezt a szálat nézi). Az I5 gátjai (csendes óra, némítás) e *mögé*
   kerülnek a `ChatNotificationServiceImpl`-ben, nem elé — a „látta” eset már most sem
   generál pusht, és azt nem kell újra eldönteni.
4. **Két listener egy eseményen, szándékosan.** A `ChatStreamBroadcaster` azt dönti el,
   mit mutassanak a már nyitott képernyők; a `ChatNotificationServiceImpl` azt, hogy
   megzavarjunk-e valakit. Közös írásuk nincs, ezért a sorrendjük sem számít.
5. **A mobil stream előtér-kötött.** Háttérbe menéskor lezár és `presence(null)`-t küld;
   ettől lesz a push kézbesítési csatorna pontosan akkor, amikor kell. Bármilyen későbbi
   „háttérben is figyelj” igény (pl. gépelés-jelző) ezt a szerződést bontaná meg.
6. **A web streamje az admin shellben él, nem a `/chat` oldalon.** Így a sidebar
   olvasatlan-badge-e akkor is él, amikor az edző máshol dolgozik — és ez az egyetlen
   ambiens jelzés, amíg nincs web push.

### 15.5 Terhelési sanity — 200 párhuzamos emitter (jegyzőkönyv)

**Mérés dátuma:** 2026-08-06. **Környezet:** helyi dev backend (JDK 24, G1 GC, alap
Tomcat/HikariCP beállítások), Postgres a `docker-compose`-ból. **Módszer:** egy Node
szkript 200 SSE kapcsolatot nyit két user között elosztva (100–100), a heap-et kívülről
`jcmd GC.run` + `GC.heap_info` mintázza, az emitter-darabszámot `jcmd GC.class_histogram`
adja (az actuatorból csak a `/health` van kitéve, metrika-végpont nincs — az az I7).

| | Alaphelyzet | 200 nyitott stream | Lezárás után |
|---|---|---|---|
| Heap used | 70 491 K | 91 872 K | 86 744 K |
| Élő `SseEmitter` | 2 | **202** (200 + a 2 valódi kliens) | **2** |
| JVM szálak | 46 | 44 | 45 |
| TCP established (8080) | 2 | 202 | 2 |

**Eredmények.**

1. **~107 KB heap kapcsolatonként** (21,4 MB / 200). 200 párhuzamos edzőnél ez ~21 MB —
   elhanyagolható; a §9 riasztási küszöbe nem a memória, hanem a *darabszám* elszállása.
2. **A szálszám nem nő.** Az aszinkron feldolgozás visszaadja a kérés-szálat, mielőtt a
   stream élne, tehát 200 kapcsolat nem 200 Tomcat-szál. Ez az a tulajdonság, ami miatt
   az SSE egyáltalán vállalható ezen a stacken.
3. **Nincs szivárgás.** Lezárás után 202 → 2 élő emitter, azaz mind a 200 felszabadult.
   A heap „used” nem esik vissza pontosan az alapszintre (86,7 MB vs 70,5 MB); ez két
   teljes 200-kapcsolatos futás után visszatartott puffer, nem emitter — a class
   histogram a döntő jel, nem a heap-összeg.
4. **A szórás mindenkit elér.** Egyetlen elküldött üzenet **pontosan 200** `message`
   frame-et eredményezett a 200 kapcsolaton (a küldő saját kliensei is megkapják, §15.4/4).
5. **200 kapcsolat megnyitása 647 ms** volt.

**Amit a mérés talált (és javítva lett).** Az első futáskor egy stream megnyitása
**~20 másodpercig** tartott: amíg nem íródik ki egyetlen bájt sem, a szervlet-konténer nem
commitálja a választ, így a kliens kérése csak a következő heartbeatnél oldódott fel — és
mivel egy kurzor nélküli kliens nem kap visszajátszást, tényleg nem volt mit írni.
Ez minden csatlakozást és **minden újracsatlakozást** vakká tett a
`lifey.chat.stream-heartbeat` idejéig. Javítás: a `ChatStreamServiceImpl.open` a
regisztráció után azonnal kiír egy `: connected` komment-frame-et
(`ChatEmitterRegistry.sendOpeningComment`). Utána a mérés **5 ms** kapcsolatonként.
Regressziós teszt:
`ChatStreamServiceImplTest.openingAStreamWritesImmediately_soTheClientIsNotBlindUntilTheFirstHeartbeat`.

**Ami ebből az I7-be megy.** A `ChatEmitterRegistry.connectionCount()` ma csak
programból olvasható; a §9 szivárgás-riasztásához Micrometer-gauge-ként ki kell tenni —
enélkül ez a mérés csak kézzel, `jcmd`-vel megismételhető.

---

## 16. Megvalósítási napló — I5 (értesítés-finomhangolás)

> **Ezzel a chat funkcionálisan kész.** Az I6 (opcionális kiterjesztések) azóta
> teljesen elkészült — §17–§20 —, hátra az I7 (üzemeltetés és mérés) van.

### 16.1 Mi készült el

**Backend**

| Elem | Fájlok |
|---|---|
| A teljes §5.2 létra | `ChatNotificationServiceImpl`: jelenlét → master kapcsoló → csendes órák → némítás → összevonási ablak → küldés + `last_notified_at` |
| Csendes órák | `service/ChatQuietHours` (tiszta, `User.utcOffsetMinutes` alapján, éjfélen átnyúló ablakkal), `SettingsRequest`/`Response`/`Mapper` + `chatQuietHoursStart` / `End` / **`chatQuietHoursSet`** |
| Némítás | `dto/MuteRequest`, `PUT /chat/conversations/{id}/mute`, `ChatService.mute`, `ConversationResponse.mutedUntil` |
| Összevonás | `ChatProperties.pushCoalesceWindow`, `PushMessage.collapseKey` + APNs `apns-collapse-id` és FCM `AndroidConfig.collapseKey` |
| Emlékeztető | `ChatUnreadReminderJob` (cron 5 perc), `ChatParticipantRepository.findReminderCandidates`, `chat_participants.last_reminded_at` (`V66__chat_reminder.sql`) |
| E-mail fallback | `MailService.sendUnreadChatEmail` + `chat_unread_{hu,en}.{html,txt}` + `mail.chat-unread.subject`, `lifey.chat.email-fallback-enabled` mögött (alapból **ki**) |

**Kliensek**

| Elem | Hol |
|---|---|
| Csendes órák UI | mobil: `notification_settings_screen.dart` (kapcsoló + két időpont-választó); web: új **Értesítések** szekció a `/settings` oldalon (chat push kapcsoló + csendes órák) |
| Némítás UI | mobil: harang-akció a szál app barjában + időtartam-lap (1 óra / 8 óra / visszavonásig); web: a szál fejlécének „⋯"-utódja ugyanezekkel |
| Némított sor | mobil `conversation_tile` és web `ConversationList`: áthúzott harang ikon |
| Adat | mobil séma **v31** (`chat_quiet_hours_*`) és **v32** (`chat_conversations.muted_until`), `ChatRepository.setMuted`, web `thread.ts` `isMuted`/`muteUntil` |

Tesztek: backend **777** zöld (ebből 26 új: összevonási ablak, collapse key, némítás,
csendes órák időzóna-határesetekkel, reminder napi cap, e-mail fallback ágai), web
**145** zöld (+3), mobil **589** zöld (+3).

### 16.2 Eltérések a tervtől — ezekkel kell dolgozni

| Terv | Valóság | Miért |
|---|---|---|
| „Csendes órában nem küld, hanem **eltolja az órák végére**" | a job egyszerűen **kihagyja** a csendes órás usert, és a következő 5 perces tick küld | ez ugyanaz az eredmény ütemezett feladat nélkül: a tick az ablak vége után ugyanazokat az olvasatlan üzeneteket találja. Egy „eltolt küldés" sor tárolása egy második, saját életciklusú állapot lenne |
| `reminderDailyCap` konfigurálható darabszám | a mező megvan, de a logika **„volt-e emlékeztető 24 órán belül"** | 1-nél nagyobb cap értelmes ütemezést kívánna (mikor a második?), amire nincs termékdöntés; a `<= 0` érték kikapcsolja a jobot, ami viszont valódi kapcsoló |
| — | **`SettingsRequest.chatQuietHoursSet`** (a tervben nem szerepel) | két nullérték nem különböztethető meg: „ez a kliens nem ismeri a csendes órákat" (hagyd békén) vs. „a user törölte az ablakot" (töröld). Enélkül egy régebbi mobil-verzió mentése némán kitörölte volna a weben beállított ablakot |
| A némítás „időtartam-választó" | **fix választék** (1 óra / 8 óra / visszavonásig), abszolút `mutedUntil` instantként tárolva | a kérdés „hagyjatok békén egy kicsit" vagy „végleg"; egy szabad időpont-választó a gyakori esetet lassítaná. Instantként a némítás **magától lejár**, nem kell söpörni |
| „Kép-csatolmány / gépelés-jelző" hivatkozás az I5-ben | változatlanul **I6** | nem került előre |

### 16.3 Amit az I5 tudatosan nem szállít

Web push (VAPID + service worker), gépelés-jelző, kép-csatolmány, rendszerüzenet a
szálban, keresés a szálban — mind I6/I7 vagy nyitott kérdés. Az **e-mail fallback kódja
kész, de kikapcsolva**: a §5.5 döntése szerint előbb a metrikákból kell látni, hányszor
sülne el; a metrikák viszont az I7 tárgya, tehát a bekapcsolás sorrendben az I7 után jön.

### 16.4 Architektúra-döntések, amik kötik a következő lépéseket

1. **Minden kapu csak az értesítést némítja, az üzenetet soha.** Csendes óra, némítás,
   összevonás — mindegyik után az üzenet olvasatlan marad, és a `ChatUnreadReminderJob`
   a háló alattuk. Bármilyen új kapu (pl. „ne értesíts munkaidőben") ugyanide, a
   `ChatNotificationServiceImpl` létrájába kerüljön, és ugyanez a szabály vonatkozzon rá.
2. **A napi cap a useré, nem a szálé.** A `last_reminded_at` ezért a user **összes**
   `chat_participants` sorára ráíródik, és a job a legfrissebbet olvassa. Aki új
   per-user chat állapotot akar bevezetni, vagy ezt a mintát folytassa, vagy csináljon
   neki valódi per-user sort — a `user_settings` viszont beállítás, nem kézbesítési állapot.
3. **Az összevonás számlálója a kurzorból jön, nem az ablakból.** Ezért marad a „N új
   üzenet" szám pontos akkor is, ha egy push elveszett, vagy a user máshol olvasta el a
   szál egy részét. Az I7 metrikái ezt ne az ablakból származtassák.
4. **A collapse key két helyen jelenik meg**: `chat-{conversationId}` az üzenet-pusholon
   és `chat-reminder` az emlékeztetőn — így az emlékeztető nem nyom el egy üzenet-sort,
   és két emlékeztető sem gyűlik egymásra.
5. **A `ChatQuietHours` tiszta és statikus.** Nincs benne `Clock` és nincs benne
   repository: a bemenete `User` + `UserSettings` + `Instant`. Ez az, ami az éjfélen
   átnyúló ablakot és az időzóna-eseteket tesztelhetővé teszi anélkül, hogy Spring-et
   kellene indítani hozzá.

### 16.5 Élő ellenőrzés (jegyzőkönyv)

Futtatva a `feature/chat-functionality` build ellen, valódi backend + Postgres, két
munkamenettel (edző → kliens). A gátak nyomát a `chat_participants` sor őrzi, ezért az
ellenőrzés azt olvassa, nem a push-kimenetet (nincs regisztrált eszköz):

| Ellenőrzés | Eredmény |
|---|---|
| első üzenet nyitja az összevonási ablakot (`last_notified_at` beíródik) | ✅ |
| ablakon belüli második üzenet kimarad (`last_notified_at` változatlan) | ✅ |
| `PUT /mute` → 204, és `mutedUntil` megjelenik a lista-válaszban | ✅ |
| némított szál nem értesít | ✅ |
| némítás feloldása után újra értesít | ✅ |
| csendes órák oda-vissza mennek a Settings API-n | ✅ |
| csendes órán belül nincs push | ✅ |
| az ablakon kívül újra van | ✅ |
| `chatQuietHoursSet` nélküli mentés **nem** törli a tárolt ablakot | ✅ |
| `chatQuietHoursSet: false` **törli** | ✅ |
| `ChatUnreadReminderJob` a soron következő 5 perces tickre lefut és bélyegzi a user minden szálát | ✅ |

---

## 17. Megvalósítási napló — I6/1 (üzenet törlése)

> **Az I6 három megmaradt tétele** (kép-csatolmány, gépelés-jelző, keresés a szálban)
> **innen indul.** A `deleted` frame az első olyan SSE esemény, ami egy már meglévő
> sort módosít — a §17.4/1 szabálya minden továbbira vonatkozik.

### 17.1 Amit a munka a kódban talált

A tétel szövege („üzenet törlése UI-ból, a backend már tudja I1 óta") **félrevezető
volt**: a törlés UI-ja az I2/I3-ban már leszállt mindkét kliensen — mobilon a buborék
hosszan-nyomás menüjének „Törlés" sora, weben a hoverre megjelenő kuka-gomb, tombstone
renderelés és lista-előnézet mindkettőn.

Ami **hiányzott**, azt a §14.3 maga nevezi meg: a törlés **nem jutott el a másik
félhez**. A szál lekérdezése `after=<utolsó id>` hézagpótlást kér, ami régebbi sorok
változását sosem hozza vissza — a peer tehát a törölt üzenet szövegét látta tovább,
akár korlátlan ideig (mobilon a lokális cache miatt egy újratelepítésig). Az I6 valódi
tartalma ezért a **propagáció** lett, nem a felület.

### 17.2 Mi készült el

**Backend**

| Elem | Fájlok |
|---|---|
| Esemény | `ChatMessageDeletedEvent` (csak `messageId`, a `ChatMessageStoredEvent` mintájára), publikálva a `ChatServiceImpl.deleteMessage`-ből |
| Frame | `ChatEvent.DELETED` + `ChatEvent.deleted(...)`, `dto/MessageDeletedEventPayload` (`conversationId`, `messageId`, `deletedAt`) |
| Szórás | `ChatStreamBroadcaster.onMessageDeleted` (`AFTER_COMMIT` + `REQUIRES_NEW`) → mindkét résztvevő, kurzor-mozgatás nélkül |
| Dokumentáció | `ChatStreamController` OpenAPI leírása a negyedik frame-mel |

**Kliensek**

| Elem | Hol |
|---|---|
| Frame kezelése | mobil: `ChatStreamController` `deleted` ága → `ChatRepository.applyDeletedMessage`; web: `hooks.ts` `applyFrame` `deleted` ága |
| Tombstone írás | mobil: `ChatRepository._tombstone` (idempotens, a lista-előnézetet csak a legutolsó üzenetnél nullázza); web: `thread.ts` `applyDeletion` (tiszta függvény, változatlan tömböt ad vissza, ha nincs mit tenni) |
| Megerősítés | mobil: `showConfirmDeleteDialog` a szál képernyőjén; web: `ConfirmDialog` a `ChatThread`-ben — új l10n kulcsok mindkét nyelven |

Tesztek: backend **782** zöld (ebből 5 új: mindkét fél megkapja a frame-et, a tombstone
egyik kurzort sem mozdítja, nem-törölt sorra nincs frame, hibanyelés, az ismételt
törlés nem szór újra), web **148** zöld (+3: `applyDeletion`), mobil **594** zöld
(+5: előnézet-nullázás a legutolsó üzenetnél, változatlan előnézet régebbinél, el nem
küldött buborék viszi tovább az előnézetet, bejövő `deleted` frame, ismételt frame).

### 17.3 Eltérések a tervtől — ezekkel kell dolgozni

| Terv | Valóság | Miért |
|---|---|---|
| „Üzenet törlése **UI-ból**" | a UI megvolt; a szállított munka a **`deleted` SSE frame** end-to-end | lásd §17.1 — egy törlés, amit a másik fél nem lát, nincs leszállítva |
| — | a `deleted` frame **nem hordoz `id:`-t** | a törölt üzenet id-je definíció szerint régebbi a kliens kurzoránál; `Last-Event-ID`-nek beállítva minden újracsatlakozás visszajátszaná a szál végét (a §15.2 „csak a `message` hordoz id-t" szabályának egyenes folytatása) |
| — | a frame a **küldő saját eszközeire is** megy | ugyanaz az ok, mint küldésnél: a másik fül / a másik telefon ne mutassa tovább a szöveget. A törlést végző kliens optimista frissítése miatt ott no-op |
| — | **megerősítő párbeszéd** mindkét kliensen, új l10n kulcsokkal | a törlés visszavonhatatlan és a másik fél képernyőjéig ér; a repo minden más destruktív műveleténél is van megerősítés. A **még el nem küldött** buborék elvetése továbbra sem kérdez — azt rajtunk kívül senki nem látta |
| — | mobilon a lista-előnézet **csak akkor** nullázódik, ha a törölt üzenet a legutolsó | a null előnézet az, amit a sor „Az üzenetet törölték"-ként rendel; egy régebbi üzenetre alkalmazva hazudna a szálról |

### 17.4 Architektúra-döntések, amik kötik a következő lépéseket

1. **A `deleted` az egyetlen frame, ami visszanyúl egy már meglévő sorra.** Minden
   eddigi frame előre mutatott (új üzenet, előrelépő kurzor), ezért volt elég a
   `after=<id>` hézagpótlás. Aki új, *módosító* eseményt vezet be (üzenet-szerkesztés,
   csatolmány-állapot), annak ugyanígy saját frame kell, és ugyanígy `id:` nélkül.
2. **A tombstone nem üzenet.** Nem mozdítja a `delivered` / `read` kurzort, nem számít
   bele az olvasatlanba, és nem vált ki pusht — a `ChatNotificationServiceImpl`
   létrájához hozzá sem ér.
3. **A törlés alkalmazása idempotens mindkét kliensen.** A művelet elvégzője optimista
   frissítést ír, majd megkapja a saját frame-jét is; a `_tombstone` (mobil) csak
   `deletedAt is null` sorra ír, az `applyDeletion` (web) ugyanazt a tömböt adja
   vissza. Bármilyen későbbi frame-típus kövesse ezt — a stream duplikálhat (§15.2).

### 17.5 Amit az I6/1 tudatosan nem szállít

Kép-csatolmány, gépelés-jelző, keresés a szálban — az I6 másik három tétele, mind
felvehető önállóan.

**Egy ismert korlát.** Ha a törlés akkor történik, amikor a kliens **nincs
csatlakozva**, a frame elvész, és az újracsatlakozás hézagpótlása (`after=<id>`) nem
hozza vissza: a tombstone csak teljes újratöltéskor jelenik meg (`resync`, cache-ürítés,
vagy weben az oldal-újratöltés utáni első oldal-lekérés). Ez tudatos: egy „mi változott
mióta offline vagy" lekérdezés a chat egészét érintő új szerződés lenne
(`chat_messages.updated_at` + egy delta végpont), az üzenet szövege pedig a szerveren
már ekkor sincs meg — csak a másik fél elavult másolata él tovább egy ideig. Ha ez
később mégis kell, a helye a stream catch-up (`ChatStreamServiceImpl`), nem a REST.

> **Utólag: kellett, és pontosan oda került.** A korlát a gyakorlatban nem „egy ideig"
> tartott, hanem véglegesnek bizonyult: mobilon a lokális Drift-cache miatt egy teljes
> app-újraindítás sem hozta vissza a tombstone-t, weben pedig a TanStack-cache
> túléli az oldalon belüli navigációt, tehát az `after=<id>` csapdája ott is
> bezárult. A javítás két rétegű:
>
> 1. **Szerver** — `ChatStreamServiceImpl.replayTombstones`: újracsatlakozáskor a
>    kurzor **alatti** sorok friss törlései is visszamennek `deleted` frame-ként,
>    `lifey.chat.stream-tombstone-window` (7 nap) korláttal, a `resync`-ág előtt
>    kilépve. Nem kellett hozzá `updated_at` és delta végpont: a `deleted_at` maga
>    az időbélyeg, amire szűrni lehet.
> 2. **Kliensek** — a szál megnyitása egyszer újraolvassa a **legfrissebb oldalt**
>    (`ChatRepository.reconcileNewestPage`, illetve weben a `reconciledRef` első
>    lekérése), utána marad az olcsó előre-hézagpótlás. Ez az az út, ami akkor is
>    működik, ha a stream épp nem szállít.

---

## 18. Megvalósítási napló — I6/2 (kép-csatolmány)

> **Az I6 két megmaradt tétele** (gépelés-jelző, keresés a szálban) **innen indul.**
> A kép az első nem-szöveges üzenettípus; a §18.4 szabályai minden továbbira
> vonatkoznak.

### 18.1 Mi készült el

**Backend**

| Réteg | Fájlok |
|---|---|
| Migráció | `V67__chat_attachments.sql`: `chat_message_attachments` tábla + `chat_messages.attachment_width/height/byte_size` + a `body` kötelezőségét felváltó `chat_messages_content_present` check |
| Entitás | `entity/ChatMessageAttachment`, `ChatMessage` + a három metaadat-mező, `hasAttachment()` / `clearAttachment()` |
| Repository | `repository/ChatMessageAttachmentRepository` |
| DTO | `dto/MessageAttachmentResponse`, `MessageResponse.attachment` |
| Szolgáltatás | `ChatServiceImpl.store(...)` (a szöveges és a képes küldés közös útja), `reencode(...)`, `findAttachment(...)`; a törlés a bájtokat is viszi |
| Végpontok | `POST /chat/conversations/{id}/messages` **multipart** változata, `GET /chat/messages/{id}/attachment` és `/attachment/thumbnail` (ETag-es feltételes GET) |
| Kép-pipeline | `ImageReencoder.boundedJpeg` (új, nem nagyít) |
| Egyéb | `ChatProperties` + `attachmentMaxBytes` / `attachmentMaxSide` / `attachmentThumbnailSize`, `exception/AttachmentTooLargeException` (413), a push törzse képnél „📷 Kép" / „📷 Photo" |

**Mobil**

| Réteg | Fájlok |
|---|---|
| Séma | **v33**: `chat_messages.attachment_width/height/byte_size/attachment_local_path`, `chat_conversations.last_message_has_attachment` |
| Domain | `ChatAttachment`, `ChatMessage.attachment` / `attachmentLocalPath` / `hasAttachment`, `ChatConversation.lastMessageHasAttachment` |
| Data | `ChatRepository.send(..., image:)`, multipart `_deliver` `onSendProgress`-szel, `_stageAttachment`, `fetchAttachment` (lemezes cache + ETag), `watchUploadProgress`, `clearAttachmentCache` |
| Presentation | `widgets/chat_attachment_view.dart` (buborék-kép + teljes képernyős néző `InteractiveViewer`-rel), `chat_composer` kép-gomb + forrás-lap + kiválasztott kép sávja, `message_bubble` kép + felirat, `conversation_tile` képes előnézet |
| Beépülés | `chatUploadProgressProvider`, kijelentkezéskori cache-ürítés az `auth_controller`-ben |

**Web**

| Réteg | Fájlok |
|---|---|
| Adatréteg | `api.postForm`, `chatApi.sendWithAttachment` / `attachment` / `attachmentThumbnail`, `queryKeys.chat.attachment*`, `types.ts` `MessageAttachmentResponse` + `ThreadMessage.localImageUrl` / `localFile` |
| Tiszta logika | `thread.ts`: `hasImage`, `isMessageSendable(raw, withImage)`, `MAX_ATTACHMENT_BYTES`, `ACCEPTED_IMAGE_TYPES`; `mergeMessages` átmenti a lokális előnézetet |
| Komponensek | `components/ChatAttachment.tsx` (thumbnail + lightbox), `ChatComposer` kép-gomb és előnézet-sáv, `MessageBubble` kép + felirat, `ConversationList` képes előnézet |
| i18n | 8 új kulcs mindkét nyelven (mobil: 9) |

Tesztek: backend **744** zöld (+8 új: metaadat és bájtok tárolása, felirat nélküli
kép, se szöveg se kép → 400, méretkorlát, ismételt küldés nem tölt fel újra,
résztvevőség-alapú letöltés, idegen szálra 404, törlés viszi a képet), web **151**
zöld (+3), mobil **598** zöld (+4: multipart küldés, felirat nélküli kép,
offline sorban álló kép újraküldése, elvetés törli a fájlt).

> ⚠️ **A Testcontainers-alapú integrációs tesztek nem futottak.** Ebben a
> környezetben a Docker démon nem indít konténert (a `docker` CLI listáz, de a
> `docker run` és a Testcontainers `DockerClientFactory` is végtelenül vár), ezért
> a `ChatFlowIntegrationTest` és a másik nyolc Testcontainers-osztály ki lett hagyva
> a futtatásból. **Ezzel együtt a `V67` migráció valódi Postgres ellen nem lett
> lefuttatva** — ez az első dolog, amit egy működő Docker mellett ellenőrizni kell.

### 18.2 Eltérések a tervtől — ezekkel kell dolgozni

| Terv | Valóság | Miért |
|---|---|---|
| `chat_messages.attachment_url` + `type` oszlop | **`chat_message_attachments` tábla** (bájtok) + három metaadat-oszlop a `chat_messages`-en | nincs objektumtár a projektben; a profilkép és a receptkép is bájtként él a DB-ben, és a chat nem vezet be új infrastruktúrát ehhez. A `type` oszlop elmaradt: egy `attachment` alobjektum megléte pontosan ugyanazt mondja meg, egy enum nélkül, ami ma egyértékű lenne |
| — | a kép **ugyanazon a végponton** megy, multipart tartalomtípussal | egy külön „csatolmány feltöltése" lépés nem-atomi lenne (üres buborék a másik oldalon, ha a második hívás elmarad), és saját idempotencia-történetet kívánna a `clientMessageId` mellé |
| — | a méretek a **`chat_messages`-en**, nem a bájtok mellett | a lista- és szál-lekérdezés minden sort beolvas; egy join a bájtokat tartó táblához vagy egy plusz kérés a kliensről ugyanazért az egy számpárért nem éri meg. A kliens ebből foglal helyet, mielőtt egyetlen bájt megérkezne |
| — | **`ImageReencoder.boundedJpeg`** (új metódus) | a meglévő `resizedJpeg` **felnagyít** — egy 200×120-as kép 1600×960 lett (a teszt fogta meg). Fix méretű profilkép-slotnál ez jó, egy chat-fotónál csak bájt. A meglévő hívókat nem érinti |
| — | a thumbnail **nem négyzetes**, hanem arányos | a buborék a valódi képarányt foglalja le, tehát egy közép-vágott négyzetet másodszor is levágna |
| „kliensoldali feltöltés-progressz" | **mobilon valódi százalék** (Dio `onSendProgress`), **weben határozatlan pörgő** | a web `fetch`-alapú API-kliense nem tud feltöltés-progresszt; egy `XMLHttpRequest`-ág új minta lenne egyetlen funkcióért. A helyi előnézet amúgy is azonnal látszik, tehát a különbség egy pörgő és egy szám között van, nem „látok valamit" és „nem látok semmit" között |
| — | a törlés a **bájtokat is törli** | egy tombstone, ami után a kép még letölthető, hazugság |
| — | mobilon a picked fájl **átmásolódik** az app dokumentum-könyvtárába | az `image_picker` cache-könyvtárát az OS bármikor felszabadíthatja; egy repülőn megírt üzenet napokig ott várna |
| — | `chat_conversations.last_message_has_attachment` (mobil séma) | a null előnézet eddig egyértelműen „törölt üzenet" volt; egy felirat nélküli kép ugyanúgy null törzsű, tehát kellett egy harmadik jel. A web nem kapott ilyen mezőt: ott a teljes `lastMessage` a kézben van |
| A design prompt: „Kép-csatolmány **csak** ha marad idő, külön, jelölten" | **nincs hozzá design-forrás** | a `42-chat-design-prompt.md` kifejezetten kizárta, és a `.dc.html` sem rajzolja. A megjelenés ezért a meglévő chat-nyelvből következik (ugyanaz a buborék, sugár, állapot-ikon készlet), új token nélkül. **Ha készül rá design, ez a szakasz az, amit felül kell írnia** |

### 18.3 Amit az I6/2 tudatosan nem szállít

Videó, hangüzenet, dokumentum-csatolmány, több kép egy üzenetben, kép-szerkesztés
küldés előtt, letöltés/megosztás a teljes képernyős nézőből. A gépelés-jelző és a
keresés a szálban változatlanul az I6 nyitott tételei.

**Egy ismert korlát.** Az `attachment` bájtjai a `chat_message_attachments`
táblában élnek, azaz **a Postgres-ben**, nem objektumtárban. Egy aktív edző-kliens
párnál ez napi néhány száz KB — elhanyagolható —, de a tábla monoton nő, és nincs
megőrzési szabály (§11/4 ugyanezt mondja a szövegre). Ha a méret valaha téma lesz,
a csere helye a `ChatMessageAttachment` + a két letöltő végpont, nem a küldési út:
a kliens szerződése (metaadat az üzeneten, bájt külön kérésben) ugyanaz marad
objektumtárral is.

### 18.4 Architektúra-döntések, amik kötik a következő lépéseket

1. **Egy üzenet = egy kérés.** A kép ugyanazon a `POST`-on megy, ugyanazzal a
   `clientMessageId`-vel, és a replay-ág **a bájtok feltöltése előtt** dönt. Aki új
   üzenettípust vezet be, ezt kövesse: ne legyen olyan állapot, amiben létezik egy
   üzenet, aminek a tartalma még úton van.
2. **A metaadat az üzeneten van, a tartalom külön kérésben.** Ez az, amitől a szál-
   lekérdezés olcsó marad és a kliens előre tud helyet foglalni. Bármilyen új
   tartalomtípus (hang, dokumentum) ugyanígy: egy kis, kötelezően jelenlévő
   leíró az üzenetben, a bájtok ETag-es GET mögött.
3. **A törlés a tartalmat is törli.** A `deleteMessage` a bájtokat is elviszi, a
   kliensek a lemezes cache-t is ürítik rá. Új tartalomtípusnál ez nem opcionális.
4. **A mobil outboxnak fájl-életciklusa is van.** A `pending` sor mellé tartozik egy
   `chat_outbox/<clientMessageId>.jpg`, amit a sikeres küldés, az elvetés és a
   kijelentkezés is takarít. Aki új, bináris tartalmú offline műveletet ír, ezt a
   hármat mind kösse be — különben a felhasználó privát fotói maradnak a lemezen.
5. **A felirat nélküli kép teljes értékű üzenet.** A `body` nullázható, ha van
   csatolmány (a DB check ezt kényszeríti ki), és minden felület (buborék, lista-
   előnézet, push, képernyőolvasó) külön ágon kezeli az „üres törzs" esetet.

---

## 19. Megvalósítási napló — I6/3 (gépelés-jelző)

> **Az I6 utolsó tétele** (keresés a szálban) **innen indul.** A `typing` az első
> frame, aminek nincs REST-megfelelője; a §19.4/1 mondja meg, miért szabad, és mire
> nem hivatkozhat egy következő.

### 19.1 Mi készült el

**Backend**

| Elem | Fájlok |
|---|---|
| Végpont | `POST /chat/typing` a `ChatStreamController`-ben (a `/presence` mellett), `dto/TypingRequest` |
| Frame | `ChatEvent.TYPING` + `ChatEvent.typing(...)`, `dto/TypingEventPayload` (`conversationId`, `userId`) |
| Logika | `ChatStreamService.typing(...)` / `Impl`: résztvevőség-guard → archív-ág → throttle → szórás **csak a peer felé** |
| Fék | `service/ChatTypingThrottle` (memóriában, `merge()`-dzsel, hogy két párhuzamos leütésből is egy menjen át) |
| Konfig | `ChatProperties.typingThrottle` (2 mp) és `typingTtl` (5 mp) + `application.yml` |

**Mobil**

| Elem | Hol |
|---|---|
| Küldés | `ChatRepository.sendTypingSignal`, `ApiEndpoints.chatTyping` |
| Állapot | `application/chat_typing_controller.dart`: `ChatTypingController` (szálanként egy lejárati timer) + `ChatTypingReporter` (3 mp-es throttle, szálváltásra nullázódik) |
| Bekötés | `ChatStreamController` `typing` ága egy `onPeerTyping` visszahíváson át — semmit nem ír a DB-be |
| UI | `chat_composer.dart`: `_TypingBand` (fix magasságú sáv) + `_TypingDots` (egy controller, dotonként eltolt fázissal) |

**Web**

| Elem | Hol |
|---|---|
| Küldés | `chatApi.typing`, `useReportTyping` (3 mp throttle, szálváltásra nullázódik) |
| Állapot | `hooks.ts`: `markPeerTyping` (a TTL-timer itt él) + `usePeerTyping`, `queryKeys.chat.typing` |
| UI | `ChatComposer` `TypingBand`-je + `@keyframes chat-typing-dot` a `globals.css`-ben |

Tesztek: backend **751** zöld (+7: a peer megkapja és a saját eszközök nem, archív
szálban elnyelve, idegen szálra 404, a throttle első/ismételt jelzése, szálankénti és
useronkénti ablak, nulla ablak = kikapcsolt fék, párhuzamos leütésekből pontosan egy
megy át), web **152** zöld (+1: `typing` frame-parse), mobil **605** zöld (+7: TTL
lejárat, a második frame kitolja a lejáratot, szálankénti jelölés, üres kiindulás,
throttle-ablak, szálváltás, frame-parse).

> ⚠️ Változatlanul igaz a §18.1 figyelmeztetése: **a Testcontainers-osztályok ebben a
> környezetben nem futnak** (a Docker démon nem indít konténert), ezért a
> `ChatFlowIntegrationTest` és nyolc társa ki van hagyva.

### 19.2 Eltérések a tervtől — ezekkel kell dolgozni

| Terv | Valóság | Miért |
|---|---|---|
| „throttle 3 mp" (kliens) | **kliensen 3 mp, szerveren további 2 mp** | egy leütés-vezérelt végpont a legkönnyebben hajtható az egész API-ban, és minden átengedett hívás egy frame valaki más socketjén. A `ChatRateLimiter` nem jó rá: az a küldési keretet fogyasztaná, amit a user valódi üzenetekre akar költeni |
| — | a frame **csak a peernek** megy, a küldő saját eszközeinek nem | a `message` és a `deleted` szándékosan megy a saját eszközökre is (ott van mit mutatni); a „te gépelsz" a saját második telefonodon zaj arról, amit épp csinálsz |
| — | **archív szálban elnyelve** | oda nem lehet írni, tehát senki nem gépel benne — és a `409`-et adó küldés mellett egy élő gépelés-jelző hazugság lenne |
| — | a jelző **fix magasságú sávban** ül, mindig a fában | a design D3 kifejezetten ezt írja („Fix magasságú sáv"), és van rá szerkezeti ok is: a szál alulra horgonyzott (mobilon `reverse: true` lista), tehát egy csak-gépeléskor létező sáv az egész beszélgetést fel-le lökné, ahányszor a másik fél elkezd és abbahagy |
| — | a TTL **a kliensek dolga**, a szerver nem tart nyilván semmit | a lejárat pontosan az, ami miatt ez az állapot elveszthető: nincs mit szinkronizálni, nincs mit visszakérdezni |
| — | a payload **nem hordoz nevet** | az egyetlen felület, ami kirajzolja, egy már nyitott szál, ami tudja, ki a peer |
| — | weben a TanStack Query cache a **csatorna** (`queryKeys.chat.typing`) | a stream az admin shellben él, a szál máshol; a cache az egyetlen meglévő út közöttük, és a `message`/`read` frame is ezen jut el a komponensekig (§14.4/1) |

### 19.3 Amit az I6/3 tudatosan nem szállít

Gépelés-jelző a **beszélgetés-listában** (csak a nyitott szálban látszik), „utoljára
aktív" idő, olvasás-jelző a composerben, és bármi, ami a **háttérben** futna: a mobil
stream előtér-kötött (§15.4/5), tehát háttérben nem érkezik és nem is megy `typing`.
Ez szándékos — az ellenkezője pont azt a szerződést bontaná meg, amitől a push
kézbesítési csatorna lesz.

Hátra az I6-ból a **keresés a szálban**.

### 19.4 Architektúra-döntések, amik kötik a következő lépéseket

1. **Ez az egyetlen frame, aminek nincs REST-megfelelője — és marad is az egyetlen.**
   A §15.4/1 szabálya („ne legyen olyan állapot, ami *csak* a streamen létezik") itt
   azért nem sérül, mert a gépelés **nem állapot**: lejár magától, elveszni sem tud
   értelmesen (egy elmaradt frame = nem jelenik meg a jelző = ugyanaz, mintha nem
   gépelne), és nincs mit egyeztetni újracsatlakozáskor. Bármi, aminek egy elveszett
   frame *következménye* van — üzenet, kurzor, törlés —, továbbra is köteles REST-ből
   is előállítható lenni.
2. **A gépelés soha nem értesít.** Nem megy át a `ChatNotificationServiceImpl`
   létráján, nem mozdít kurzort, nem számít olvasatlanba, nem ír adatbázist. Egy
   `typing` a szerveren nulla írás.
3. **A leütés-vezérelt végpontnak szerveroldali féke is van.** A kliens-throttle
   udvariasság, nem védelem. Aki új, felhasználói interakcióra kötött végpontot ír
   (reakció, „lát engem" jelzés), tegye ugyanezt: a fék a szerveren van, a kliensé
   ráadás.
4. **A TTL rövidebb az újraküldési ablaknál** (5 mp vs. 3 mp), és ez a sorrend
   szándékos: egy folyamatosan gépelő ember jelzője megújul, mielőtt lejárna, tehát
   nem villog mondat közben. Aki ezeket hangolja, tartsa meg a relációt.

---

## 20. Megvalósítási napló — I6/4 (keresés a szálban)

> **Ezzel az I6 teljes**, és a chat funkcionálisan is, kiterjesztéseivel együtt is
> kész. Hátra az **I7 (üzemeltetés és mérés)** van — belépőpontja a §12–§20.

### 20.1 Mi készült el

**Backend**

| Elem | Fájlok |
|---|---|
| Végpont | `GET /chat/conversations/{id}/messages/search?q=&before=&limit=` a `ChatMessageController`-ben, `MessageListResponse` válasszal |
| Lekérdezés | `ChatMessageRepository.searchInConversation` — `unaccent(lower(...)) like ... escape '!'`, tombstone-ok kizárva, `id desc` |
| Szolgáltatás | `ChatServiceImpl.searchMessages` (résztvevőség-guard, trim, minimum hossz, wildcard-escape, keyset + „van még" próbasor) |
| Konfig | `ChatProperties.searchMinLength` (2) + `application.yml` |

**Mobil**

| Elem | Hol |
|---|---|
| Adat | `ChatRepository.searchMessages` — **nem ír a lokális DB-be**, `ApiEndpoints.chatMessageSearch` |
| Állapot | `application/chat_search_controller.dart`: 300 ms debounce, generációszám a versenyző válaszok ellen, `failed` külön az „üres találat"-tól |
| Kiemelés | `domain/message_highlight.dart`: `foldForSearch` (1:1 karakter-leképezés) + `highlightSegments` |
| Képernyő | `presentation/chat_search_screen.dart` + `/chat/:conversationId/search` útvonal, belépő a szál app barjának nagyító ikonja |

**Web**

| Elem | Hol |
|---|---|
| Adat | `chatApi.searchMessages`, `queryKeys.chat.search` |
| Kiemelés | `thread.ts`: `highlightSegments` (NFD + diakritika-eltávolítás, index-térképpel) |
| UI | `components/ChatSearch.tsx` (debounce, üres/hiba/találat állapotok), a `ChatThread` fejléce keresőmezőre vált, a folyam helyére a találatok kerülnek |

Tesztek: backend **757** zöld (+6: keyset és „van még", wildcard-escape, trim,
rövid/üres term = üres oldal, idegen szálra 404) — plusz **5 integrációs teszt**, ami az
ékezet-érzéketlenséget, a tombstone-kizárást, a wildcard-escape-et és a lapozást
valódi Postgres ellen fogja; web **158** zöld (+6), mobil **616** zöld (+11: kilenc
kiemelés-eset és két repository-eset).

> ⚠️ **Az öt integrációs teszt nem futott le.** Ugyanaz a környezeti korlát, mint a
> §18.1-ben: a Docker démon itt nem indít konténert, ezért a `ChatFlowIntegrationTest`
> (és nyolc társa) ki van hagyva. **Ez itt jobban fáj, mint eddig**: az ékezet-kezelés
> és a wildcard-escape SQL-ben él, amit mock nem tud igazolni — a hozzájuk tartozó
> tesztek meg vannak írva, de futtatásuk a következő működő Docker melletti build
> feladata.

### 20.2 Eltérések a tervtől — ezekkel kell dolgozni

| Terv | Valóság | Miért |
|---|---|---|
| „`ILIKE` + **trigram index**, ha kell" | **nincs index** | a keresés mindig egy szálra szűkül (`idx_chat_msg_conv`), és egy szál reálisan pár ezer sor — azon a szekvenciális szűrés ingyen van. Egy GIN trigram index *minden* chat-üzenet szövegén viszont írási költség lenne minden küldésnél, mérhető olvasási nyereség nélkül. A terv „ha kell"-je pontosan ezt a döntést hagyta nyitva, és a válasz most: nem kell |
| `ILIKE` | **`unaccent(lower(...)) LIKE ... ESCAPE '!'`** | magyarul egy ékezet-érzékeny keresés használhatatlan („labnap" nem találná meg a „Lábnap"-ot). A `FoodRepository` már pontosan így csinálja a V48-as `unaccent` kiterjesztéssel — a chat nem vezet be új mintát. Az `escape` pedig azért kell, mert a beírt szöveg **keresőkifejezés, nem minta**: „50%" a százalékjelet keresi, nem mindent |
| — | rövid vagy üres term = **üres oldal, nem 400** | a kliensek gépelés közben keresnek; az első leütésre adott hibaválasz minden normál használatot hibafolyammá tenne |
| — | a találatok **nem kattinthatók** | lásd §20.3 |
| — | mobilon **külön képernyő** (`/chat/:id/search`), weben **a fejléc kereső-módja** | mindkettőn ugyanaz az ok, más csomagolással: a szál fordított, alulra horgonyzott keyset-ablak, a találatok pedig szórtak és fentről lefelé olvasandók. Weben a két hasáb miatt a fejléc-váltás elég; mobilon egy képernyőn két, egymásnak ellentmondó lista-modell lakna |
| — | a kiemelés **kliensenként más implementáció** (Dart tábla vs. JS NFD) | a Dartban nincs beépített Unicode-normalizálás, és egy csomagot behozni ezért az egy függvényért nem indokolt (`CLAUDE.md`). A magyar ábécére a két megoldás egyezik; a különbség egzotikus írásjeleknél lenne látható |

### 20.3 Amit az I6/4 tudatosan nem szállít

**Ugrás a találatról a szálba.** Ez a hiányzó darab, és szándékosan az: a szál egy
*folytonos* keyset-ablak (mobilon a Drift táblában, weben a query cache-ben), amit a
kliens a legfrissebbtől visszafelé lapoz. Egy régi találat megnyitásához vagy
végig kellene lapozni odáig (sok körbejárás), vagy be kellene tölteni egy szigetet a
találat köré — és egy lyukas ablakot a szál **szomszédosként** rajzol ki: rossz
nap-elválasztók, rossz feladó-csoportosítás, vagyis csendben hazudik a beszélgetésről.
Ez a helyes megoldás egy „hézag-tudatos" lista-modell, ami nagyobb változtatás, mint
maga a keresés volt.

Amit helyette kap a felhasználó: a találat **teljes szövegét**, a feladót, a pontos
időpontot és a kiemelt egyezést — a „mit írt erről?" kérdésre ez a válasz. A seam az
ugráshoz megvan: a szerver `before=<id>` kurzora már most tud a találat köré lapozni;
a kliensoldali lista-modell az, ami hiányzik hozzá.

Nem szállít továbbá: keresés **több szálon át** (a végpont szálra szűkített),
találatok lapozása („több eredmény" gomb — a szerver `hasMore`-t ad, a kliensek
egyelőre az első oldalt mutatják), keresés csatolmány-fájlnévre.

### 20.4 Architektúra-döntések, amik kötik a következő lépéseket

1. **A keresés ugyanaz a keyset, mint a szálé.** `before` + `hasMore`, `id desc`,
   ugyanaz a `MessageListResponse`. Aki lapozást tesz a találatokra, ne találjon ki
   új mechanikát — a szerver oldala már kész.
2. **Találat ≠ cache.** Sem a mobil Drift táblája, sem a web query cache-e nem kapja
   meg a találatokat. Ez nem óvatosság, hanem a folytonossági invariáns megőrzése:
   mindkét kliens egy összefüggő ablakként rajzolja ki, ami a tárolóban van. Bármilyen
   jövőbeli „üzenet betöltése id szerint" előbb ezt az invariánst kell rendezze.
3. **Egy nézet, egy lista-modell.** A keresés azért külön képernyő (mobil) illetve
   külön mód (web), mert a szál fordított és alulra horgonyzott, a találatok pedig
   nem. Ha később bejön egy harmadik lista (pl. csatolmány-galéria), az is a maga
   nézetét kapja, nem egy negyedik ág ugyanabban a `ListView`-ban.
4. **A beírt szöveg soha nem minta.** A `%` és `_` escape-elve megy be. Aki új
   `LIKE`-alapú keresést ír bárhol a projektben, ugyanezt tegye — a `FoodRepository`
   és a `RecipeRepository` ma **nem** teszi, és az egy meglévő, külön javítandó hiba,
   nem követendő minta.
5. **Az ékezet-kezelés a szerveré, a kiemelés a kliensé — és a kettőnek egyeznie
   kell.** Ha a szerver talál valamit, amit a kliens nem tud kiemelni, az hibának
   látszik. A `unaccent` és a kliensoldali folding együtt mozognak.

---

## 21. Megvalósítási napló — I7 (üzemeltetés és mérés)

> **Ezzel a terv végig van vezetve: I1–I7 kész.** A napi üzemeltetés
> belépőpontja innentől a **[devops/chat-operations.md](../../devops/chat-operations.md)**
> runbook — ez a szakasz azt rögzíti, mi készült el és miért így.

### 21.1 Mi készült el

| Elem | Fájlok |
|---|---|
| Metrikák | `ChatMetrics` — négy méter, előre regisztrált sorozatokkal; bekötve a `ChatServiceImpl` küldési útjába, a `ChatNotificationServiceImpl` teljes gát-létrájába és a `ChatUnreadReminderJob` két kézbesítési ágába |
| Kapcsolat-mérő | `lifey.chat.stream.connections` gauge a `ChatEmitterRegistry.connectionCount()` fölött — a §15.5 nyitva hagyott tétele |
| Kitettség | `management.endpoints.web.exposure.include: health,metrics`, és `/actuator/**` **`ROLE_SUPER_ADMIN`** mögé zárva a `SecurityConfig`-ban |
| Runbook | **`devops/chat-operations.md`** (új): kill switch, a négy méter olvasása, négy küszöb azzal együtt, hogy mit jelentenek, tünet→ok tábla, teljes konfig-referencia, skálázási figyelmeztetés — linkelve a `devops/README.md`-ből |
| Tesztek | `ChatMetricsTest` (4), `RoleBasedAccessControlTest` +2 (az actuator zárás) |

A négy méter:

| Méter | Típus | Címkék |
|---|---|---|
| `lifey.chat.messages.sent` | counter | `kind` = `text` \| `image` |
| `lifey.chat.stream.connections` | gauge | — |
| `lifey.chat.push.decisions` | counter | `outcome` = `sent` \| `skipped-viewing` \| `skipped-disabled` \| `skipped-quiet-hours` \| `skipped-muted` \| `skipped-coalesced` |
| `lifey.chat.reminders.sent` | counter | `channel` = `push` \| `email` |

Tesztek: backend **761** zöld (+4: minden sorozat létezik nullán, üzenetek
típusonként, push-döntések okonként, a gauge élőben olvas), és **+2 integrációs
teszt** az actuator jogosultságra. Mobil és web érintetlen — az I7 tisztán
szerveroldali.

> ⚠️ Ugyanaz a környezeti korlát, mint a §18.1/§20.1-ben: a Testcontainers-osztályok
> itt nem futnak, tehát a **két új actuator-jogosultsági teszt sem futott le.** Ezek
> pont azt igazolnák, hogy a `/actuator/metrics` nem publikus — **a legfontosabb
> ellenőrzés ebben az iterációban.** Egy működő Docker melletti buildnél ez az első.

### 21.2 Eltérések a tervtől — ezekkel kell dolgozni

| Terv | Valóság | Miért |
|---|---|---|
| „Ha addig többinstance-os lesz a backend: `PostgresChatEventBus` (LISTEN/NOTIFY)" | **nem készült el** | a feltétel nem teljesült: a `render.yaml` egy `web` service `starter` terven, egy instance. Egy `LISTEN/NOTIFY` implementáció ma nem oldana meg semmit, viszont egy új, hosszú életű DB-kapcsolatot és egy listener-szálat hozna egy 192 MB heapes konténerbe. A seam megvan; a runbook „Scaling out" szakasza megmondja, mikor kell elővenni — **és azt is, hogy a `@Scheduled` jobok duplázódása a súlyosabb probléma ott, nem a realtime** |
| „Riasztás-küszöbök" | **dokumentált küszöbök, nem konfigurált riasztások** | nincs riasztási platform ezen a deployon (se Prometheus, se Grafana). Egy „küszöb" ilyenkor az, amit egy ember tud megnézni: a runbook mindegyikhez megadja, mi a normális, mi a rossz, miért számít, és mi az első lépés |
| „Metrikák (Actuator/Micrometer, **már be van húzva**)" | igaz, de **semmi nem volt kitéve**: `exposure.include: health` | ezért az I7 érdemi része nem a mérés, hanem az **elérhetőség** volt — és az, hogy közben ne szivárogjon ki semmi. Megoldás: `metrics` kitéve, `/actuator/**` super-admin mögé zárva. A prefixre írt szabály miatt egy később kitett endpoint sem válhat véletlenül publikussá |
| — | **nincs `micrometer-registry-prometheus`** | nincs scraper, ami olvasná. A `/actuator/metrics` JSON-ja embernek olvasható, és pont ez a használati mód. A regisztrációs kód független ettől: ha lesz Prometheus, egy dependency és nulla kódváltozás |
| — | minden sorozat **előre regisztrálva**, nullán | egy csak-első-használatkor megjelenő számláló a legrosszabb fajta riasztáshoz: a „nincs adat" és a „nem történt semmi" ugyanaz a leolvasás lenne — és az érdekes eset (hirtelen minden push kimarad) épp az, amikor egy sorozat hiányozna |
| — | az e-mail fallback **továbbra is ki van kapcsolva** | a §16.3 szerint a bekapcsolás sorrendben az I7 *után* jön: előbb kellenek a számok. Most már megvannak — a runbook megírja, melyiket kell nézni hozzá (`reminders.sent{channel=push}`) és mit várj utána. Ez termékdöntés, nem kódmunka |

### 21.3 Amit az I7 tudatosan nem szállít

Riasztási platform (nincs mibe kötni), Prometheus/Grafana, tracing, a push
**kézbesítési** hibaarányának metrikája (az APNs/FCM válasza ma logban él, nem
méterben — a `PushService` a chat fölött van, és egy közös push-metrika a
push-modul saját iterációja lenne, nem a chaté), megőrzési szabály a chat-adatra
(§11/4 és §18.3), és a `PostgresChatEventBus`.

### 21.4 Architektúra-döntések, amik kötik a következő lépéseket

1. **Az `/actuator/**` super-admin mögött van, nem publikusan.** A szabály a
   *prefixre* szól, nem a ma kitett egyetlen endpointra: aki később kitesz még
   egyet az `exposure.include`-ban, az alapból zárt lesz. A `/actuator/health`
   marad publikus, mert a Render deploy-próbája azon múlik.
2. **A méterek neve és címkéi egy helyen élnek** (`ChatMetrics`). Egy elgépelt
   string a hívás helyén két külön idősorra hasítja a metrikát, és azt senki nem
   veszi észre. Aki chat-métert ad hozzá, oda adja hozzá.
3. **Minden sorozat létezik indulástól, nullán.** Ez a runbook küszöbeinek az
   előfeltétele. Új címke-értéknél (pl. egy hatodik push-kihagyási ok) a
   konstruktorban is fel kell venni.
4. **A push-döntés minden ága mér.** A `ChatNotificationServiceImpl` létrájának
   nincs olyan kilépési pontja, ami ne növelne számlálót — ettől olvasható az
   arány. Aki új gátat tesz a létrába (§16.4/1), adjon hozzá egy
   `PushDecision` értéket is, különben a kimaradás láthatatlanná válik.
5. **A runbook a művelet, a terv az indoklás.** Üzemeltetési változás
   (új küszöb, új lever) a `devops/chat-operations.md`-be megy; ide csak akkor,
   ha a *döntés* változik.
