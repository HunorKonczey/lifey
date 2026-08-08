# 44 – A chat kiemelése önálló szolgáltatásba (migrációs terv)

**Státusz:** terv, jóváhagyásra vár. Kód még nem készült hozzá.
**Előzmény:** [40-trainer-chat-plan.md](40-trainer-chat-plan.md) (a chat teljes terve, I1–I7),
[devops/chat-operations.md](../../devops/chat-operations.md) (üzemeltetés),
[devops/deploy-backend-render.md](../../devops/deploy-backend-render.md) (a mai deploy).
**Cél:** a `com.lifey.chat` modul kiemelése a `lifey-api` monolitból egy önálló,
Renderen külön futó Spring Boot szolgáltatásba (`lifey-chat`), a mobil és a web
kliens átállításával együtt.

---

## 0. Vezetői összefoglaló — mit javaslok

| Kérdés | Döntés | Hol |
|---|---|---|
| Kiemeljük-e a chatet? | **Igen**, de nem terhelés miatt — **blast radius**, eltérő erőforrás-profil és önálló deploy miatt | §1 |
| Mikor? | Előbb **M1** (határ-megkeményítés a monoliton belül) — ez önmagában is megéri. A tényleges kiemelés a §1.3 küszöbökhöz kötve | §1.3, §9 |
| Külön adatbázis? | **Nem az első fázisban.** Közös Neon DB, **külön Flyway-tulajdonjoggal** és szűk, read-only projekciókkal a `users` / `trainer_clients` felé | §4 |
| Postgres helyett más DB? | **Nem.** A mennyiség nem indokolja. A valódi tárolási probléma a `bytea` csatolmány → objektumtár, külön munka | §4.6 |
| Keretrendszer? | **Marad Spring Boot 4 / Java 24.** Egy második nyelv ára egy fejlesztőnél most nagyobb, mint a haszna | §1.4 |
| Repo | Monorepo marad, új gyökér-mappa: **`chat/`** (Maven artifact: `lifey-chat`) | §3 |
| Push és e-mail | **A monolitnál marad**, a chat HTTP-n hívja (`/internal/push`). Ok: a Firebase Admin SDK metaspace-igénye — így a chat service jóval kisebb JVM-mel elfut | §6 |
| Auth | Közös `JWT_SECRET`, a chat **csak validál**, tokent soha nem ad ki. Belső hívások külön S2S titokkal | §5 |
| Kliens-átállás | **Runtime konfigurálható chat base URL** a szerverről (`GET /api/v1/client-config`), nem compile-time konstans — különben nincs gyors rollback az App Store miatt | §7 |
| Költség | +1 Render Starter instance (a listaárat a cutover előtt ellenőrizni kell) | §8.4 |
| Becsült ráfordítás | **~10–14 fejlesztői nap**, 8 mérföldkőre bontva | §9 |

---

## 1. Miért, és mikor

### 1.1 Az érvek, erősségi sorrendben

Az előzetes álláspont (a beszélgetés-indítóban) ezt már felvázolta; itt a
kódból ellenőrzött formája.

1. **Blast radius.** Egy elszivárgó `SseEmitter` ma az *egész* API-t OOM-olja:
   edzésnapló, táplálkozás, auth, minden. A `devops/chat-operations.md`
   „Connection leak" pontja pontosan ezt írja le, és az elsősegély is ez:
   *restartold az egész API-t*. Külön szolgáltatásban a chat halála csak a chat
   halála.
2. **Eltérő erőforrás-profil.** A chat hosszú életű kapcsolatokat tart
   (`CHAT_STREAM_TIMEOUT=5m` ablakokban újranyitva), a többi modul kérés-válasz.
   Ma ugyanazon a 192 MB-os heapen és ugyanazon a Tomcat thread poolon
   osztoznak.
3. **Eltérő skálázási tengely.** A monolit *kérésre* skálázódik, a chat
   *párhuzamos kapcsolatra*.
4. **Ez a legönállóbb modul.** A csatolás gyakorlatilag egyirányú — lásd §2.
5. **Fordított irányú haszon, amit könnyű elfelejteni:** ha a chat kiválik,
   **a monolit szabadon skálázható 2+ instance-ra**, mert az egyetlen komponens,
   amit az `InMemoryChatEventBus` egy node-hoz köt, már nem benne fut. Ma ez a
   korlát az egész API-ra vonatkozik.

### 1.2 Ami *nem* érv

A terhelés. A mért 107 KB/SSE-kapcsolat mellett 10 000 párhuzamos chatelő
kellene ahhoz, hogy a memória téma legyen; 1:1 edző-kliens szálaknál ez nem
reális horizont. A `lifey.chat.stream.connections` gauge pont azért létezik
(I7), hogy ezt **adatból** és ne megérzésből lássuk.

### 1.3 Kiváltó küszöbök — mikor húzzuk meg a ravaszt

A kiemelés akkor induljon, ha az alábbiak **bármelyike** teljesül:

| # | Küszöb | Hogyan mérjük |
|---|---|---|
| K1 | `lifey.chat.stream.connections` napi csúcsa tartósan (2 hét) **> 300** | `GET /actuator/metrics/lifey.chat.stream.connections`, super-admin tokennel |
| K2 | Az API OOM-mal újraindul, és a chat érintett (a gauge magas volt az esemény előtt) | Render logs + a gauge trendje |
| K3 | **A chatet önállóan akarod deployolni** a többi API nélkül (pl. gyakori chat-iteráció, kockázatmentesen) | döntés, nem mérés — és önmagában is teljesen legitim ok |
| K4 | A monolitot 2+ instance-ra kell skálázni bármi más miatt | Render CPU/memória, válaszidők |

**K3 és K4 a valószínű valódi kiváltó ok**, nem K1. Ezt érdemes kimondani,
mert megkíméli a projektet attól, hogy egy sosem érkező forgalmi küszöbre várjon.

**Fontos:** az **M1 mérföldkő (határ-megkeményítés) küszöbtől függetlenül,
most is megéri.** Az a munka akkor is jobb kódot hagy maga után, ha a kiemelés
soha nem történik meg.

### 1.4 Miért marad Spring Boot

Ha nulláról terveznénk chatet, **Elixir/Phoenix** lenne az őszinte válasz
(BEAM-processzek KB nagyságrendben, Channels + Presence beépítve, elosztottan),
másodikként Go. De:

- A §15.5 mérés szerint **a Spring MVC SSE nem foglal szálat kapcsolatonként**
  (200 kapcsolatnál a JVM szálszáma nem nőtt) — a szokásos „a servlet-modell
  rossz erre" ellenérv itt empirikusan halott.
- Egy második nyelv ára egy fejlesztőnél: második toolchain, második CI, második
  deploy-runbook, második idióma-készlet, és a chat üzleti logikája (a §5
  push-gát-létra) *újraírandó*, nem átmozgatandó.
- A meglévő 16 backend teszt (`backend/src/test/java/com/lifey/chat/**`)
  átmozgatható; újraírandó lenne.

**A nyelvváltás akkor kerüljön újra elő, ha a chat kiválása után a Java-oldali
korlátok kimutathatóan szorítanak** — nem előbb.

---

## 2. A tényleges csatolás (kódból ellenőrizve)

### 2.1 Kifelé — mit használ a `com.lifey.chat` a monolitból

Az importok pontos száma (`grep -rh "^import com\.lifey" backend/src/main/java/com/lifey/chat`):

| Import | Db | Mire kell | Hova kerül M1 után |
|---|---|---|---|
| `com.lifey.user.User` | 8 | feladó/címzett, megjelenítendő név, e-mail, `utcOffsetMinutes` | `ChatUserDirectory` port |
| `com.lifey.common.domain.BaseEntity` | 4 | JPA infrastruktúra | másolat a chat service-ben |
| `com.lifey.settings.UserSettings` | 3 | `chatPushEnabled`, csendes órák, nyelv | `ChatNotificationPreferences` port |
| `com.lifey.settings.UserSettingsRepository` | 2 | ugyanaz | ugyanaz |
| `com.lifey.settings.LanguagePreference` | 2 | push szöveg nyelve | port DTO enum |
| `com.lifey.trainer.entity.TrainerClient` | 2 | **jogosultsági alap** | `ChatRelationshipGuard` port |
| `com.lifey.trainer.TrainerClientRepository` | 1 | ugyanaz | ugyanaz |
| `com.lifey.trainer.TrainerClientStatus` | 1 | `ACTIVE` szűrés | port DTO |
| `com.lifey.trainer.TrainerClientRevokedEvent` | 1 | archiválás visszavonáskor | **befelé jövő esemény** → §5.4 |
| `com.lifey.push.service.PushService` | 2 | értesítés | `ChatPushSender` port |
| `com.lifey.push.service.PushMessage` | 2 | ugyanaz | port DTO |
| `com.lifey.push.PushDeviceRepository` | 1 | „van-e egyáltalán eszköze" | `ChatNotificationPreferences.hasPushDevice` |
| `com.lifey.auth.CurrentUserProvider` | 2 | ki a hívó | `ChatCaller` port |
| `com.lifey.common.image.ImageReencoder` | 1 | csatolmány újrakódolás | `ChatImageProcessor` port |
| `com.lifey.mail.service.MailService` | 1 | e-mail fallback (ma **kikapcsolva**) | §6.3 — elhalasztva |
| `com.lifey.common.exception.ResourceNotFoundException` | 2 | infrastruktúra | másolat |

### 2.2 Befelé — mi hivatkozik a chatre

**Egyetlen dolog:** `com.lifey.common.exception.GlobalExceptionHandler` importál
5 chat-kivételt (`AttachmentTooLargeException`, `ChatDisabledException`,
`ChatRateLimitedException`, `ConversationArchivedException`,
`InvalidMessageBodyException`) a HTTP-státusz leképezéshez.

(A `MailService` grep-találata **álpozitív**: csak egy Javadoc-hivatkozás
`docs/chat/40-trainer-chat-plan.md §5.5`-re, nem kódfüggés.)

### 2.3 Adatbázis-szintű csatolás

A négy chat-tábla idegen kulcsai (V64, V67):

```
chat_conversations.trainer_client_id -> trainer_clients(id)
chat_conversations.trainer_id        -> users(id)
chat_conversations.client_id         -> users(id)
chat_messages.sender_id              -> users(id)
chat_participants.user_id            -> users(id)
chat_message_attachments.message_id  -> chat_messages(id) ON DELETE CASCADE
```

Ezen felül a V65 **a `user_settings` táblát bővíti** három chat-oszloppal
(`chat_push_enabled`, `chat_quiet_hours_start`, `chat_quiet_hours_end`) — ez a
tábla a monolité marad, a chat csak olvassa.

A keresés a Postgres `unaccent` kiterjesztésre épül (V48), a
`ChatMessageRepository` `function('unaccent', ...)` hívásain keresztül.

### 2.4 JPA-relációk, amiket M1-ben fel kell bontani

| Entitás | Mező | Ma | M1 után |
|---|---|---|---|
| `ChatConversation` | `trainerClient` | `@ManyToOne TrainerClient` | `Long trainerClientId` |
| `ChatConversation` | `trainer`, `client` | `@ManyToOne User` | `Long trainerId`, `Long clientId` |
| `ChatMessage` | `sender` | `@ManyToOne User` | `Long senderId` |
| `ChatParticipant` | `user` | `@ManyToOne User` | `Long userId` |

Ez a legnagyobb tömegű refaktor az egész tervben, és **viselkedés-változás
nélküli** kell hogy legyen. Érinti a repository-k JPQL-jeit is (`p.user.id`,
`m.sender.id` navigációk → sima oszlop-összehasonlítás), valamint a
`ChatMapper`-t, ami ma `User` objektumot kap (`displayName(User)`).

### 2.5 Rejtett csatolás, ami importból nem látszik

A `ChatNotificationServiceImpl` és a `ChatUnreadReminderJob` **`java.time.Clock`-ot
injektál**, és a projektben az egyetlen `Clock` bean-definíció a
`com.lifey.push.PushConfig`-ban van. Ez nem jelenik meg a `com.lifey.*`
import-listában (a típus JDK-s), de valódi Spring-kontextus-függés a push
modulra.

Ugyanez a mintázat máshol is előfordulhat — **M1 első lépése egy
kontextus-szintű ellenőrzés**: milyen bean-eket kap a `com.lifey.chat`, amiket
nem ő definiál. A `Clock` a chat service-ben saját `@Bean Clock clock()`-ot kap
(`Clock.systemUTC()`), a `ChatConfig`-ban.

---

## 3. Célállapot

### 3.1 Ábra

```
                    ┌───────────────────────────────────────┐
   mobil (Flutter)  │  GET /api/v1/client-config            │
   web  (Next.js)   │     → { chatBaseUrl: "..." }          │
        │           └───────────────────────────────────────┘
        │                          ▲
        │  minden nem-chat hívás   │
        ├──────────────────────────┴────────────► lifey-api  (Render, starter)
        │                                          com.lifey.{auth,user,trainer,
        │                                            settings,push,mail,...}
        │                                          + /internal/push  (S2S)
        │                                          + /internal/... (S2S)
        │                                                 │
        │  minden /chat/** hívás + SSE                     │ ugyanaz a
        └──────────────────────────────────► lifey-chat  │ Neon Postgres
                                              com.lifey.chat│
                                              (SSE, jobs)  ▼
                                                    ┌──────────────┐
                                                    │ Neon Postgres│
                                                    │  frankfurt   │
                                                    └──────────────┘
   írás:  lifey-api  → minden tábla, KIVÉVE chat_*
          lifey-chat → CSAK chat_* táblák
   olvasás: lifey-chat → users, user_settings, trainer_clients (szűk projekciók)
```

### 3.2 Repo-elrendezés

```
lifey/
├── backend/          # lifey-api            (változatlan hely)
├── chat/             # lifey-chat           ← ÚJ
│   ├── Dockerfile
│   ├── pom.xml
│   ├── mvnw, .mvn/
│   └── src/main/java/com/lifey/chat/...
├── mobile/
├── web/
├── watch/
├── devops/
├── docs/
└── render.yaml       # két service
```

**A `com.lifey.chat` csomagnév megmarad.** Így a fájlok átmozgatása
`git mv` + import-igazítás, nem újraírás, és a Git történet követhető marad
(`git log --follow`).

**Nem lesz közös Maven parent/shared modul** az első fázisban. Indoklás: egy
megosztott artifact azt jelenti, hogy a két deployable build-időben csatolt —
a chat nem deployolható, amíg a shared modul nem publikált. Egy fejlesztőnél ez
drágább, mint a duplikáció, ami konkrétan: `BaseEntity` (~20 sor),
`ResourceNotFoundException` (~10 sor), `JwtService.parseAccessToken` +
`JwtAuthenticationFilter` + `UserPrincipal` (~120 sor). Ha ez a lista valaha
100 sor fölé nő, akkor jöjjön a shared modul — előbb ne.

---

## 4. Adatbázis-stratégia

### 4.1 Döntés: közös DB, megosztott tulajdonjoggal

**Fázis A (a kiemeléskor): közös Neon adatbázis.**

- `lifey-chat` a `chat_conversations`, `chat_messages`, `chat_participants`,
  `chat_message_attachments` táblák **kizárólagos írója**.
- `lifey-chat` **read-only** hozzáféréssel olvassa a `users`, `user_settings`,
  `trainer_clients` táblákat — de **nem JPA entitásként**, hanem szűk,
  natív-lekérdezéses projekciókon keresztül (§4.4).
- `lifey-api` **soha nem ír** `chat_*` táblába a cutover után.

Ez tudatosan a „shared database" kompromisszum. Amit cserébe kapunk: nincs
adat-replikáció, nincs stale jogosultság, nincs S2S hívás a forró úton, a
meglévő idegen kulcsok érvényben maradnak, és az egész migráció **nulla
adatmozgatással** megy — a cutover pillanatában egyetlen sor sem költözik.

Amit vállalunk: a séma-változás fegyelme emberi szabály, nem gépi kényszer.
Ezt a §4.2 Flyway-hasítás teszi ellenőrizhetővé.

**Fázis B (opcionális, később): külön adatbázis** — §4.5. Nem része ennek a
tervnek, de a döntéseket úgy hozzuk, hogy ne zárja ki.

### 4.2 Flyway-tulajdonjog — ezt az első napon el kell dönteni

Két alkalmazás, amelyik ugyanarra a DB-re futtat Flyway-t, egymásnak megy.
A megoldás:

**A `lifey-chat` saját history táblát kap.**

```yaml
# chat/src/main/resources/application.yml
spring:
  flyway:
    table: flyway_schema_history_chat      # NEM a default flyway_schema_history
    locations: classpath:db/migration
    baseline-on-migrate: true
    baseline-version: 999                  # a már meglévő V64–V67 „megtörtént"
```

- A `lifey-chat` migrációi **`V1000__`-től** indulnak (`V1000`, `V1001`, …).
  Külön history táblában technikailag nem ütközhetnének, de a számtartomány
  elkülönítése emberi olvasónak azonnal megmondja, melyik migráció kié.
- A meglévő `V64__chat.sql`, `V65__user_settings_chat_push.sql`,
  `V66__chat_reminder.sql`, `V67__chat_attachments.sql` **a `backend/`-ben
  marad**, változatlanul. Nem törölhetők: a `flyway_schema_history` már
  rögzítette a checksumjukat, és egy friss környezet (lokális fejlesztés, teszt)
  ezekből építi fel a sémát.
- **Szabály, amit be kell tartani:** a cutover után a `backend/` alatt
  keletkező migráció **nem érintheti** a `chat_*` táblákat. A `user_settings`
  chat-oszlopai kivételt képeznek — az a tábla a monolité.

**Ellenőrző lépés a CI-ban:** [`devops/check-schema-ownership.sh`](../../devops/check-schema-ownership.sh)
(M2-ben elkészült). Mindkét irányt őrzi: a `backend/` migrációja nem nevezhet
meg `chat_*` táblát (a három történelmi kivételen túl), a `chat/` migrációja
pedig nem *írhat* a monolit tábláiba — hivatkozni rájuk (FK, select) szabad,
mert Fázis A pont így néz ki. A `--` kommenteket levágja, tehát a chat sémára
hivatkozó magyarázó szöveg nem bukik meg rajta.

#### 4.2.1 A baseline önmagában nem elég — üres adatbázison nincs chat séma

*(M2-ben derült ki; a fenti konfiguráció szükséges, de nem elégséges.)*

A `baseline-on-migrate` csak **nem üres** sémán csinál bármit is: beszúrja a
baseline sort, és onnantól a nála magasabb verziójú migrációkat futtatja. Éles
környezetben ez a helyes viselkedés — a `chat_*` táblák már ott vannak.

**Üres sémán viszont a Flyway egyszerűen migrál nulláról**, és mivel a chat
service migrációi `V1000`-nél kezdődnek, *a chat táblák soha nem jönnek létre*.
Ez nem elméleti: pontosan ez az M3 két környezete — a lokális fejlesztés és a
chat service saját Testcontainers-tesztjei.

**Megoldás:** a chat service első migrációja legyen **idempotens baseline**:

```sql
-- chat/src/main/resources/db/migration/V1000__chat_baseline.sql
-- Éles adatbázison no-op (a táblák a monolit V64/V66/V67-jéből már léteznek);
-- friss adatbázison ez hozza létre őket. Ugyanaz a séma, kétféle úton.
create table if not exists chat_conversations ( ... );
```

**A második buktató ugyanitt:** a `chat_*` táblák idegen kulcsai a `users` és
`trainer_clients` táblákra mutatnak, amik egy chat-only adatbázisban nem
léteznek. Ezért a baseline **nem lehet a V64/V66/V67 sima másolata**.

Döntés: az FK-k **maradjanak** a baseline-ban (éles környezetben úgyis
léteznek, és Fázis A-ban a hivatkozási épség a DB dolga), a chat service
tesztjei pedig kapjanak egy **teszt-only migrációt**, ami a monolit három
tábláját csonkolt formában létrehozza:

```
chat/src/test/resources/db/migration-test/V1__monolith_stub.sql
    users            (id, email, first_name, last_name, utc_offset_minutes)
    user_settings    (user_id, chat_push_enabled, chat_quiet_hours_*, language)
    trainer_clients  (id, trainer_id, client_id, status)
```

Ezekre a `ChatUserDirectory` / `ChatNotificationPreferences` /
`ChatRelationshipGuard` JDBC-implementációinak (§4.4) amúgy is szükségük van
teszteléshez, tehát nem többletmunka, hanem ugyanaz a munka.

**M3-ban ez a három fájl az első feladat**, mielőtt bármi más átmozgatásra
kerülne — különben a tesztek zöldnek látszanak úgy, hogy nincs mit tesztelniük.

### 4.3 Adatbázis-felhasználók és jogosultságok

Két külön DB-user, nem egy közös:

```sql
-- Egyszeri, kézzel a Neon konzolon vagy psql-ből.
create user lifey_chat with password '<generált>';

-- A chat saját táblái: teljes jog.
grant select, insert, update, delete on
    chat_conversations, chat_messages, chat_participants, chat_message_attachments
    to lifey_chat;
grant usage, select on sequence
    chat_conversations_id_seq, chat_messages_id_seq,
    chat_participants_id_seq, chat_message_attachments_id_seq
    to lifey_chat;

-- A monolit táblái: CSAK olvasás. Ez a gépi kényszer a §4.1 szabály mögött.
grant select on users, user_settings, trainer_clients to lifey_chat;

-- A Flyway history táblához kell CREATE jog a sémán.
grant create on schema public to lifey_chat;
```

Ez az egyetlen pont, ahol az „olvasás-írás" határ **nem** csak dokumentáció:
ha a chat service bármikor `users`-be próbálna írni, a Postgres visszautasítja.

### 4.4 A monolit tábláinak olvasása a chat service-ből

**Nem** másoljuk át a `User`, `UserSettings`, `TrainerClient` entitásokat.
Helyette a §5.2 portok chat-oldali implementációja három szűk, natív
lekérdezés:

```java
// chat/src/main/java/com/lifey/chat/spi/jdbc/JdbcChatUserDirectory.java
// A monolit users táblájának NÉGY oszlopa, semmi több. Nem entitás: nincs
// JPA-mapping, nincs lazy loading, és egy users-séma bővítés nem tud
// eltörni semmit a chatben.
private static final String FIND = """
    select id, first_name, last_name, email, utc_offset_minutes
    from users where id = any(?)
    """;
```

Ugyanígy `user_settings` (5 oszlop: `chat_push_enabled`,
`chat_quiet_hours_start`, `chat_quiet_hours_end`, `language`, + `user_id`),
`trainer_clients` (4 oszlop: `id`, `trainer_id`, `client_id`, `status`), és
`push_devices` (csak `exists`-lekérdezés).

**Ezt a felületet szerződésként kell kezelni.** Konkrétan: a `backend/`-ben
ezen öt oszlop-készlet átnevezése/törlése törő változás a chat service-re
nézve. M2-ben kerüljön egy megjegyzés az érintett migrációkhoz és entitásokhoz.

### 4.5 Ha később mégis külön DB kell (Fázis B, nem most)

Amit előre el kell rontani ahhoz, hogy ez később mechanikus legyen — és amit
ez a terv **nem** ront el:

1. A JPA-relációk már M1-ben ID-vé alakulnak (§2.4) → az entitások nem
   igényelnek `users` táblát ugyanabban a DB-ben.
2. A `users` / `trainer_clients` olvasás már portok mögött van (§5.2) → az
   implementáció JDBC-ről HTTP-re vagy eseményvezérelt replikára cserélhető
   anélkül, hogy a `ChatServiceImpl` egy sora változna.
3. Az FK-k eldobása egyetlen migráció:
   ```sql
   alter table chat_conversations drop constraint chat_conversations_trainer_id_fkey;
   -- ... a többi négy ugyanígy
   ```
   Ekkortól a hivatkozási épséget a szolgáltatás garantálja, nem a DB. Egy
   törölt user árva chat-sorokat hagy → kell egy takarító mechanizmus (GDPR-
   törlés eseményre iratkozva). **Ez az igazi ára a külön DB-nek**, és pontosan
   ezért nincs benne az első fázisban.

### 4.6 Van-e a Postgresnél alkalmasabb DB chatre? — Nincs, ebben a méretben

- A keyset lapozás `(conversation_id, id desc)` szerint és a monoton
  olvasás-kurzorok pont az, amiben egy btree jó.
- A `sendMessage` egyetlen tranzakcióban ír hármat (üzenet + a denormalizált
  `chat_conversations.last_message_*` előnézet + a küldő kurzora). Ez valódi
  érték, amit egy eventually-consistent store-ban vissza kellene építeni.
- Nagyságrend: egy aktív edző 100 klienssel × 20 üzenet/nap ≈ **730 ezer sor/év**.
  A Postgres ezt nem veszi észre.
- Cassandra/ScyllaDB (a „Discord-válasz") napi milliós üzenetszámnál és nagy
  csoportos fan-outnál kezd nyerni. 1:1 szálaknál egyik sem áll fenn.

**A valódi tárolási probléma nem az üzenet, hanem a csatolmány.** A
`chat_message_attachments.image`/`thumbnail` `bytea` oszlopok duzzasztják a
backupot és a Neon-számlát. A válasz erre **objektumtár (S3/R2)**, nem másik
adatbázis — és ez **külön munka, nem ennek a tervnek a része** (lásd terv §18.3).
Ha mégis egyszerre csinálnánk, az a cutover kockázatát duplázza; ne tegyük.

Egy megjegyzés a sorrendhez: ha az objektumtár *előbb* készül el, a chat
service kiemelése olcsóbb lesz (nincs több MB-os bájt a JVM-en át). Ha
*később*, akkor a chat service lesz a természetes hely neki. Mindkét sorrend
működik; a fordítottja (egyszerre) nem.

---

## 5. Határok: portok, auth, jogosultság

### 5.1 A vezérelv

**A chat definiálja az interfészeket, a monolit implementálja őket.**
(Dependency Inversion.) Ettől M1 után a `com.lifey.chat` csomag egyetlen
sora sem importál `com.lifey.{user,trainer,settings,push,mail,auth}`-ból, és a
kiemelés annyi, hogy az interfészek átmennek a chat service-be, ahol új
(JDBC vagy HTTP) implementációt kapnak.

Az interfészek helye: **`com.lifey.chat.spi`**.

### 5.2 A hét port

```java
package com.lifey.chat.spi;

/** Ki a hívó. Ma: CurrentUserProvider. Kiválás után: a chat saját JWT-filtere. */
public interface ChatCaller {
    Long currentUserId();
}

/** A megjelenítéshez és a csendes órákhoz kellő user-adat. Semmi több. */
public interface ChatUserDirectory {
    Optional<ChatUser> find(Long userId);
    Map<Long, ChatUser> findAll(Collection<Long> userIds);   // batch: a lista-nézet miatt
}
public record ChatUser(Long id, String displayName, String email, int utcOffsetMinutes) {}

/** A push-gát-létra bemenetei (terv §5.2). */
public interface ChatNotificationPreferences {
    ChatPushPrefs load(Long userId);
}
public record ChatPushPrefs(
        boolean pushEnabled,
        LocalTime quietHoursStart,
        LocalTime quietHoursEnd,
        boolean hungarian,
        boolean hasRegisteredDevice) {}

/** A jogosultsági alap: van-e aktív edző-kliens kapcsolat. */
public interface ChatRelationshipGuard {
    Optional<ChatRelationship> findActive(Long trainerClientId);
    Optional<ChatRelationship> findActiveBetween(Long userA, Long userB);
    List<ChatRelationship> findActiveForUser(Long userId);
}
public record ChatRelationship(Long id, Long trainerId, Long clientId) {}

/** Értesítés-kiküldés. Soha nem dob (a mai PushService szerződése). */
public interface ChatPushSender {
    void send(Long userId, ChatPushNotification notification);
}
public record ChatPushNotification(String title, String body,
                                   Map<String, String> data, String collapseKey) {}

/** Csatolmány újrakódolás. Ma: common.image.ImageReencoder. */
public interface ChatImageProcessor {
    ChatEncodedImage reencode(byte[] source, int maxSide);
}
public record ChatEncodedImage(byte[] bytes, String contentType, int width, int height) {}

/** Az e-mail fallback (ma kikapcsolva). Lásd §6.3. */
public interface ChatMailSender {
    void sendUnreadChatEmail(Long userId, long unreadCount, String peerName);
}
```

A monolit-oldali implementációk (M1-ben) a *hívott* modulban laknak, nem a
chatben — így a függés iránya a csomagfán is látszik:

```
com.lifey.auth.ChatCallerAdapter              implements ChatCaller
com.lifey.user.ChatUserDirectoryAdapter       implements ChatUserDirectory
com.lifey.settings.ChatPreferencesAdapter     implements ChatNotificationPreferences
com.lifey.trainer.ChatRelationshipGuardAdapter implements ChatRelationshipGuard
com.lifey.push.ChatPushSenderAdapter          implements ChatPushSender
com.lifey.common.image.ChatImageProcessorAdapter implements ChatImageProcessor
com.lifey.mail.ChatMailSenderAdapter          implements ChatMailSender
```

Kiválás után ugyanezek a portok a chat service-ben kapnak implementációt:
`ChatCaller` → a saját JWT-filter, `ChatUserDirectory`/`ChatNotificationPreferences`/
`ChatRelationshipGuard` → JDBC projekciók (§4.4), `ChatPushSender`/`ChatMailSender`
→ HTTP-kliens a monolit `/internal/**`-jához, `ChatImageProcessor` → a
`ImageReencoder` másolata.

### 5.3 JWT a határon át

**Döntés: közös HS256 titok, a chat csak validál.**

- A `lifey-chat` ugyanazt a `JWT_SECRET`-et kapja env-ből, mint a `lifey-api`.
- A `lifey-chat` **soha nem ad ki tokent**: nincs benne `AuthController`,
  nincs refresh-token tábla, nincs `generateAccessToken`. Csak
  `parseAccessToken` + a `UserPrincipal` felépítése a claimekből
  (`sub`, `email`, `roles`).
- A `JwtAuthenticationFilter`, `JwtService.parseAccessToken`, `UserPrincipal`,
  `JwtAuthenticationEntryPoint`, `JwtAccessDeniedHandler` **másolatként**
  költözik (~120 sor, §3.2 indoklás).
- **Szerződés, amit dokumentálni kell:** algoritmus HS256, `sub` = user id
  (Long, stringként), `roles` = `List<String>` az enum neveivel, `iss` =
  `lifey.jwt.issuer`. Ha ezek bármelyike változik a monolitban, a chat service-t
  ugyanazon deployban kell frissíteni.

**Miért nem JWKS/RS256?** Mert a titokrotáció ma nem megoldott probléma
(egyetlen `JWT_SECRET` env var), és az aszimmetrikus váltás önmagában egy külön
munka a monolitban. Ha valaha harmadik szolgáltatás jön, akkor kerüljön elő
újra.

**Aminek működnie kell a cutover után:** a kliens a chat service 401-ére a
**monolit** `/auth/refresh`-ét hívja, majd újrapróbálja a chat-hívást. §7-ben
konkrétan.

### 5.4 Jogosultság a határon át — a legkényesebb pont

A chat ma közvetlenül olvassa a `trainer_clients` táblát, és egy
`@EventListener`-rel (`ChatArchiveListener`) reagál a `TrainerClientRevokedEvent`-re,
**a revoke tranzakcióján belül**. Ez a rész a kiválással elveszti a
tranzakciós garanciáját. Három rétegű válasz:

**1. réteg — szinkron olvasás a küldés útján.**

> ⚠️ **Javítva M3-ban (§17.4.5).** Ez a pont eredetileg azt állította, hogy a
> védelem *már megvan*, mert a `sendMessage` a guardon megy át. **A kódban nem
> így van:** `ChatServiceImpl.store()` a résztvevőséget és a
> `conversation.archivedAt` mezőt nézi, a `trainer_clients` táblát nem érinti —
> a guardot csak a szál *megnyitása* használja. A küldést ténylegesen az
> `archived_at` flag állítja meg.

Mivel közös a DB, a `ChatRelationshipGuard` JDBC-implementációja **ugyanazt az
igazságot látja**, mint a monolit, késleltetés nélkül — ezt a lehetőséget viszont
ki kell használni, nem adott. **M4 feladata**: egy
`relationshipGuard.findActive(conversation.trainerClientId)` hívás a küldés
útján, indexelt point-lookup, üzenetenként egy lekérdezés. Ettől lesz igaz, hogy
Fázis A-ban nincs stale ablak — és ez a réteg az, ami a 2. réteg (webhook)
elvesztésére is fedezetet ad.

**2. réteg — archiválási értesítés (a `chat_conversations.archived_at` beírásához).**
Az archiválás egy *írás* a chat táblájába, amit a monolit már nem végezhet el.
A monolit ezért a revoke után értesíti a chatet:

```
POST {CHAT_URL}/internal/relationships/{trainerClientId}/revoked
X-Lifey-Internal: <S2S titok>
```

`@TransactionalEventListener(phase = AFTER_COMMIT)`-ből, hogy egy visszagörgetett
revoke ne archiváljon élő szálat. **Ez a hívás elveszhet** (a chat épp
újraindul, hálózati hiba) — ezért:

**3. réteg — egyeztető söprés.** A chat service napi egyszer lefuttat egy
lekérdezést, ami megkeresi azokat a `chat_conversations` sorokat, ahol
`archived_at is null`, de a hozzájuk tartozó `trainer_clients.status != 'ACTIVE'`,
és archiválja őket. Fázis A-ban ez egyetlen join:

```sql
update chat_conversations c
   set archived_at = now()
  from trainer_clients tc
 where c.trainer_client_id = tc.id
   and c.archived_at is null
   and tc.status <> 'ACTIVE';
```

**Következmény, amit ki kell mondani:** *ha* az 1. réteg megvalósul (M4), a
legrosszabb eset Fázis A-ban az, hogy egy archiválandó szál `archived_at` nélkül
marad legfeljebb egy napig — küldeni **akkor sem lehet bele**, mert a küldés a
guardon megy át. A szál „aktívnak" *látszik* a kliens listájában: kozmetikai
hiba, nem jogosultsági.

**Az 1. réteg nélkül viszont** a webhook elvesztése azt jelenti, hogy egy
visszavont kapcsolat szálába a napi söprésig lehet írni. **Ezért M6 (cutover)
előfeltétele, hogy az 1. réteg meglegyen** — nem opcionális megkeményítés.

Fázis B-ben (külön DB) ez a garancia elveszik, és a válasz vagy egy rövid TTL-es
cache + szinkron ellenőrzés, vagy egy kimenő outbox tábla a monolitban. **Ez a
Fázis B legdrágább tétele**, és külön tervet érdemel, ha valaha sorra kerül.

### 5.5 Service-to-service auth

A `/internal/**` végpontok mindkét irányban közös titkot használnak:

```
X-Lifey-Internal: <LIFEY_INTERNAL_TOKEN>
```

- Egy `OncePerRequestFilter`, ami **konstans idejű** összehasonlítást végez
  (`MessageDigest.isEqual`), és 401-et ad hiány/eltérés esetén.
- A `SecurityConfig`-ban `/internal/**` a `PUBLIC_ENDPOINTS` *előtt* kap saját
  szabályt: `.requestMatchers("/internal/**").permitAll()` + a filter dönt —
  vagy tisztábban, egy második `SecurityFilterChain` `@Order(1)`-gyel, ami csak
  a `/internal/**`-ra illeszkedik.
- **Ne legyen `/api/v1/` prefixe.** Így egy esetleges publikus reverse proxy
  szabály (`/api/**`) nem engedi át véletlenül, és a Swagger sem hirdeti.
- A titok ugyanaz mindkét service-en, `sync: false` a `render.yaml`-ben.

---

## 6. Push, e-mail, ütemezett munkák

### 6.1 A push a monolitnál marad — és ez mért döntés

A `backend/Dockerfile` megjegyzése konkrétan rögzíti: a Firebase Admin SDK
(gRPC + protobuf + Google API client) annyi osztályt tölt be, hogy **96 MB
metaspace-szel a JVM `OutOfMemoryError: Metaspace`-szel halt meg indulás
közben**, ezért kapott 192 MB-ot.

Ha a push a monolitnál marad, a `lifey-chat` JVM-nek **nincs Firebase SDK-ja**.

**Mért értékek (M3, §17.4)** — az eredetileg becsült 96m metaspace **kevésnek
bizonyult**, a szolgáltatás elindult vele és az első kérésen meghalt:

| | `lifey-api` | `lifey-chat` (mért) |
|---|---|---|
| `-Xmx` | 192m | **192m** |
| `MaxMetaspaceSize` | 192m | **128m** (mért csúcs: 99 MB, prod profillal, minden végpont megkopogtatva) |
| `ReservedCodeCacheSize` | 48m | 48m |
| `MaxDirectMemorySize` | 32m | 32m |
| jar mérete | 126 MB | **66 MB** |

A haszon tehát valós, csak kisebb a reméltnél: **64 MB metaspace-megtakarítás**,
nem 96. A heap 192m maradt (nem 256m): egy SSE-kapcsolat 107 KB (§15.5 mérés),
tehát 200 párhuzamos chatelő ~21 MB — nem a kapcsolatok töltik meg a heapet.

A chat oldali implementáció:

```java
// chat/.../spi/http/HttpChatPushSender.java
POST {LIFEY_API_URL}/internal/push
X-Lifey-Internal: <titok>
{ "userId": 42, "title": "...", "body": "...",
  "data": {"type":"chat_message","conversationId":"7"}, "collapseKey": "chat-7" }
```

A monolit oldalon ez egy vékony controller a meglévő `PushService` fölött —
**nem chat-specifikus**, bármelyik jövőbeli szolgáltatás használhatja.

**Hibakezelés:** a `PushService` szerződése ma az, hogy soha nem dob. A HTTP
változatnak ugyanígy kell viselkednie: timeout (2s connect, 5s read), a hibát
logolja és nyeli. Egy push elvesztése kellemetlen, de a §5.4 emlékeztető-job a
biztonsági háló — ami a chat service-ben fut, tehát a hálózati hiba esetén is
működik.

### 6.2 A `lifey.chat.push.decisions` metrika a chat service-ben marad

Az egész gát-létra (jelenlét → master kapcsoló → csendes órák → némítás →
összevonás) chat-logika, és a chat service-ben fut. Csak az utolsó lépés — a
tényleges kiküldés — megy HTTP-n. A metrikák így nem esnek szét: az
`outcome=sent` továbbra is azt jelenti, hogy „a chat úgy döntött, megzavarjuk".

### 6.3 Az e-mail fallback: elhalasztva

A `CHAT_EMAIL_FALLBACK_ENABLED` ma `false`, és a kód **soha nem futott
élesben** (terv §16.1). A kiemeléskor a `ChatMailSender` port implementációja a
chat service-ben legyen egy **no-op**, ami logol, a flag pedig maradjon `false`.

Így a `MailService` függés a kiváláskor egyszerűen megszűnik, ahelyett hogy egy
soha nem használt HTTP-utat építenénk hozzá. Ha később bekapcsolnánk, akkor
kerüljön be egy generikus `POST /internal/mail/send` a monolitba —
`{userId, subject, bodyHtml}` —, és a szöveget a chat service rendereli.

### 6.4 A `ChatUnreadReminderJob` és a duplafutás

A job a chat service-be költözik (`JOB_CHAT_UNREAD_REMINDER_CRON`, 5 percenként).
A chat service **egy instance**, tehát lock nem kell — de ez a feltevés a
`render.yaml`-ben és a doksiban is legyen kimondva, mert az instance-szám
felemelése azonnal duplikált emlékeztetőket okoz.

Ha valaha 2+ instance kell, a legolcsóbb megoldás **új dependency nélkül** egy
Postgres advisory lock a job elején:

```java
// A lock a tranzakció végén automatikusan felszabadul (pg_advisory_xact_lock).
// A "try" változat azonnal false-t ad, ha másik node már fut — nem várakozik.
Boolean acquired = jdbcTemplate.queryForObject(
        "select pg_try_advisory_xact_lock(?)", Boolean.class, CHAT_REMINDER_LOCK_KEY);
if (!Boolean.TRUE.equals(acquired)) {
    return;   // másik instance viszi ezt a tickset
}
```

(A ShedLock ugyanezt adja plusz egy dependency-vel és egy táblával. A projekt
szabálya szerint új keretrendszer indoklást igényel; 6 sorért nem éri meg.)

**A cutover alatt viszont a duplafutás valós veszély** — §10.3 percre lebontva
kezeli.

### 6.5 Realtime a szétvágás után

Az `InMemoryChatEventBus` **változatlanul marad**, mert a chat service egy
instance-on fut. A `ChatEventBus` interfész továbbra is a dokumentált seam.

Ha a chat service maga skálázódik 2+ instance-ra, a `ChatEventBus`
Postgres `LISTEN/NOTIFY` implementációja a következő lépés (terv §2, §9,
`devops/chat-operations.md` → Scaling out). Ez a terv ezt **nem** tartalmazza,
mert egy ismeretlen jövőbeli terhelésre írt kód.

---

## 7. Kliens-oldal

### 7.1 A legfontosabb döntés: a chat base URL runtime jöjjön

A mobil app `ApiConfig.baseUrl`-je ma **compile-time konstans**
(`String.fromEnvironment('API_BASE_URL')` + egy beégetett produkciós URL).
Ha a chat URL-je is így kerülne be, **a rollback egy App Store review-kört
jelentene** — 1-3 nap alatt, egy éles chat-hiba közepén. Ez elfogadhatatlan.

**Megoldás: a szerver mondja meg.**

```
GET /api/v1/client-config          (a monoliton, autentikált)
200 {
  "chatBaseUrl": "https://lifey-chat.onrender.com/api/v1",
  "configTtlSeconds": 300
}
```

- A monoliton egy env var vezérli: `CHAT_PUBLIC_BASE_URL`. **Üres érték = a
  chat a monoliton van** → a kliens a saját base URL-jét használja a
  chat-hívásokhoz is. Ez a rollback kapcsoló: egy env-változás Renderen.
- A kliens **indításkor** és a TTL lejártakor kéri le, `SharedPreferences`-be
  (mobil) / memóriába (web) cache-eli.
- **Hibatűrés:** ha a hívás elbukik vagy a válasz hiányos, a kliens a monolit
  base URL-jére esik vissza. Egy leállt config-végpont nem törheti el a chatet.
- A cutover előtt a TTL-t 300 másodpercre állítjuk (gyors terjedés), utána
  vissza 6 órára (kevesebb felesleges hívás).

**Ez a végpont önmagában is hasznos** a jövőben (feature flag-ek, karbantartási
üzenet), de most tartsuk egy mezőre.

### 7.2 Mobil (Flutter) — konkrét változások

| Fájl | Változás |
|---|---|
| `mobile/lib/core/network/api_config.dart` | `chatBaseUrl` getter, ami a runtime configból olvas; fallback `baseUrl` |
| `mobile/lib/core/network/dio_client.dart` | **Új `chatDioProvider`**: külön `Dio` példány, `baseUrl` a chat URL, de **ugyanaz az `AuthInterceptor`** (ugyanaz a `tokenStorage`, ugyanaz a `refreshDio`, ami a *monolithoz* megy) |
| `mobile/lib/core/network/` (új) | `client_config_repository.dart` — a §7.1 lekérés + cache |
| `mobile/lib/features/chat/data/chat_repository.dart` | a `chatDioProvider`-t kapja a `dioClientProvider` helyett |
| `mobile/lib/features/chat/data/chat_stream_client.dart` | ugyanaz — a `ChatStreamClient` konstruktora már ma is `Dio`-t kap, tehát csak a provider-bekötés változik |
| `mobile/lib/features/chat/data/trainer_clients_repository.dart` | **NEM változik.** Ez a fájl a chat feature-ben van, de a `/trainer/clients` végpontot hívja, ami a monoliton marad. Ezt könnyű elrontani. |

**Amit az `AuthInterceptor`-ban ellenőrizni kell:** a 401-re induló refresh a
`refreshDio`-t használja (monolit base URL), és a sikeres refresh után az
*eredeti* kérést ismétli — ami most már egy másik hostra megy. A mai
implementáció a `mainDio`-t kapja meg a retry-hoz; ez az egy hely, ahol a
retry-nak a **kérés saját** Dio-ját kell használnia, nem egy beégetettet.
**M5 első feladata ennek átnézése.**

**Az SSE újracsatlakozás:** a `ChatStreamClient` ma `disconnect()`/`connect()`
párral kezelhető. A config-változásra (base URL váltás) a stream-controllernek
újra kell csatlakoznia — különben a felhasználó a régi hostra kötve marad a
következő app-indításig.

**Offline outbox:** nem változik. A `clientMessageId` idempotencia ugyanúgy
működik, csak más hoston.

**Push deeplink:** nem változik — a payload (`type: chat_message`) a chat
service-ből ugyanaz.

### 7.3 Web (Next.js) — konkrét változások

| Fájl | Változás |
|---|---|
| `web/src/lib/env.ts` | új, opcionális `NEXT_PUBLIC_CHAT_BASE_URL` (fallback: `NEXT_PUBLIC_API_BASE_URL`) — a *build-time* fallback |
| `web/src/lib/api/client.ts` | `request()` mellé `chatRequest()`, vagy `request()` opcionális `baseUrl` paraméterrel. A token- és refresh-kezelés **közös marad** |
| `web/src/lib/api/chat-stream.ts` | a `fetch(\`${env.NEXT_PUBLIC_API_BASE_URL}/chat/stream\`)` → a chat base URL. A `refreshAccessToken()` hívás **marad a monolité** |
| `web/src/features/chat/api.ts` | `chatRequest()`-re vált |
| (új) `web/src/lib/client-config.ts` | a §7.1 végpont lekérése, runtime felülírja az env-fallbacket |

**CORS:** a `lifey-chat` service-nek saját `CORS_ALLOWED_ORIGINS` env-változó
kell, a Vercel domainnel (és a preview domainekkel, ha ma is engedettek).
**Ez a leggyakoribb cutover-hiba** — a web chat 100%-ban eltörik, ha kimarad,
miközben a mobil hibátlanul működik. M6 füstteszt-listáján kötelező elem.

Az SSE-nél a CORS különösen fontos: a `text/event-stream` válasz preflightot
igényel az `Authorization` header miatt.

### 7.4 Watch

A `watch/` nem érinti a chatet (nincs chat-fájl benne). Ellenőrizendő M5-ben,
de várhatóan nulla változás.

---

## 8. Deploy

### 8.1 `render.yaml` — a második service

A meglévő `lifey-api` blokk mellé:

```yaml
  - type: web
    name: lifey-chat
    runtime: docker
    dockerfilePath: ./chat/Dockerfile
    dockerContext: ./chat
    # UGYANAZ a régió, mint a Neon projekt és a lifey-api: a chat mindkettővel
    # beszél (DB közvetlenül, monolit /internal/push HTTP-n).
    region: frankfurt
    # NEM free: a spin-down megölné a ChatUnreadReminderJob-ot, és egy hideg
    # indítás alatt minden SSE-kapcsolat halott.
    plan: starter
    branch: main
    autoDeploy: true
    healthCheckPath: /actuator/health
    envVars:
      - key: SPRING_PROFILES_ACTIVE
        value: prod
      # MÉRT érték (§17.4), nem becslés — a terv első változata 96m-et írt ide,
      # és az kevés volt. A tényleges render.yaml a repo gyökerében ezt már
      # tartalmazza.
      - key: JAVA_OPTS
        value: -Xms64m -Xmx192m -XX:MaxMetaspaceSize=128m -XX:ReservedCodeCacheSize=48m -XX:MaxDirectMemorySize=32m
      - key: SPRING_DATASOURCE_URL
        sync: false
      - key: SPRING_DATASOURCE_USERNAME     # lifey_chat, NEM a monolit usere (§4.3)
        sync: false
      - key: SPRING_DATASOURCE_PASSWORD
        sync: false
      - key: JWT_SECRET                     # UGYANAZ az érték, mint a lifey-api-n
        sync: false
      - key: LIFEY_INTERNAL_TOKEN           # S2S titok, mindkét service-en azonos
        sync: false
      - key: LIFEY_API_INTERNAL_URL         # https://lifey.onrender.com
        sync: false
      - key: CORS_ALLOWED_ORIGINS           # a Vercel domain(ek)
        sync: false
      - key: CHAT_ENABLED
        value: "true"
      - key: JOB_CHAT_UNREAD_REMINDER_CRON
        value: "0 */5 * * * *"
```

És a `lifey-api` blokkjába két új változó:

```yaml
      # Üres = a chat a monoliton fut (rollback állás). Kitöltve = a kliensek
      # a chat service-hez mennek. Ez a cutover és a rollback kapcsolója.
      - key: CHAT_PUBLIC_BASE_URL
        sync: false
      - key: CHAT_INTERNAL_URL              # https://lifey-chat.onrender.com
        sync: false
      - key: LIFEY_INTERNAL_TOKEN
        sync: false
      # A monolit chat-modulja kikapcsolható a cutover után (§10.3).
      - key: CHAT_LOCAL_ENABLED
        value: "true"
```

### 8.2 `chat/Dockerfile`

A `backend/Dockerfile` másolata, két különbséggel:
- **Nincs** `PUSH_FCM_CREDENTIALS_B64` / `PUSH_APNS_KEY_B64` dekódolás az
  entrypointban (nincs mit dekódolni).
- Más `JAVA_OPTS` alapérték (§8.1).

### 8.3 Kapcsolat-készlet — a Neon oldal

Két service ugyanahhoz a Neon DB-hez. A `lifey-api` ma
`hikari.maximum-pool-size: 5`, `minimum-idle: 0`.

- A `lifey-chat` kapjon **3**-at. Az SSE-kapcsolatok nem tartanak DB-kapcsolatot
  (az emitter memóriában él), a forgalom rövid tranzakciókból áll.
- Együtt max. 8 egyidejű kapcsolat — Neon Launch/Scale terven bőven belül fér.
- A `minimum-idle: 0` beállítás **mindkét service-en kell**, különben a Neon
  compute soha nem szuszpendál, és a számla nő. Ez a `backend/`-ből átmásolandó
  komment is.

### 8.4 Költség

| Tétel | Ma | Kiemelés után |
|---|---|---|
| Render web service | 1 × Starter | **2 × Starter** |
| Neon | változatlan | változatlan (ugyanaz a DB, +3 kapcsolat) |
| Vercel | változatlan | változatlan |

A Render Starter listaára **a cutover előtt ellenőrizendő a Render aktuális
árlistáján** — ne a fejemből írt számot használd a döntéshez. A lényeg a
nagyságrend: **egy második, ugyanakkora instance havidíja**, plusz az, hogy
mostantól két service logját, két deployt és két környezeti változó-készletet
kell karbantartani.

**Ezt a költséget a K3 küszöb (önálló deploy) indokolja a leginkább.** Ha csak
K1-re várnánk, a pénz évekig indokolatlan lenne.

---

## 9. Mérföldkövek

Összesen **~10–14 fejlesztői nap**. Az M1 önállóan is szállítható és önmagában
is értékes; onnantól minden lépés visszagörgethető.

### M0 — Döntési kapu (0,5 nap)

Nem kód. Kimenet: eldöntött válasz ezekre —

1. Melyik küszöb (K1–K4) miatt indul a munka? Írd le egy mondatban.
2. A Render Starter aktuális ára × 2 elfogadható-e?
3. Van-e 2 hétnyi mért `lifey.chat.stream.connections` adat? Ha nincs, gyűjtsd
   előbb — a kiválás után ez lesz a viszonyítási alap.

**Kilépési feltétel:** a döntés és az indoklás bekerül ide, §22-be.

---

### M1 — Határ-megkeményítés a monoliton belül (2–3 nap) · ✅ KÉSZ (napló: §17.2)

**Ez a mérföldkő a kiemeléstől függetlenül is megéri.** Ha itt megállunk, akkor
is jobb kód marad.

1. `com.lifey.chat.spi` csomag + a hét interfész és DTO-juk (§5.2).
2. A hét adapter a monolit megfelelő moduljaiban.
3. A négy entitás JPA-relációinak ID-vé bontása (§2.4) — **viselkedés-változás
   nélkül**. Érinti: `ChatConversation`, `ChatMessage`, `ChatParticipant`,
   a négy repository JPQL-je, `ChatMapper`, `ChatServiceImpl`,
   `ChatNotificationServiceImpl`, `ChatUnreadReminderJob`, `ChatStreamServiceImpl`.
4. `ChatQuietHours.isQuiet(User, UserSettings, Instant)` → `isQuiet(ChatUser, ChatPushPrefs, Instant)`.
5. Az 5 chat-kivétel kivezetése a `GlobalExceptionHandler`-ből egy
   `com.lifey.chat.ChatExceptionHandler` `@RestControllerAdvice`-ba.
6. A `ChatArchiveListener` marad `@EventListener`-nek — ez az utolsó
   monolit-irányú kötés, és M4-ben esik ki.

**Kész-definíció:**
```bash
# Nulla találat, kivéve com.lifey.chat.* és com.lifey.common.domain.BaseEntity
grep -rh "^import com\.lifey" backend/src/main/java/com/lifey/chat \
  | grep -v "^import com\.lifey\.chat" \
  | grep -v "BaseEntity\|ResourceNotFoundException\|TrainerClientRevokedEvent"
```
A 16 meglévő chat-teszt zöld, **átírás nélkül vagy csak a mockok cseréjével**.
Ha egy teszt logikát kell átírni, az azt jelenti, hogy a refaktor
viselkedést változtatott — vissza kell nézni.

**Rollback:** sima revert, nincs séma- vagy config-változás.

---

### M2 — Séma-tulajdonjog (1 nap) · ✅ KÉSZ (napló: §17.3)

1. A `lifey_chat` DB-user létrehozása és jogosultságai (§4.3) — runbook:
   [devops/chat-database-split.md](../../devops/chat-database-split.md).
2. A `lifey-chat` Flyway-konfiguráció előkészítése (§4.2), külön history
   táblával és `baseline-version: 999`-cel — **plusz a §4.2.1 baseline-lelet**.
3. CI-ellenőrzés: `backend/` migráció nem érinthet `chat_*` táblát.
4. Megjegyzés a `users` / `user_settings` / `trainer_clients` entitásokhoz:
   „ezekből a chat service olvas — lásd docs/chat/44".

**Kész-definíció:** a `lifey_chat` userrel egy `insert into users` **hibára fut**.

**Rollback:** a user eldobása (a runbook „Undo" szakasza).

---

### M3 — A `chat/` Maven projekt (2–3 nap) · ✅ KÉSZ (napló: §17.4)

0. **Először a séma** (§4.2.1, M2 lelete): `V1000__chat_baseline.sql`
   idempotens formában, és a teszt-only `V1__monolith_stub.sql`. E nélkül a
   chat service tesztjei üres adatbázison futnának, és zöldek lennének anélkül,
   hogy bármit ellenőriznének.
1. `chat/pom.xml` — a `backend/pom.xml` alapján, **Firebase Admin SDK és APNs
   kliens nélkül**, `mail` nélkül. Marad: web, data-jpa, validation, security,
   actuator, jjwt, flyway, postgresql, lombok, springdoc.
2. `git mv backend/src/main/java/com/lifey/chat chat/src/main/java/com/lifey/chat`
   — és ugyanez a 16 teszttel.
3. Másolatok: `BaseEntity`, `ResourceNotFoundException`, `ApiError`, a JWT
   ötös (§5.3), `ImageReencoder`, `SecurityConfig` (lecsupaszítva),
   `WebCorsConfig`, **és a `Clock` bean** (§2.5).
4. Az `spi` portok JDBC-implementációi (§4.4) és HTTP-implementációi (§6.1).
5. `chat/Dockerfile`, `chat/src/main/resources/application.yml` (a `lifey.chat.*`
   blokk átemelve a `backend/` application.yml-ből, változatlan defaultokkal).
6. **Metaspace-mérés** (§6.1): fut-e a service 96 MB-tal? Írd le a mért értéket.
7. Lokálisan két process fut egymás mellett, közös DB-vel, és a web kliens
   `NEXT_PUBLIC_CHAT_BASE_URL=http://localhost:8081/api/v1`-gyel végigvihető
   egy teljes chat-folyamat.

**Kész-definíció:** `cd chat && ./mvnw test` zöld, mind a 16 teszt. Lokális
kétszolgáltatásos füstteszt: szál nyitás → küldés → SSE-fogadás → olvasás-nyugta
→ kép-csatolmány → törlés → keresés.

**Rollback:** a `chat/` mappa törlése; a `backend/` érintetlen (M3-ban a monolit
chat-modulja még a helyén van — a `git mv` a *másolat* forrása, a monolitbeli
példány M3 végén még nincs törölve).

> **Figyelem:** M3 alatt a kód átmenetileg két helyen létezik. Ez tudatos: a
> monolitbeli példány a rollback-út a cutoverig. Az M7 törli.

---

### M4 — A monolit `/internal` felülete (1–2 nap) · ✅ KÉSZ (napló: §17.5)

0. **Elsőként (M3 lelete, §17.4.5): a küldés-úti guard-ellenőrzés.**
   `ChatServiceImpl.store()` kérdezze meg a `ChatRelationshipGuard`-ot a
   beszélgetés `trainerClientId`-jével. E nélkül a kivált chat service
   korlátlanul fogadna üzenetet egy visszavont kapcsolat szálába — ez **M6
   előfeltétele**, nem opcionális megkeményítés.
1. `POST /internal/push` — vékony controller a `PushService` fölött, **nem
   chat-specifikus**.
2. `POST /internal/relationships/{trainerClientId}/revoked` **a chat
   service-en**, és a monolitban a `ChatArchiveListener` helyére lépő
   `@TransactionalEventListener(AFTER_COMMIT)` HTTP-hívó (§5.4/2). A chat
   service-ben ekkor tér vissza a törölt `ChatArchiveListener` funkciója és a
   tesztje.
3. Az S2S filter mindkét oldalon (§5.5).
4. A napi egyeztető söprés a chat service-ben (§5.4/3).
5. A monolit chat-modulja **kapcsolhatóvá válik**:
   `@ConditionalOnProperty(name = "lifey.chat.local-enabled", havingValue = "true", matchIfMissing = true)`
   a három controlleren, a `ChatUnreadReminderJob`-on és a
   `ChatNotificationServiceImpl` eseménykezelőjén.
6. `GET /api/v1/client-config` a monoliton (§7.1).

**Kész-definíció:** `CHAT_LOCAL_ENABLED=false` mellett a monolit elindul, és a
`/api/v1/chat/**` **hitelesített** hívóra 404-et ad. (Hitelesítetlenül 401 jön,
mert a security lánc előbb utasít el, mint hogy a dispatcher kiderítené, hogy
nincs handler — ez nem bizonyít semmit a mappingről. §17.5.)
`LIFEY_INTERNAL_TOKEN` nélkül a `/internal/push` 401-et ad.

**Rollback:** `CHAT_LOCAL_ENABLED=true` (a default).

---

### M5 — Kliensek (2–3 nap) · ✅ KÉSZ (napló: §17.7)

A §7.2 és §7.3 teljes listája, plusz:
- `AuthInterceptor` retry-út átnézése (a kritikus pont, §7.2).
- Az SSE újracsatlakozás config-változásra.
- Mobil és web teszt-készlet kiegészítése: egy teszt, ami *ellenőrzi*, hogy a
  chat-hívások a chat base URL-re, a `trainer_clients` hívás pedig a monolitra
  megy.
- A `web/e2e/trainer-chat.spec.ts` futtatása két base URL-lel.

**Kész-definíció:** `CHAT_PUBLIC_BASE_URL` üresen hagyva minden változatlanul
működik (**ez a legfontosabb teszt**), kitöltve pedig a chat a másik hostra megy.

**Rollback:** `CHAT_PUBLIC_BASE_URL` kiürítése — kliens-újratelepítés nélkül.

---

### M6 — Deploy (1 nap) · ✅ ELŐKÉSZÍTVE (napló: §17.8)

A runbook átírva (§10) és a teljes útvonal lokálisan végigmérve két processzen.
**Ami hátravan, az a te kezedben van**: a `main`-be merge, a Neon-grantok, és a
Render-oldali lépések (§10.2).

Részletesen §10-ben.

---

### M7 — Takarítás (0,5 nap) · ✅ KÉSZ, ELŐREHOZVA M5 elé (napló: §17.6)

1. A `backend/src/main/java/com/lifey/chat` és a 16 teszt **törlése**.
2. A hét adapter átalakítása: az `spi` interfészek a monolitból eltűnnek, az
   adapterek a `/internal/**` controllerekké alakulnak (ahol még kellenek).
3. `lifey.chat.*` blokk törlése a `backend/application.yml`-ből (a
   `user_settings` chat-oszlopai maradnak — azok a monolité).
4. `CHAT_LOCAL_ENABLED` és a `@ConditionalOnProperty`-k törlése.
5. Dokumentáció: `devops/chat-operations.md` átírása két service-re,
   `docs/02-architecture.md` frissítése, ennek a doksinak a §22 naplója.

**Rollback:** ettől a ponttól a visszaút már nem egy env-változó, hanem egy
revert commit. **Ezért M7 legkorábban a cutover után két héttel jöjjön.**

---

### M8 — Opcionális, később

- Objektumtár a csatolmányoknak (§4.6) — a legnagyobb hozamú következő lépés.
- `ChatEventBus` Postgres `LISTEN/NOTIFY` fölött, ha a chat 2+ instance lesz.
- Külön adatbázis (Fázis B, §4.5) — csak ha valódi indok jön rá.
- A push kiemelése önálló szolgáltatásba — a *következő* jelölt, mert a
  `PushService` a chat kiválásával **két deployable közös függése** lesz.

---

## 10. Deploy runbook

> **Ez nem cutover.** A §10 eredetileg egy élő chat átállítására íródott
> (kilenc lépés, kettős futás, fokozatos kliens-átterelés). A chat viszont
> soha nem került éles adatbázisba (§17.6), tehát ez egyszerűen **egy új
> szolgáltatás első deployja**. Nincs mit átállítani, és nincs mihez
> visszagörgetni — ami a munkát rövidebbé teszi, a rollback jelentését viszont
> megváltoztatja (§10.4).

### 10.1 Előfeltételek

- [ ] A branch mergelve `main`-be. **Mindkét service innen deployol**, és a
      `V65` (a monolité) meg a `V1000` (a chaté) egyetlen commitban jár együtt.
- [ ] A `lifey_chat` Postgres-role létrehozva **és a grantok kiadva** —
      [devops/chat-database-split.md](../../devops/chat-database-split.md)
      1–3. lépés. A 3. lépés harmadik lekérdezésének (`insert into users`)
      **hibára kell futnia**.
- [ ] Neon backup / point-in-time elérhető, és tudod, meddig nyúlik vissza.
- [ ] Kéznél: a `JWT_SECRET` aktuális értéke (a `lifey-api` Environment fülén),
      egy frissen generált `LIFEY_INTERNAL_TOKEN`, és a Vercel-domain(ek).
- [ ] Az env-fájlok kitöltve: [devops/render/](../../devops/render/) — a
      `lifey-chat.env` teljes, a `lifey-api-chat-additions.env` a három új
      változó. Importálás után **keress rá a `<<<`-re** a dashboardon: a Render
      a kitöltetlen helyőrzőket is szó szerint beimportálja.

### 10.2 Sorrend — és miért pont ez

A két service között **egyirányú indulási függés** van: a `lifey-chat`
Flyway-migrációja idegen kulcsokkal hivatkozik a `users` és `trainer_clients`
táblákra, tehát a monolitnak **előbb** kell futnia legalább egyszer.

| # | Lépés | Hol | Ellenőrzés |
|---|---|---|---|
| 1 | `main` deploy — a `lifey-api` felmegy `V65`-ig | Render (auto) | `/actuator/health` 200; a `flyway_schema_history` legnagyobb verziója **65**, és **nincs** `chat_*` tábla |
| 2 | `LIFEY_INTERNAL_TOKEN` beállítása a `lifey-api`-n | Render env | a service újraindul, health zöld |
| 3 | A `lifey-chat` service létrehozása a Blueprintből, a §8.1 env-készlettel | Render | a build lefut |
| 4 | Első indulás | Render | a logban `baselined schema with version: 999`, majd `Migrating schema "public" to version "1000 - chat"`. Ezután **4 `chat_*` tábla** és **két** `flyway_schema_history*` létezik |
| 5 | `CHAT_INTERNAL_URL` a `lifey-api`-n = a chat service URL-je | Render env | újraindul |
| 6 | **Füstteszt** (§10.3) | curl | mind a 6 pont |
| 7 | `CHAT_PUBLIC_BASE_URL` a `lifey-api`-n = `https://<chat>.onrender.com/api/v1` | Render env | `GET /api/v1/client-config` ezt adja vissza |
| 8 | Web füstteszt | böngésző | **külön figyelj a CORS-ra** (§13/R2) |
| 9 | Mobil füstteszt mindkét szerepkörben | két készülék | küldés, push, offline outbox |

**A 7. lépés az, ami a klienseket odaküldi.** Előtte a chat service fut, de
senki nem beszél vele — ez szándékos: a füstteszt egy olyan szolgáltatáson fut,
amit még nem használ senki.

### 10.3 Füstteszt (a 6. lépés)

Egy éles access tokennel, a `lifey-api`-ról szerezve. A lokális megfelelőjét
ugyanígy végigvittem, jegyzőkönyv: §17.8.

1. `GET /api/v1/chat/conversations` a **chat service-en**, a **monolit**
   tokenjével → **200**. Ez a JWT-szerződés (§5.3); ha 401, a `JWT_SECRET` nem
   bitre azonos.
2. Szál megnyitása egy valódi, aktív edző-kliens kapcsolatra → **201**, és a
   `peer.displayName` a **valódi nevet** adja. Ez bizonyítja, hogy a JDBC
   projekciók olvassák a monolit `users` tábláját (§4.4).
3. Üzenetküldés → **201**.
4. `GET /actuator/metrics/lifey.chat.internal.push?tag=outcome:ok`
   (super-admin token) → **1.0**. Ez a chat→monolit push-út; ha `failed`, a
   `LIFEY_INTERNAL_TOKEN` vagy a `LIFEY_API_INTERNAL_URL` rossz.
5. Kapcsolat visszavonása a monoliton (`DELETE /api/v1/trainer/clients/{id}`) →
   a szál `archived_at`-je **azonnal** beáll. Ez a monolit→chat webhook.
6. Küldés a visszavont szálba → **409**; olvasás ugyanott → **200**.

### 10.4 Rollback — és amit tudnod kell róla

`CHAT_PUBLIC_BASE_URL` kiürítése a `lifey-api`-n. A kliensek a következő
config-lekérésnél (mobil: app-indulás vagy foreground; web: lapbetöltés) a fő
API-ra esnek vissza.

**Ez nem visszaállítja a chatet — megszünteti.** A monolit már nem szolgálja ki
a `/api/v1/chat/**` útvonalakat, tiszta 404-et ad rájuk. A rollback tehát azt
jelenti: *„a chat legyen inkább egyértelműen elérhetetlen, mint hibásan
működő"*. Ez legitim válasz egy elromlott chat service-re, de **nem tartalék**.

| Tünet | Lépés |
|---|---|
| Minden chat-hívás 401 | `JWT_SECRET` nem azonos → javítsd a `lifey-chat`-en, újraindul |
| Csak a web tört el | `CORS_ALLOWED_ORIGINS` a `lifey-chat`-en |
| A push nem megy | `LIFEY_INTERNAL_TOKEN` / `LIFEY_API_INTERNAL_URL`; a `lifey.chat.internal.push{outcome=failed}` számláló mondja meg |
| A chat service nem indul | a `lifey_chat` role grantjai (§4.3) — a Flyway `create`-je bukik el elsőként |
| Bármi más, és sürgős | `CHAT_PUBLIC_BASE_URL` kiürítése |

**Nincs adatvisszaállítási forgatókönyv**: a chat táblákat kizárólag a chat
service írja, és a rollback nem nyúl hozzájuk.

### 10.5 Deploy utáni két hét

- Naponta egyszer: `lifey.chat.stream.connections` (a **chat service**
  `/actuator/metrics`-én), `lifey.chat.push.decisions` bontásban,
  `lifey.chat.internal.push{outcome=failed}`, és
  **`lifey.chat.relationship.reconciled` — ennek nullán kell maradnia**;
  ha nem, a revoke-webhook csendben elromlott (§5.4).
- Render memória-grafikon mindkét service-en. A `lifey-chat` RSS-e
  stabilizálódjon; ha kúszik, az emitter-szivárgás (`devops/chat-operations.md`).
- A `CLIENT_CONFIG_TTL_SECONDS` a deploy körül legyen **300**, utána vissza
  `21600`-ra — így egy esetleges rollback percek alatt terjed.

## 11. Tesztelési stratégia

| Szint | Mit fed le | Hol |
|---|---|---|
| Meglévő 16 backend teszt | A chat üzleti logikája | átmozgatva a `chat/` alá, M3 |
| Új: `spi` adapter tesztek | A JDBC projekciók helyes oszlopokat olvasnak | `chat/`, M3 |
| Új: S2S filter teszt | Rossz/hiányzó titok → 401, konstans idejű összehasonlítás | mindkét oldal, M4 |
| Új: JWT-kompatibilitási teszt | A monolit által kiadott token a chat service-ben feloldható; lejárt token 401 | `chat/`, M3 |
| Új: kétszolgáltatásos integrációs füstteszt | Teljes folyamat két JVM-mel, közös Testcontainers Postgresszel | `chat/`, M3 |
| Mobil | A chat hívások a chat URL-re, a `trainer_clients` a monolitra mennek | `mobile/test/`, M5 |
| Web | ugyanaz + `chat-stream.ts` base URL | `web/src/**/*.test.ts`, M5 |
| E2E | `web/e2e/trainer-chat.spec.ts` két base URL-lel | M5 |

**Amit külön ki kell próbálni, mert könnyen kimarad:**
- Lejárt access token a **SSE stream közben** → a kliens a monolithoz megy
  refresh-ért, majd újracsatlakozik a chathez.
- Kép-feltöltés a chat service-en, a monolit multipart-limitjétől függetlenül
  (a chat saját `CHAT_ATTACHMENT_MAX_BYTES`-a a maga konténerében érvényes).
- Ékezetes keresés — az `unaccent` kiterjesztés ugyanabban a DB-ben van,
  tehát működnie kell, de a chat service DB-userének kell hozzá jog.

---

## 12. Megfigyelés a szétvágás után

| Metrika | Hol | Változás |
|---|---|---|
| `lifey.chat.stream.connections` | **chat service** `/actuator/metrics` | Már nem a monoliton. A `devops/chat-operations.md` minden hivatkozását át kell írni. |
| `lifey.chat.push.decisions` | chat service | változatlan jelentés |
| `lifey.chat.messages.sent` | chat service | változatlan |
| `lifey.chat.reminders.sent` | chat service | változatlan |
| **Új:** `lifey.chat.internal.push` (`outcome` = `ok` \| `failed`) | chat service | A `/internal/push` HTTP-hívás sikere. Ez az új meghibásodási pont, mérni kell. |
| **Új:** `lifey.chat.relationship.reconciled` | chat service | Hány szálat archivált a napi söprés (§5.4/3). **Ha ez tartósan nem nulla, a webhook nem érkezik meg** — ez a szám a webhook egészségügyi mutatója. |

Az actuator továbbra is `ROLE_SUPER_ADMIN` mögött, a chat service-en is.

---

## 13. Kockázatok

| # | Kockázat | Hatás | Mérséklés |
|---|---|---|---|
| R1 | A `JWT_SECRET` nem azonos a két service-en | Minden chat-hívás 401 | Cutover előfeltétel-lista 3. pontja: éles tokennel ellenőrizve |
| R2 | CORS kimarad a chat service-en | A web chat teljesen eltörik, a mobil hibátlan → nehéz észrevenni | 10.3/8. lépés, kötelező web füstteszt |
| ~~R3~~ | ~~A `ChatUnreadReminderJob` egyszerre fut mindkét helyen~~ | — | **Megszűnt**: a job csak a chat service-ben létezik (§17.6) |
| R4 | A `backend/` migráció hozzányúl egy `chat_*` táblához | Séma-drift, két igazság | CI-ellenőrzés (M2/3) + a `lifey_chat` user jogosultságai |
| R5 | Az `AuthInterceptor` retry a régi hostra ismétel | 401-hurok a chatben | M5 első feladata, explicit teszt |
| R6 | Az M1 entitás-refaktor viselkedést változtat | Csendes adathiba (rossz szál, rossz kurzor) | Kész-definíció: a 16 teszt **logika-átírás nélkül** zöld |
| R7 | A `/internal/push` elérhetetlen | Nincs push-értesítés | A hívás nyeli a hibát; a 30 perces emlékeztető-job a háló; új metrika (§12) |
| R8 | A `client-config` végpont hibázik | A kliensek a monolitra esnek vissza, ahol a chat 404 | A kliensek **cache-elik** az utolsó választ (mobil: SharedPreferences, web: localStorage), tehát egy átmeneti kiesés nem téríti el őket (§17.7.1) |
| R9 | Compile-time URL a mobilon | Rollback = App Store review | §7.1 runtime config — ezért van így. Foreground-onként újratöltve (§17.7.3) |
| R10 | Két Render service = két deploy elfelejthető | Verzió-eltérés a JWT-szerződésen | Ha a `sub`/`roles`/`iss` szerződés változik, a két deploy **ugyanabban a PR-ben** menjen |
| R11 | Neon kapcsolat-limit | Kapcsolathiba csúcsidőben | §8.3 pool-méretek, `minimum-idle: 0` mindkét oldalon |

---

## 14. Amit ez a terv tudatosan nem tartalmaz

| Nem csináljuk | Miért |
|---|---|
| API gateway a két service elé | Újabb komponens, újabb single point of failure, újabb havidíj. Két base URL a kliensen olcsóbb. |
| Külön adatbázis a chatnek (most) | §4.5 — az FK-k elvesztése és a jogosultsági stale-ablak ára ma nagyobb, mint a haszon |
| Objektumtár a csatolmányoknak (most) | Értékes, de **külön munka** — a cutoverrel együtt duplázná a kockázatot (§4.6) |
| Kafka / RabbitMQ / bármilyen broker | Két szolgáltatás között két HTTP-hívás van. Broker nélkül is megoldott. |
| WebSocket | A terv §2 döntése változatlan: SSE + REST |
| Elixir / Go átírás | §1.4 |
| `ChatEventBus` elosztott implementációja | A chat service egy instance. Ismeretlen jövőbeli terhelésre írt kód. |
| A monolit további darabolása | A push a *következő* jelölt (M8), de nem most |

---

## 15. Nyitott kérdések

Ezekre a terv nem ad végleges választ; a jelölt megoldás mellettük áll.

1. **A `client-config` végpont autentikált vagy publikus legyen?**
   Jelölt: **autentikált**, mert csak bejelentkezett felhasználó chatel, és így
   nem hirdeti a belső topológiát. Kockázat: a bejelentkezés *előtt* nincs
   chat-URL — de nincs is rá szükség.
2. **A `lifey-chat` kapjon-e saját Swagger UI-t prod-ban?**
   Jelölt: **nem**, ahogy a monolit sem (`application-prod.yml`).
3. **Az M7 (a monolitbeli chat-kód törlése) mikor jöjjön?**
   Jelölt: a cutover után **két héttel**, ha a §10.5 mutatók rendben vannak.
4. **Kell-e a chat service-nek saját `/actuator/health` DB-ellenőrzés?**
   Jelölt: igen, a default `DataSourceHealthIndicator` elég — de vedd
   figyelembe, hogy Neonon egy szuszpendált compute miatt a health-check
   ébreszteni fog. A monoliton ez ma is így van.
5. **A napi egyeztető söprés (§5.4/3) melyik service-ben fusson?**
   Jelölt: **a chat service-ben**, mert ő ír `chat_conversations`-be. Fázis
   B-ben ez átgondolandó.
6. **Két service esetén hol legyen a `docs/` chat-üzemeltetés?**
   Jelölt: `devops/chat-operations.md` marad a hely, de kapjon egy „Két
   szolgáltatás" fejezetet a cutover után.

---

## 16. Ellenőrzőlista (nyomtatható)

**M1** — ✅ kész, napló: §17.2
- [x] kontextus-ellenőrzés: milyen bean-t kap a chat, amit nem ő definiál (§2.5)
      → a `Clock` volt, átkerült `common.config.ClockConfig`-ba
- [x] `com.lifey.chat.spi` 7 interfész + DTO-k
- [x] 7 adapter a monolit moduljaiban
- [x] 4 entitás relációi ID-vé bontva (3 entitás, 5 reláció)
- [x] `ChatQuietHours` szignatúra portokra
- [x] chat-kivételek külön `@RestControllerAdvice`-ba
- [x] a grep-kész-definíció csak a várt maradékot adja (§17.2.5)
- [x] 16 teszt zöld, logika-átírás nélkül; +2 új adapter-teszt (§17.2.3)

**M2** — napló: §17.3
- [ ] `lifey_chat` DB-user + jogosultságok — **kézi lépés, rád vár**
      ([runbook](../../devops/chat-database-split.md) 1–2. lépés)
- [ ] `insert into users` a `lifey_chat` userrel hibára fut (runbook 3. lépés)
- [x] Flyway-döntés véglegesítve, a baseline-lelettel együtt (§4.2, §4.2.1)
- [x] CI-ellenőrzés mindkét irányra, önteszttel igazolva
- [x] entitás-megjegyzések + `backend/CLAUDE.md` szabály

**M3** — ✅ kész, napló: §17.4
- [x] **először:** `V1000__chat_baseline.sql` (idempotens) + teszt-only
      `V1__monolith_stub.sql` (§4.2.1)
- [x] `chat/pom.xml` Firebase/APNs/mail nélkül (jar: 66 MB vs. 126 MB)
- [x] kód + tesztek átmásolva (a monolitbeli példány marad a rollback-út)
- [x] másolatok (BaseEntity, JWT-oldal, ImageReencoder, …) — ~430 sor
- [x] `spi` JDBC + HTTP implementációk
- [x] `chat/Dockerfile`, `application.yml`, `render.yaml`, `chat-ci.yml`
- [x] **metaspace mérés: a tervezett 96m kevés volt → 128m** (§17.4.2)
- [x] lokális kétszolgáltatásos füstteszt, a monolit tokenjével (§17.4.3)
- [x] 162 teszt zöld, ebből 22 integrációs valódi Postgres ellen

**M4** — ✅ kész, napló: §17.5
- [x] **a küldés-úti guard** (M3 lelete, §17.4.5) — mindkét kódbázisban
- [x] `POST /internal/push` (generikus, 202)
- [x] revoke-webhook (monolit → chat) + `POST /internal/relationships/revoked`
- [x] nightly egyeztető söprés + `lifey.chat.relationship.reconciled` metrika
- [x] S2S filter mindkét oldalon, konstans idejű összehasonlítással
- [x] `CHAT_LOCAL_ENABLED` kapcsoló, integrációs teszttel
- [x] `GET /api/v1/client-config`
- [x] 837 + 173 teszt zöld

**M5**
- [ ] `AuthInterceptor` retry-út átnézve
- [ ] mobil: `chatDioProvider`, config-repo, SSE újracsatlakozás
- [ ] mobil: `trainer_clients_repository.dart` **változatlan**
- [ ] web: `chatRequest()`, `chat-stream.ts`, client-config
- [ ] tesztek mindkét oldalon
- [ ] üres `CHAT_PUBLIC_BASE_URL` mellett minden változatlan

**M6** — napló: §17.8
- [x] a §10 runbook átírva első deployra (nem cutover)
- [x] `clientConfig.reload()` bekötve foreground-ra (§17.7.3/3 zárva)
- [x] a teljes útvonal lokálisan végigmérve két processzen (§17.8)
- [ ] `main`-be merge — **rád vár**
- [ ] Neon grantok (runbook 1–3. lépés) — **rád vár**
- [ ] Render lépések (§10.2 1–9.) — **rád vár**

**M7** — ✅ kész, előrehozva M5 elé, napló: §17.6
- [x] monolit chat-kód törölve
- [x] `lifey.chat.*` config törölve a `backend/`-ből
- [x] dokumentáció frissítve (`devops/chat-operations.md`, `backend/CLAUDE.md`)

---

## 17. Naplók

*(Ez a fejezet a megvalósítás során töltődik, a 40-es terv §12–§21 mintájára:
mérföldkövenként „mi készült el", „eltérések a tervtől", „amit tudatosan nem
szállít", „döntések, amik kötik a következő lépéseket".)*

### 17.1 M0 — döntési kapu

*(kitöltendő)*

---

### 17.2 M1 — határ-megkeményítés · ✅ KÉSZ

Egy commitnyi munka, **viselkedés-változás nélkül**. 824 teszt zöld, ebből a
chat 143 + 10 új adapter-teszt. A `ChatFlowIntegrationTest` 22 esete valódi
Postgres ellen futott (Testcontainers) — ez az egyetlen, ami az átírt JPQL-t
igazolja, mert a unit tesztek mockolják a repositorykat.

#### 17.2.1 Mi készült el

**A hét port — `com.lifey.chat.spi`** (+ `package-info.java`, ami a függés
irányát is rögzíti): `ChatCaller`, `ChatUserDirectory` (+`ChatUser`),
`ChatNotificationPreferences` (+`ChatPushPrefs`), `ChatRelationshipGuard`
(+`ChatRelationship`), `ChatPushSender` (+`ChatPushNotification`),
`ChatImageProcessor`, `ChatMailSender`.

**A hét adapter**, mindegyik a *hívott* modulban, package-private:
`auth.ChatCallerAdapter`, `user.ChatUserDirectoryAdapter`,
`settings.ChatPreferencesAdapter`, `trainer.ChatRelationshipGuardAdapter`,
`push.ChatPushSenderAdapter`, `common.image.ChatImageProcessorAdapter`,
`mail.ChatMailSenderAdapter`.

**Entitás-relációk ID-vé bontva** (§2.4): `ChatConversation.trainerClient/trainer/client`
→ `trainerClientId/trainerId/clientId`, `ChatMessage.sender` → `senderId`,
`ChatParticipant.user` → `userId`. Az FK-kat a DB továbbra is kikényszeríti;
migráció **nem kellett**, mert az oszlopnevek változatlanok.

**JPQL átírva** három repositoryban: `c.trainer.id` → `c.trainerId`,
`m.sender.id` → `m.senderId`, `p.user.id` → `p.userId`, és három `join fetch`
(`c.trainer`, `c.client`, `p.user`, `m.sender`) eltávolítva.

**A chat-kivételek külön advice-ban:** `com.lifey.chat.ChatExceptionHandler`.
A `GlobalExceptionHandler` már nem importál `com.lifey.chat`-ből semmit.

#### 17.2.2 Eltérések a tervtől — ezekkel kell dolgozni

1. **`ChatRelationshipGuard.findActiveForUser` nem készült el.** A tervben
   szerepelt, de nincs hívója: a mobil a chat-feature-ben lévő
   `trainer_clients_repository.dart`-tal a *monolit* `/trainer/clients`
   végpontját hívja, nem a chatét. Nem építünk használat nélküli API-t.
2. **`hasRegisteredDevice` a `ChatPushSender`-re került**, nem a
   `ChatPushPrefs`-be. Így a forró push-út nem fizet egy eszköz-lekérdezésért,
   amire csak a (kikapcsolt) e-mail fallbacknek van szüksége.
3. **`utcOffsetMinutes` a `ChatPushPrefs`-en van, nem a `ChatUser`-en.** A
   csendes órák az egyetlen fogyasztója, és így az egész gát-létra **egy**
   lekérdezésből kiszolgálható. Következmény: `ChatQuietHours.isQuiet` szignatúrája
   `(ChatPushPrefs, Instant)`, és a „nincs settings sor" eset eltűnt a chatből —
   a defaultokat az adapter alkalmazza.
4. **`ChatImageProcessor` `BufferedImage`-szintű maradt** (`decode` +
   `boundedJpeg` + `contentType`), nem egy `encode(upload)` hívás. Így a
   „dekódolj egyszer, kódolj kétszer, majd olvasd vissza a valódi méretet"
   érvelés (§18.2) a chatben marad, és az adapter háromsoros delegálás.
5. **`ApiErrorResponses` kiemelve** a `GlobalExceptionHandler`-ből, hogy a
   `ChatExceptionHandler` ugyanazt a válasz-alakot építse. Ezért a chat
   `common.exception`-ből most **két importtal többet** használ, mint a tervezett
   lista — mindkettő a §3.2 „másolandó" halmazba tartozik.
6. **A `Clock` bean átkerült** `push.PushConfig`-ból egy új
   `common.config.ClockConfig`-ba. Ez a §2.5-ben talált rejtett csatolás, és
   nemcsak a chatet érintette: a `TrainerWeeklyReportJob` is a push modulon
   keresztül jutott hozzá.
7. **Új domain-metódusok a `ChatConversation`-ön:** `peerOf(Long)` és
   `hasParticipant(Long)`. Ugyanaz a ternáris négy helyen volt kimásolva
   (mapper, broadcaster, receipt, notification); most egy helyen van.
   Ezzel `ChatMapper.peerIdOf` megszűnt, `ChatMapper.displayName` pedig
   átköltözött a `ChatUserDirectoryAdapter`-be — a név-fallback („név, ha van,
   különben e-mail") annak a modulnak a dolga, amelyik a user rekordot birtokolja.
8. **`ChatMapper.toConversationResponse` új paramétert kapott** (`ChatUser peer`),
   mert a beszélgetés már csak id-t hordoz.
9. **`getConversations` egy batch lekérdezéssel bővült** (`userDirectory.findAll`),
   ami a két peer `join fetch`-ét váltja ki. Nettó lekérdezésszám változatlan
   nagyságrendű, N+1 nincs.

#### 17.2.3 Tesztek: ami átköltözött

Két teszt-eset a chatből az adapterekbe került, mert a viselkedés is oda került.
**Nem veszett el lefedettség**, két új osztály tartja:

| Ami a chatben volt | Hol van most |
|---|---|
| `recipientWithoutSettingsRow_stillGetsPushed` | `settings.ChatPreferencesAdapterTest` (4 eset: default push/quiet/nyelv/offset, és a „eltűnt user → UTC" ág) |
| `openConversationWithUser_findsTheRelationshipInEitherDirection` | `trainer.ChatRelationshipGuardAdapterTest` (6 eset: aktív/visszavont/hiányzó link, mindkét irány, idegenek) |

A `ChatNotificationServiceImplTest` megfelelő esete
`recipientWithDefaultPreferences_isPushed` néven maradt — az továbbra is valós
állítás a szolgáltatásról, csak már nem a „nincs sor" ágról szól.

#### 17.2.4 Amit az M1 tudatosan nem szállít

- **A `ChatArchiveListener` marad `@EventListener`**, és ez az egyetlen
  megmaradt kifelé mutató import (`trainer.TrainerClientRevokedEvent`).
  Szándékos: az archiválásnak a revoke tranzakcióján belül kell történnie,
  amíg egy processzben futunk. **M4** cseréli webhookra (§5.4).
- **`BaseEntity`, `ResourceNotFoundException`, `ApiError`, `ApiErrorResponses`**
  importok megmaradnak — ezek a §3.2 szerint másolatként költöznek M3-ban.
- Semmilyen séma-, konfigurációs vagy kliens-változás.

#### 17.2.5 A kész-definíció mérése

```
$ grep -rh "^import com\.lifey" backend/src/main/java/com/lifey/chat \
    | grep -v "^import com\.lifey\.chat" | sort | uniq -c | sort -rn
   4 import com.lifey.common.domain.BaseEntity;
   2 import com.lifey.common.exception.ResourceNotFoundException;
   1 import com.lifey.trainer.TrainerClientRevokedEvent;
   1 import com.lifey.common.exception.ApiErrorResponses;
   1 import com.lifey.common.exception.ApiError;
```

Kiindulás: **16 import 6 modulból**. Most: **5 import, ebből 4 a `common`
infrastruktúra**, és egyetlen valódi modul-függés maradt, aminek pontosan
ismerjük a lejárati dátumát (M4).

Befelé: kizárólag a hét adapter hivatkozik a chatre, mindegyik egy olyan
interfészt implementálva, amit a chat definiál. A `GlobalExceptionHandler`
függése megszűnt.

#### 17.2.6 Döntések, amik kötik a következő lépéseket — M1

- **A `spi` csomag a kiemelés egysége.** M3-ban ez a 11 fájl változatlanul
  átmegy a `chat/`-ba, és ott kap JDBC (§4.4) illetve HTTP (§6.1)
  implementációt. A `ChatServiceImpl` egyetlen sora sem változik tőle.
- **A `ChatUser` szándékosan nem tartalmaz `firstName`/`lastName`-et.** Ha a
  chat service valaha maga akarna nevet formázni, az újra szétszórná a
  fallback-szabályt; a JDBC implementációnak ugyanúgy kész `displayName`-et kell
  visszaadnia.
- **A `ChatRelationship` nem hordoz státuszt.** A guard csak aktív linket ad
  vissza, tehát „a relationship a kezedben *maga* az engedély". Ezt a
  Fázis B (külön DB) tervezésekor is meg kell tartani — ott ez lesz az a pont,
  ahol a cache TTL-je értelmet nyer.

---

### 17.3 M2 — séma-tulajdonjog · ✅ KÉSZ (a DB-lépés kézi végrehajtásra vár)

Nem alkalmazás-kód. A mérföldkő terméke egy **gépi kényszer** (CI-őr), egy
**futtatható runbook** (Neon), és egy **lelet**, ami M3 sorrendjét megváltoztatta.
824 teszt változatlanul zöld.

#### 17.3.1 Mi készült el

**[`devops/check-schema-ownership.sh`](../../devops/check-schema-ownership.sh)** —
a build-idejű őr, bekötve a `backend-ci.yml`-be a Java setup *elé* (olcsó, és
ha megbukik, nincs értelme a 3 perces teszt-futásnak).

Mindkét irányt őrzi, és a két irány szabálya szándékosan **nem szimmetrikus**:

| Irány | Szabály | Miért ez |
|---|---|---|
| `backend/` → `chat_*` | **bármilyen említés** tiltott (3 történelmi kivétellel) | A monolitnak a cutover után semmi dolga ezekkel a táblákkal. A tompa szabály itt a helyes. |
| `chat/` → `users`/`user_settings`/`trainer_clients` | csak az **írás** tiltott (`alter`/`drop`/`insert`/`update`/`delete`) | Hivatkozni rájuk kell — az FK-k és a §4.4 projekciók pont ezt csinálják. Fázis A így néz ki. |

A `--` kommenteket levágja a vizsgálat előtt, tehát a chat sémára hivatkozó
magyarázó szöveg nem bukik meg rajta. **Önteszttel ellenőrizve**: egy
`alter table chat_participants ...` sor megbuktatja, egy `chat_messages`-t
említő komment nem.

A chat-oldali ág akkor lép működésbe, amikor a `chat/` mappa létrejön (M3) —
így M3-nak nem kell visszajönnie CI-t szerkeszteni.

**[`devops/chat-database-split.md`](../../devops/chat-database-split.md)** — a
runbook: jelszó-generálás, `create role` + a négy `grant` blokk, öt
ellenőrző lekérdezés (kettőnek sikerülnie, háromnak buknia kell), a
credential-ek helye, a lokális változat, és az Undo.

**Entitás-megjegyzések** a `User`, `UserSettings`, `TrainerClient` osztályokon:
melyik oszlopokat olvassa a chat service, és hogy ezek átnevezése törő változás
egy másik deployable-re nézve. Plusz egy sor a `backend/CLAUDE.md` szabályai
közé, a „soha ne szerkessz alkalmazott migrációt" mellé.

#### 17.3.2 A lelet: a baseline önmagában nem elég

A terv §4.2-je azt állította, hogy `baseline-on-migrate: true` +
`baseline-version: 999` megoldja a Flyway-hasítást. **Élesben igen, üres
adatbázison nem** — és pont az utóbbi az M3 két környezete (lokális fejlesztés,
a chat service Testcontainers-tesztjei). Részletek és a döntés: **§4.2.1**.

Ebből következik, hogy **M3 nem a kód átmozgatásával kezdődik, hanem a sémával**
(új 0. lépés a mérföldkőben). Ha fordítva csinálnánk, a chat service tesztjei
üres adatbázison futnának — zölden, anélkül hogy bármit ellenőriznének. Ez az a
fajta hiba, ami nem esik ki, csak később derül ki.

#### 17.3.3 Eltérések a tervtől

1. **A grantok nem zárják ki a monolitot a `chat_*` tábláiból**, és nem is
   szabad, hogy kizárják: a monolit a cutoverig futtatja a chatet, a `lifey`
   role-lal. A kizárás **cutover utáni** lépés, és bekerült a runbookba
   („After the cutover") azzal a figyelmeztetéssel, hogy elveszi a rollback-utat.
   A tervben ez implicit volt; kimondva biztonságosabb.
2. **A `push_devices` táblára nincs grant.** A terv §4.4-e négy projekciót
   sorolt fel, köztük egy `exists`-lekérdezést a `push_devices`-ra — de az M1-es
   döntés (§17.2.2/2) után a `hasRegisteredDevice` a `ChatPushSender`-en van,
   ami HTTP-n megy a monolithoz. Így a chatnek nem kell hozzáférnie.
3. **A CI-őr nem a tervezett „V68-nál újabb fájl" szabályt használja**, hanem
   egy néven nevezett allowlistet (`V64`, `V66`, `V67`). Robusztusabb: nem
   feltételez semmit a jövőbeli számozásról, és nem törik el, ha valaki
   visszamenőleg beszúr egy migrációt.

#### 17.3.4 Ami rád vár (kézi lépés)

A `lifey_chat` role létrehozása és a grantok **nem futottak le** — jelszót kell
generálni hozzá, ami nem az én dolgom. A runbook 1–4. lépése, kb. 10 perc.
A kész-definíció a runbook 3. lépésének harmadik lekérdezése: az
`insert into users` **hibára fut**.

Ez nem blokkolja M3 kódmunkájának a nagyját — lokálisan a `lifey` role-lal is
fejleszthető —, de **M6 előtt kötelező**, és az M3-as lokális kétszolgáltatásos
füstteszthez érdemes már megcsinálni, hogy egy jogosultsági hiba a gépeden
derüljön ki, ne Renderen.

#### 17.3.5 Döntések, amik kötik a következő lépéseket — M2

- **A `V64`/`V66`/`V67` örökre a `backend/`-ben marad**, és a CI-őr névvel
  ismeri őket. Ha valaha átszámoznánk vagy törölnénk őket, az őr allowlistjét
  is javítani kell — de a `flyway_schema_history` checksumjai miatt ez amúgy sem
  megengedett.
- **Egy adatbázis, két role, azonos JDBC URL.** A `lifey-chat` és a `lifey-api`
  `SPRING_DATASOURCE_URL`-je bitre azonos; csak a `_USERNAME`/`_PASSWORD` tér el.
  M6 előfeltétel-listáján ezt ellenőrizni kell, mert egy elgépelt host itt két
  külön adatbázist jelentene, csendben.

---

### 17.4 M3 — a `chat/` Maven projekt · ✅ KÉSZ

A `lifey-chat` fordul, elindul, és **162 saját tesztje zöld** — ebből 22 a
`ChatFlowIntegrationTest`, ami valódi Postgres ellen, saját sémával, a saját
JWT-ellenőrzésén keresztül fut. A monolit 824 tesztje változatlanul zöld.

#### 17.4.1 Mi készült el

**A modul:** `chat/` (`lifey-chat`), saját `pom.xml`, `Dockerfile`, `mvnw`.
76 fő forrásfájl + 14 teszt a `com.lifey.chat` csomagban, változatlan
csomagnévvel — a fájlok másolatok, nem újraírások.

**Séma (a §4.2.1 lelet szerint először):**
`V1000__chat_baseline.sql` idempotens formában (a V64+V66+V67 *végállapota*, nem
a történetük), és a teszt-only `V1__monolith_stub.sql`, ami a `users`,
`user_settings`, `trainer_clients` táblákat a §4.4 oszlopaival hozza létre.

**A hét port implementációja a másik oldalon:**

| Port | Chat-oldali implementáció |
|---|---|
| `ChatCaller` | `auth.ChatCallerAdapter` — a service saját security contextje |
| `ChatUserDirectory` | `spi.jdbc.JdbcChatUserDirectory` |
| `ChatNotificationPreferences` | `spi.jdbc.JdbcChatNotificationPreferences` — **egy** `left join` lekérdezés |
| `ChatRelationshipGuard` | `spi.jdbc.JdbcChatRelationshipGuard` — a két irány **egy** lekérdezésben |
| `ChatPushSender` | `spi.http.HttpChatPushSender` → `POST /internal/push` |
| `ChatMailSender` | `spi.http.NoopChatMailSender` (§6.3 szerint elhalasztva) |
| `ChatImageProcessor` | `common.image.ChatImageProcessorAdapter` (másolt `ImageReencoder`) |

**Infrastruktúra-másolatok:** `BaseEntity`, `ApiError`, `ApiErrorResponses`,
`ResourceNotFoundException`, `InvalidImageException`, `ImageReencoder`,
`WebCorsConfig`, `ClockConfig`, a JWT-oldal (lásd lentebb), és egy szűkített
`GlobalExceptionHandler`. **~430 sor**, a §3.2-ben becsült „100 sor fölött jöjjön
a shared modul" küszöb fölött — de a nagyja `ImageReencoder` (95 sor) és a
generikus hibakezelő (105 sor), amik között nulla közös változás várható. A
küszöböt tehát nem a sorszám, hanem az **együtt-változás** dönti el; ezt M7-nél
újra kell nézni.

**Deploy:** `chat/Dockerfile`, `render.yaml` második service-e, `chat-ci.yml`
workflow (a séma-őrrel és Testcontainers-szel).

#### 17.4.2 A mérés: a 96 MB metaspace téves volt

A terv §6.1-e 96 MB-ot feltételezett. A valóság:

| Mérés (prod profil, minden végpont megkopogtatva) | Érték |
|---|---|
| `-XX:MaxMetaspaceSize=96m` | **elindul, majd `OutOfMemoryError: Metaspace` az első kérésen** |
| tényleges metaspace-csúcs | **99,15 MB** (87,3 non-class + 11,9 class) |
| `-XX:MaxMetaspaceSize=128m` | 0 OOM, terhelés után is `UP`, ~29 MB tartalék |
| jar mérete | 66 MB vs. a monolit 126 MB-ja |

**A haszon valós, de kisebb a reméltnél: 64 MB metaspace-megtakarítás, nem 96.**
A heap 192m maradt (nem a tervezett 256m) — egy SSE-kapcsolat 107 KB, tehát 200
párhuzamos chatelő ~21 MB; nem a kapcsolatok töltik meg a heapet.

A `render.yaml`, a `chat/Dockerfile` és a §8.1 táblázat mind a mért értéket
tartalmazza.

#### 17.4.3 A kétszolgáltatásos ellenőrzés (jegyzőkönyv)

Lokálisan, `docker compose` Postgresszel, két JVM-mel:

1. `lifey-api` (8080) felépíti a sémát — a négy `chat_*` tábla létrejön.
2. `lifey-chat` (8081) indul: Flyway **baseline 999**, majd `V1000` lefut és
   **no-op** a meglévő táblákon. Ez a §4.2.1 döntés igazolása valódi közös
   adatbázison, nem csak üres teszt-DB-n.
3. Regisztráció + login a **monoliton** → access token.
4. **Ugyanaz a token a chat service-en:** `GET /api/v1/chat/conversations` →
   `200 {"items":[]}`, és a válasz **bitre azonos** a monolitéval. Ez az §5.3
   JWT-szerződés élő igazolása két külön processz között.
5. Minden chat-végpont megkopogtatva hitelesített tokennel: a nem-résztvevő
   mindenütt 404-et kap (a guard működik), `POST /presence` → 204,
   `GET /stream` → 200 (az SSE megnyílik).
6. Hibakezelés-paritás: egy hiányzó multipart paraméter **mindkét**
   szolgáltatásban 500 — azonos viselkedés, nem regresszió. (Javítható, de az
   eltérés a két szolgáltatás között nagyobb kockázat lenne, mint a hiba maga.)

#### 17.4.4 Eltérések a tervtől

1. **`git mv` helyett másolás.** A terv M3/2. lépése `git mv`-t írt, de a
   monolitbeli példánynak a cutoverig a helyén kell maradnia — ő a rollback-út.
   A törlés M7 dolga.
2. **`ChatArchiveListener` nem költözött** (a `TrainerClientRevokedEvent`-re
   iratkozó listener), és a tesztje sem. **M4 hozza vissza** internal
   endpointként. Lásd §17.4.5 — ez több, mint egy elhalasztott fájl.
3. **`JwtService` helyett `JwtVerifier`.** A név az aszimmetria: ebben a
   szolgáltatásban nincs `generateAccessToken`, nincs refresh-tábla, nincs mód
   credentialt kiadni. Az `iss` claimet is ellenőrzi (`requireIssuer`), amit a
   monolit filtere nem tesz.
4. **`UserPrincipal` szűkebb**: nincs `UserDetails`, nincs jelszó-hash, és a
   `roles` **string marad**, nem a `Role` enum. Így egy új szerepkör bevezetése
   a monolitban nem igényel release-t itt — enum-mal egy ismeretlen név
   `IllegalArgumentException`-t dobna a `Role.valueOf`-ban, és az egész kérést
   elutasítaná.
5. **`ChatPushSender.hasRegisteredDevice` a chat service-ben mindig `true`.**
   Csak az e-mail fallback kérdezi, ami §6.3 szerint kikapcsolva marad —
   végpontot építeni hozzá, amit senki nem hív, rosszabb lenne.
6. **Új metrika: `lifey.chat.internal.push`** (`outcome` = `ok` \| `failed`).
   A hálózati ugrás olyan hibamód, ami az in-process változatban nem létezett;
   a §12 táblázat előre jelezte, itt meg is valósult.
7. **A teszt-konfiguráció `application-test.yml` + `@ActiveProfiles("test")`.**
   Egy `src/test/resources/application.yml` **nem összefésülődik** a fővel,
   hanem teljesen elfedi (a test-classes előrébb van a classpathon) — a
   kontextus el sem indult tőle. Ez a fajta hiba nem magától értetődő; a fájl
   fejlécében ki van írva.

#### 17.4.5 ⚠️ Amit a munka talált: a §5.4 első rétege nem létezik

A terv §5.4-e azt állította, hogy Fázis A-ban „nincs stale ablak", mert a
`ChatRelationshipGuard` a küldésnél élőben látja a visszavont kapcsolatot.

**Ez nem igaz. A kódot ellenőriztem: a `sendMessage` út nem hívja a guardot.**
`ChatServiceImpl.store()` a résztvevőséget és a `conversation.archivedAt`
mezőt nézi — a `trainer_clients` táblát nem érinti. A guardot csak a szál
*megnyitása* használja.

Vagyis a küldést ténylegesen az **`archived_at` flag** állítja meg, amit ma a
`ChatArchiveListener` ír a revoke tranzakcióján belül. A kiválás után ez a
listener nincs, tehát a chat service-nek **jelenleg nincs útja** archiválni.

**Következmények:**
- **M6 (cutover) előtt ezt meg kell oldani** — jelen állapotban egy kiválasztott
  chat service korlátlanul fogadna üzenetet egy visszavont kapcsolat szálába.
- A megoldás **M4-be tartozik**, és két részből áll: (a) a revoke-webhook, ami
  az `archived_at`-et írja, **és** (b) egy `relationshipGuard.findActive(...)`
  hívás a küldés útján, ami a webhook elvesztésére is fedezetet ad. A (b)
  nélkül a webhook elvesztése 24 órás lyukat jelent a napi egyeztető söprésig.
- A §5.4 szövegét ennek megfelelően javítottam.

Az M3 lokális állapotában ez nem okoz kárt: a chat service nincs éles
forgalomban, a monolit pedig továbbra is a saját, tranzakción belüli
listenerével archivál.

#### 17.4.6 Döntések, amik kötik a következő lépéseket — M3

- **A `V1000` idempotens marad, örökre.** Ha valaki nem-idempotens állítást tesz
  bele, a friss adatbázis és az éles adatbázis viselkedése szétválik, és a
  különbség csak egy új környezet felállításakor derül ki.
- **A teszt-stub a read-szerződés súrlódási pontja.** Ha egy JDBC-projekció új
  oszlopot akar, azt **ugyanabban a commitban** fel kell venni a
  `V1__monolith_stub.sql`-be. Ez szándékos kellemetlenség: enélkül a chat
  észrevétlenül kezdene olyan oszlopra támaszkodni, amiről a monolit nem tud.
- **A hibakezelés paritása erősebb szabály, mint a hibakezelés minősége.** A
  hiányzó multipart paraméter 500-asa mindkét oldalon rossz — de amíg a
  kliensek mindkét szolgáltatással beszélnek, egy egyoldalú javítás nagyobb baj.
  M7 után javítható, egyszerre.

---

### 17.5 M4 — a szolgáltatások közötti felület · ✅ KÉSZ

**837** teszt zöld a monolitban (+13), **173** a chat service-ben (+11). A
mérföldkő két dolgot szállít: a §17.4.5-ben talált korrektségi lyuk befoltozását,
és a seam mindkét irányát.

#### 17.5.1 Mi készült el

**A küldés-úti guard (a fontos rész).** `ChatServiceImpl.store()` mostantól
megkérdezi a `ChatRelationshipGuard`-ot a beszélgetés `trainerClientId`-jével,
az `archivedAt` ellenőrzés *után*. Egy indexelt point-lookup üzenetenként.
Mindkét kódbázisban ugyanaz a kód. A monolitban ez ma no-op (ott a revoke
tranzakción belül archivál), a chat service-ben viszont **ez az, ami miatt egy
elveszett webhook nem jelent jogosultsági rést**.

Szándékosan **csak az írás útján**: az olvasás nem ellenőrzi, mert az előzmény
mindkét félnek örökre olvasható marad (§1.3/1).

**A seam, monolit oldal** (`com.lifey.internal`):

| Elem | Mit csinál |
|---|---|
| `InternalApiProperties` | `lifey.internal.*` — a közös titok, a chat URL-je, timeoutok |
| `InternalAuthFilter` | S2S auth, **konstans idejű** összehasonlítás |
| `InternalSecurityConfig` | külön `SecurityFilterChain` `@Order(HIGHEST_PRECEDENCE)`, `/internal/**`-ra |
| `InternalPushController` | `POST /internal/push` → 202. **Nem chat-specifikus** |
| `ChatRevokeWebhook` | `@TransactionalEventListener(AFTER_COMMIT)` → `POST /internal/relationships/revoked` |
| `ChatServiceClientConfig` | kimenő `RestClient` korlátozott timeoutokkal |

**A seam, chat oldal** (`com.lifey.internal`): ugyanaz a filter tükörképe, plusz
`InternalRelationshipController` (`POST /internal/relationships/revoked` → 204),
és a `ChatRelationshipReconciliationJob` (nightly, egy `update ... from` join).

**A cutover-kapcsolók:** `lifey.chat.local-enabled` (a 3 chat-controlleren, a
reminder jobon és a `ChatArchiveListener`-en `@ConditionalOnProperty`-vel), és
`GET /api/v1/client-config` a `lifey.chat.public-base-url` kiszolgálására.

#### 17.5.2 Két dolog, amit a tesztírás talált

**1. A kész-definíció „404" része hitelesítést igényel.** A terv azt írta, hogy
`CHAT_LOCAL_ENABLED=false` mellett a `/api/v1/chat/**` 404-et ad. Hitelesítetlen
hívásra **401 jön** — a Spring Security a védett útvonalakat azelőtt utasítja
el, hogy a dispatcher megnézné, van-e handler. A teszt ezért hitelesítve kérdez;
a DoD szövegét javítottam.

**2. Egy meglévő hiba: az ismeretlen útvonal 500-at adott, nem 404-et.** A
`GlobalExceptionHandler` catch-all `@ExceptionHandler(Exception.class)`-a
elnyelte a `NoResourceFoundException`-t. Ez nem az M4 munkája okozta, de pont a
cutover teszi láthatóvá: a 6. lépés után egy régi kliens 500-akat kapna 404
helyett, ami hibakereséskor rossz irányba küld. **Mindkét szolgáltatásban
javítva** — ez a *paritást megtartó* javítás, szemben a multipart-500-zal
(§17.4.6), amit épp azért hagytam, mert csak az egyik oldalon lett volna.

#### 17.5.3 Eltérések a tervtől

1. **A revoke-webhook pár alapú**, nem `trainerClientId` alapú. A terv
   `POST /internal/relationships/{trainerClientId}/revoked`-ot írt, de a
   `TrainerClientRevokedEvent` `(trainerId, clientId)`-t hordoz, és a chat
   `archiveForPair(trainerId, clientId)`-ja is így dolgozik. Ráadásul egy
   újra-meghívott kliens **több** történelmi szálat tarthat, és mind halott —
   a pár alapú hívás mindet lefagyasztja, az id alapú csak egyet.
2. **Nincs retry a webhookban.** Szándékos: az 1. réteg (guard) miatt egy
   elveszett hívás nem okoz jogosultsági kárt, a 3. réteg (söprés) pedig
   beállítja a flaget. Egy retry-sor harmadik mechanizmus lenne olyan
   problémára, amit kettő már megold.
3. **A söprés nightly, nem gyakoribb.** Csak a kozmetikai „a szál még aktívnak
   látszik" esetet javítja — a valódi értéke a `lifey.chat.relationship.reconciled`
   számláló, ami az **egyetlen** hely, ahol egy csendben elromlott webhook
   látszik. **Nulla az egészséges érték.**
4. **A `/internal/push` 202-t ad, nem 200-at.** A `PushService` soha nem dob,
   maga kezeli a hibáit — „átvéve kézbesítésre" az egyetlen őszinte válasz.
5. **A `ChatRevokeWebhook` a `com.lifey.internal` csomagban van**, nem a
   `com.lifey.chat`-ben. Muszáj: a chat-modult M7 törli a monolitból, ez a
   listener viszont utána is kell.

#### 17.5.4 Döntések, amik kötik a következő lépéseket — M4

- **Egy titok, két irány.** A chat service ugyanazt a
  `lifey.monolith.internal-token`-t használja a kimenő hívásokhoz és a bejövők
  ellenőrzéséhez. Egy dolgot kell rotálni, de a rotáció **mindkét service
  egyidejű újraindítását** igényli — M6 előfeltétel-listáján ez tétel.
- **Az üres titok zár, nem nyit.** Mindkét filter elutasít, ha nincs
  konfigurálva. Egy elfelejtett env-változó push-vesztés (hangos, javítható),
  nem pedig nyitott végpont, amivel bárkinek lehet értesítést küldeni.
- **A `lifey.chat.local-enabled` nincs benne a `ChatProperties` rekordban.**
  Csak `@ConditionalOnProperty` olvassa az Environmentből — így a rekord (és a
  több tucat teszt, ami konstruálja) érintetlen maradt, és M7-ben a flag
  nyomtalanul eltűnik.

---

### 17.6 M7 — a monolit leteszi a chatet · ✅ KÉSZ (előrehozva)

**Miért itt.** A munka közben kiderült, hogy a chat **soha nem került éles
adatbázisba**: a `main` a `V63`-nál tart, a V64–V67 csak a feature branchen
létezik, tehát Neon soha nem látta őket. Ezzel az egész átmeneti gépezet
tárgytalanná vált — nincs élő adat, nincs mihez visszagörgetni, és a „cutover"
nem átállás, hanem egyszerűen a chat első deployja. A migrációk így egyszerűen
**átköltöztek** a chat service-be, ami viszont maga után vonta a monolit
chat-moduljának törlését: enélkül a monolit `ddl-auto: validate`-je olyan
táblákat keresne, amiket már nem ő hoz létre — deploy-sorrendi függés két
service között.

#### 17.6.1 Mi történt

| | |
|---|---|
| `V64`/`V66`/`V67` | átköltözve, **egy** `V1000__chat.sql` végállapotként. Nincs `if not exists`: a chat hozza létre őket, nincs mit „megkerülni" |
| `V65` | **marad a backendben** — a `user_settings` a monolité, a chatnek csak `SELECT` joga van rá |
| `com.lifey.chat` (76 fájl + 16 teszt) | törölve a monolitból |
| a 7 `spi` adapter + 2 tesztjük | törölve |
| `lifey.chat.*` konfiguráció, `CHAT_LOCAL_ENABLED`, a reminder cron | törölve |
| `sendUnreadChatEmail` + 4 sablon + 2 i18n kulcs | Java törölve (halott kód); a **szövegek** átköltöztek a `chat/` alá, ahol a funkció újraépül, ha valaha bekapcsoljuk (§6.3) |
| `unaccent` extension | kikerült a chat migrációjából: a monolité (V48), és a `lifey_chat` role-nak amúgy sincs joga extensiont telepíteni. A teszt-stub hozza létre chat-only adatbázison |
| séma-őr allowlistje | **kiürült**, és a mechanizmus is kikerült — a szabály mostantól kivétel nélküli |

**Mérleg:** monolit 837 → **659** teszt (a chat 178 tesztje átment), chat service
173 → **189**.

#### 17.6.2 Amire figyelni kellett

**A törölt adapterek lefedettsége.** §17.2.3-ban azt írtam, hogy a lefedettség
nem veszett el, csak átköltözött az adapter-tesztekbe. Most azok az adapterek is
törlődtek — a lefedettségnek tehát **másodszor is költöznie kellett**, ezúttal a
chat service JDBC-implementációihoz, amiknek addig nem volt saját tesztjük.
Az új `JdbcProjectionsIntegrationTest` (16 eset, valódi Postgres) ezt tartja:
a name-fallback, a hiányzó settings sor defaultjai, a `PENDING`/`REVOKED`
szűrés, a mindkét irányú pár-keresés. **Ez a szolgáltatás legfontosabb tesztje** —
minden más Java, amit a fordító ellenőriz, ez viszont SQL-string egy másik
deployable sémájára.

**Maven `clean` kell törlés után.** A `target/classes` alatt maradt régi
`.class` fájlok miatt az egész teszt-készlet elszállt (`NoClassDefFoundError`
egy törölt osztályra), ami elsőre valódi hibának látszik. Nem az.

#### 17.6.3 Ami ebből a tervben elavult

- A **§10.3 cutover-runbook** kilenc lépése egy élő chat átállítására íródott.
  Az 1., 5., 6. és 7. lépés (a reminder job átadása, a `CHAT_LOCAL_ENABLED`
  átbillentése, a kapcsolatszám-figyelés) tárgytalan. Ami marad: a chat service
  deployja, a füstteszt, a `CHAT_PUBLIC_BASE_URL` beállítása, és a web
  CORS-ellenőrzés. **A §10 újraírása M6 első feladata.**
- A **§13/R3** (duplikált emlékeztetők) kockázat megszűnt.
- A **rollback** már nem „vissza a monolitra", hanem „`CHAT_PUBLIC_BASE_URL`
  kiürítése" → a kliensek a fő API-ra mennek, ahol a chat útvonalak 404-et
  adnak. Ez **nem** működő chat, csak tiszta hibakép. Ezt ki kell mondani M6-ban:
  a chat service leállása = nincs chat, nincs tartalék.

---

### 17.7 M5 — a kliensek · ✅ KÉSZ

Mobil **621** teszt zöld (+5), web **164** (+6), analyzer és `tsc` tiszta.

#### 17.7.1 Mi készült el

**Mobil.** `ClientConfigRepository` + `ClientConfigController` (SharedPreferences
cache-sel), `chatBaseUrlProvider`, `chatDioProvider`, és a `TokenRefresher` mint
külön, megosztott objektum. A `chat_repository` és a `ChatStreamClient` a chat
kliensre került; a `trainer_clients_repository` **maradt** a fő kliensen, immár
kommenttel, hogy miért.

**Web.** `lib/api/base-url.ts` (futásidejű feloldás, három lépcsős fallback),
`chatClient` a `client.ts`-ben, `lib/api/client-config.ts` (localStorage cache),
és a `chat-stream.ts` + `features/chat/api.ts` átkötése. A `Providers`-ben egy
fire-and-forget betöltés.

**A fallback-lánc mindkét platformon ugyanaz:** futásidejű válasz → build-time
érték (csak weben) → **a fő API base URL-je**. Egy elérhetetlen config-végpont
vagy egy beállítatlan env-változó tehát a szétvágás *előtti* viselkedésre esik
vissza, nem egy sehova nem mutató appra.

#### 17.7.2 A retry-út átnézése két hibát talált — az egyik súlyosabb volt

**1. A retry hoszt-ja (amit előre jeleztem).** Az `AuthInterceptor` a
`_mainDio.fetch(retryOptions)`-t hívta. Ez valójában *nem* rontotta volna el az
URL-t — a `RequestOptions` magával viszi a `baseUrl`-t —, de a chat kérésének
újrapróbálását a monolit Dio-ja diszpécselte volna, a saját interceptor-láncán
át. Törékeny és félreérthető. Most minden kliens **magán** próbál újra
(`retryDio` callback, mert a Dio még épül, amikor az interceptor létrejön).

**2. A megosztott refresh (ezt nem láttam előre, és ez a komolyabb).** Az
in-flight refresh future az interceptor **példány**mezője volt. Két Dio = két
interceptor = két privát future — vagyis pontosan az a verseny, amit az a mező
megelőzni hivatott. A refresh token **egyszer használatos**: két egyidejű
rotáció közül az egyik elhasznált tokennel megy, elbukik, és **kilépteti a
felhasználót ok nélkül**. A koordináció ezért kikerült egy közös
`TokenRefresher`-be, amit mindkét interceptor kap. Erre külön teszt van.

A refresh maga mindig a **fő API-ra** megy, akármelyik service adta a 401-et —
a chat service csak ellenőriz tokent, kiadni nem tud (§5.3).

#### 17.7.3 Eltérések a tervtől

1. **`StateNotifier` helyett `Notifier`** — a projekt Riverpod 3-at használ, a
   `StateNotifierProvider` már nincs. A meglévő `SessionExpiredNotifier` mintáját
   követi.
2. **A weben is futásidejű a feloldás**, nem csak build-time env. A terv §7.3-a
   env-változót írt fallbackkel; egy redeploy a weben gyors, de incidens közben
   az is build — és két kliens kétféle viselkedése önmagában is probléma. Az
   env-változó megmaradt harmadik lépcsőnek.
3. **Nincs TTL-alapú újratöltés.** A `ttl` érték tárolva van, de a mobil
   `reload()`-ját még senki nem hívja resume-kor. Ez **M6 feladata** — addig a
   config app-indításkor (mobil) és lapbetöltéskor (web) frissül, ami a
   cutoverhez elég, de egy futó appot nem ér el.

#### 17.7.4 Amit nem verifikáltam böngészőben

A változás base-URL-plumbing: két deployolt service kellene hozzá, hogy
böngészőben bármit mutasson. Amit helyette futtattam: `tsc --noEmit`, `eslint`,
164 web unit teszt (köztük 6 új, ami épp azt méri, melyik hívás melyik hosztra
megy), `flutter analyze` és 621 mobil teszt. A valódi böngésző-ellenőrzés a
**M6 cutover 8. lépése** (web füstteszt, CORS-szal együtt).

---

### 17.8 M6 — deploy-előkészítés · ✅ KÉSZ (a Render-lépések rád várnak)

Nem tudtam deployolni — az a te Render-fiókod és a te titkaid. Amit helyette
csináltam: **átírtam a runbookot** arra, ami ez valójában (első deploy, nem
cutover), lezártam a §17.7.3/3 nyitott tételt, és **végigmértem a teljes
útvonalat lokálisan, két processzen, friss adatbázison**.

#### 17.8.1 A lokális jegyzőkönyv

`docker compose down -v` után üres adatbázis, majd `lifey-api` (8080) és
`lifey-chat` (8081) éles jar-okból, `prod` profillal, a valódi env-készlettel.

| # | Amit mértem | Eredmény |
|---|---|---|
| 1 | A monolit indul, és **nem hoz létre chat táblát** | `flyway_schema_history` max = **65**, `chat_*` táblák száma = **0**. A `V64` hiányzik a történetből (63 → 65) — pontosan úgy, ahogy kell |
| 2 | A chat service saját sémát épít | `baselined schema with version: 999`, majd `Migrating ... to version "1000 - chat"`. Utána **4** `chat_*` tábla és **két** `flyway_schema_history*` |
| 3 | A monolit tokenje a chat service-en | szál megnyitva → **201**, és a `peer.displayName` = `"Kiss Anna"` — a JDBC projekció olvassa a monolit `users` tábláját |
| 4 | Üzenetküldés, a másik fél oldaláról olvasva | **201**, a kliens listájában `unreadCount: 1`, helyes előnézettel |
| 5 | chat → monolit push | `lifey.chat.internal.push{outcome=ok}` = **1.0**, `failed` = **0.0**; `push.decisions{sent}` = **1.0** |
| 6 | `GET /api/v1/client-config` | a chat URL-jét adja vissza, futásidőben |
| 7 | Revoke a monoliton (`DELETE /trainer/clients/{id}`) | 204, és a szál `archived_at`-je **azonnal** beáll — a webhook megérkezett |
| 8 | Küldés a visszavont szálba / olvasás ugyanott | **409** / **200** |

#### 17.8.2 A három réteg külön-külön igazolva

Ez volt a mérés valódi célja, mert a §17.4.5-ben talált lyuk épp itt záródik:

1. **Elveszett webhook szimulálva** — az `archived_at`-et kézzel visszaállítottam
   `NULL`-ra, miközben a `trainer_clients.status` `REVOKED` maradt. A küldés
   **így is 409-et kapott**, más üzenettel:
   `"Conversation is no longer backed by an active relationship"`. Az üzenet
   nem íródott be (a szálban maradt 1 üzenet). **A guard fog.**
2. **A webhook** a 7. pontban, azonnali hatással.
3. **A söprés** — a job SQL-jét kézzel lefuttatva egyetlen sort archivált,
   pontosan azt, amit az 1. pont hagyott flag nélkül.

#### 17.8.3 Mi változott a tervben

- **§10 újraírva.** Kilenc lépés helyett kilenc, de más: a hangsúly a
  **sorrenden** van (a monolitnak előbb kell futnia, mert a chat FK-i a `users`
  és `trainer_clients` táblákra mutatnak), és a 7. lépés — a
  `CHAT_PUBLIC_BASE_URL` — az egyetlen, ami a klienseket odaküldi. Előtte a chat
  service fut, de senki nem beszél vele; a füstteszt tehát olyan szolgáltatáson
  fut, amit még nem használ senki.
- **A rollback jelentése kimondva.** `CHAT_PUBLIC_BASE_URL` kiürítése **nem
  állítja vissza a chatet — megszünteti**: a monolit 404-et ad a chat
  útvonalakra. Ez legitim válasz egy elromlott chat service-re, de nem tartalék.
- **R3 (duplikált emlékeztetők) törölve** a kockázati táblából — a job csak egy
  helyen létezik.
- **`devops/chat-operations.md`** kapott egy „Where the chat lives" fejezetet,
  öt új tünet-sort, és a metrika-táblázat két új számlálót. A „Scaling out"
  már a `lifey-chat`-ről szól, azzal a megjegyzéssel, hogy a `lifey-api`
  **mostantól szabadon skálázható** — ez a szétvágás egyik nyeresége, amit
  könnyű elfelejteni.
- **`docs/02-architecture.md`** kapott egy „Chat service" fejezetet.

#### 17.8.4 A §17.7.3/3 lezárva

A `clientConfig.reload()` most a **foreground-ra** van kötve, egy saját
`WidgetsBindingObserver`-rel a `ClientConfigController`-ben. Nem a
`ConnectivitySyncController`-be került, ami a kézenfekvő hely lett volna: az
(közvetve) figyeli a `chatDioProvider`-t, tehát egy config-változás **azt az
objektumot építené újra, amelyik a változást kérte**. A `clientConfigProvider`
semmi olyat nem figyel, amit a válasz megváltoztathat — nincs kör.

#### 17.8.5 Ami rád vár

1. **Merge `main`-be.** Mindkét service innen deployol, és a `V65` meg a `V1000`
   egyetlen commitban jár együtt.
2. **A Neon grantok** — [devops/chat-database-split.md](../../devops/chat-database-split.md)
   1–3. lépés. Egy változás M3 óta: a `create extension` kikerült a chat
   migrációjából, tehát extension-jog nem kell.
3. **A §10.2 kilenc Render-lépése**, a §10.3 füsttesztjével.
