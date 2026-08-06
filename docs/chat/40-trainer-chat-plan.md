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
> **Állapot (2026-08-06):** az **I1 (backend alap)** és az **I2 (mobil chat mindkét
> szerepkörben + push)** kész. A leszállított szerződést és a tervtől való eltéréseket a
> **[§12 (I1)](#12-megvalósítási-napló--i1-backend-alap)** és a
> **[§13 (I2)](#13-megvalósítási-napló--i2-mobil--push)** rögzíti.
> **A következő lépés az I3 (edzői web) vagy az I4 (realtime) — mindkettő belépőpontja
> a §12 + §13, illetve a [§10](#10-design) design-forrásai**
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

### I3 – Edzői web felület · ~3 nap

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

### I4 – Realtime (SSE) + jelenlét + kézbesítési állapotok · ~4 nap

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

### I5 – Értesítés-finomhangolás · ~2 nap

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

### I6 – Kiterjesztések (opcionális, igény szerint) · ~3 nap

- **Kép-csatolmány**: a meglévő kép-pipeline (`common/image`, `Thumbnailator`,
  profilkép/recept minta) újrahasznosítása; `chat_messages.attachment_url` + `type`
  oszlop, kliensoldali feltöltés-progressz.
- **Gépelés-jelző**: `POST /chat/typing` (throttle 3 mp) → `typing` SSE esemény, 5 mp TTL.
  Sose vált ki pusht.
- **Üzenet törlése** UI-ból (a backend már tudja I1 óta).
- **Keresés a szálban** (`ILIKE` + trigram index, ha kell).

### I7 – Üzemeltetés és mérés · ~1 nap

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
