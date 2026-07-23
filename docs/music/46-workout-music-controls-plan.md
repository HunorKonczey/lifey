# 46 – Zenevezérlés edzés közben (Spotify / YouTube Music / Apple Music)

Status: terv kész + design kész + **M1 + M2 implementálva** (Dart-mag + UI-váz
+ Android MediaSession-híd) — lásd §8/§9; M3 (iOS Apple Music) a következő
lépés, Mac-hozzáférést igényel
Scope: csak mobil (Flutter + natív hidak) — **nincs backend-változás**
Design prompt: `47-workout-music-design-prompt.md`
Kész design: `Lifey Music Control.dc.html` (A–D elemek, sötét/világos, HU/EN) —
a design-review megállapításai a §6-ban, a javasolt fejlesztési irány a §7-ben
Érintett képernyő: `../../mobile/lib/features/workouts/presentation/log_session_screen.dart`

## 1. Mit építünk

Folyamatban lévő edzés (futó `LogSessionScreen`, `_finishedAt == null`) alatt a
felhasználó a telefonon szóló zenét az appból vezérelhesse, app-váltás nélkül:

1. **Szolgáltató-választás.** Első használatkor (vagy váltáskor) egy bottom
   sheet-ben kiválasztja: **Spotify**, **YouTube Music** vagy **Apple Music**.
   A választás eszköz-lokálisan megjegyzett — legközelebb már nem kérdezzük.
2. **Sticky zene-gomb.** A kiválasztott szolgáltató ikonja egy kis kerek
   gombként a sticky alsó zónába "ragad", a „Befejezés" gomb mellé. Lejátszás
   közben finoman animál (equalizer-pötty), így ránézésre látszik, szól-e zene.
3. **Mini lejátszó.** A gombra koppintva a szokásos lejátszó-sablon nyílik
   bottom sheet-ként: albumborító, szám címe + előadó, **előző / play-pause /
   következő** vezérlők, szolgáltató-chip, szolgáltató-váltás gomb.
4. **Csak futó edzés alatt él.** Befejezett/szerkesztett múltbeli session-ben a
   gomb nem jelenik meg. A funkció a zenét sosem indítja magától — ami már
   szól, azt vezérli.

Nem célja (out of scope): playlist-böngészés, keresés, konkrét szám indítása,
hangerő-szabályzás, saját audio-lejátszás, web app, watch-tükrözés (utóbbi
későbbi bővítés, a `WorkoutSessionState`-be már most nem tesszük bele).

## 2. Platform-valóság — ez határozza meg az egész architektúrát

### 2.1 Android: egyetlen univerzális híd (MediaSession)

Androidon a rendszer `MediaSessionManager.getActiveSessions()` API-ja **minden
aktív médialejátszást** (Spotify, YT Music, Apple Music, bármi) elér, teljes
vezérléssel és metaadattal — pontosan azt, amit a rendszer saját
médiaértesítése is használ. Egy implementáció fedi le mindhárom szolgáltatót,
**nem kell Spotify fejlesztői fiók, se OAuth, se hálózat**.

- Feltétel: a felhasználónak egyszer engedélyeznie kell az **értesítés-
  hozzáférést** (Notification access) az appnak — rendszerbeállítás,
  deep-linkkel odavisszük (`ACTION_NOTIFICATION_LISTENER_SETTINGS`, API 30+
  esetén `ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS` a saját komponensre
  szűrve). Ehhez kell egy (tartalmilag üres) `NotificationListenerService`
  alosztály a manifestben `BIND_NOTIFICATION_LISTENER_SERVICE` permission-nel —
  a `getActiveSessions()` ennek a komponensnek a nevével hívható.
- Vezérlés: `MediaController.transportControls.play() / pause() /
  skipToNext() / skipToPrevious()`.
- Állapot: `MediaController.Callback.onPlaybackStateChanged /
  onMetadataChanged` + `OnActiveSessionsChangedListener` → cím, előadó,
  play/pause állapot, albumborító (`METADATA_KEY_ALBUM_ART` bitmap → PNG
  byte-ok az EventChannel-en át).
- A szolgáltató-választás Androidon csak **package-név szűrés**:
  `com.spotify.music`, `com.google.android.apps.youtube.music`,
  `com.apple.android.music`. Android 11+ package-visibility miatt mindhárom
  package-re `<queries>` bejegyzés kell a manifestbe (telepítettség-
  detektáláshoz és app-indításhoz).
- Ha a választott appnak nincs aktív session-je (nem szól semmi): a mini
  lejátszó üres állapotot mutat „Indíts el egy lejátszást a(z) X-ben" CTA-val,
  ami launch-intenttel megnyitja az appot. Szándékosan nem próbálunk
  `KEYCODE_MEDIA_PLAY`-t diszpécselni — az a *legutóbbi* sessionhöz megy, ami
  lehet másik app is.
- **Play Store kockázat:** a notification-listener engedély használatát a
  Play-policy médiavezérlő use case-re elfogadja, de "prominent disclosure"
  kell: az engedélykérő sheet-ben világosan le kell írni, mire és miért kell
  (M2-ben kötelező szöveg, l10n-nel).

### 2.2 iOS: szolgáltatónként külön (és nem is teljes) a lefedettség

iOS-en **nincs** publikus API más appok lejátszásának vezérlésére (a privát
MediaRemote framework App Store-on tiltott). Ezért szolgáltatónként:

- **Apple Music** — `MPMusicPlayerController.systemMusicPlayer`: publikus,
  teljes értékű (play/pause/skip, `nowPlayingItem` metaadat + artwork,
  `playbackState`, változás-notificationök). Feltétel:
  `NSAppleMusicUsageDescription` az Info.plist-ben +
  `MPMediaLibrary.requestAuthorization` (a metaadat-olvasáshoz kell).
- **Spotify** — hivatalos **iOS App Remote SDK** (SpotifyiOS): app-to-app
  kapcsolat a telepített Spotify apphoz, play/pause/skip + playerState
  subscribe + artwork. Free fiókkal is működik. Feltételek:
  - **Külső előkövetelmény:** app-regisztráció a Spotify Developer
    Dashboard-on (Client ID + redirect URI, pl. `lifey://spotify-callback`) —
    ezt kézzel kell megcsinálni, a terv M4 mérföldköve enélkül nem indulhat.
  - Info.plist: `LSApplicationQueriesSchemes: [spotify]` + a redirect URI
    URL-séma regisztrálása.
  - Kapcsolódási sajátosság: az App Remote csak akkor tud csatlakozni, ha a
    Spotify fut és van aktív session-je; ha nem, `authorizeAndPlayURI("")`
    ébreszti fel (rövid app-váltással jár — ezt a UX-ben jelezni kell).
  - Flutter oldalról a `spotify_sdk` pub csomag wrappeli; **csak iOS-en**
    használjuk (Androidon a 2.1-es univerzális híd megy Spotify-ra is —
    egységesebb, és nem függ a Spotify SDK Android-oldali korlátaitól).
- **YouTube Music** — iOS-en **nincs** semmilyen vezérlő API vagy SDK.
  Döntés: a választóban iOS-en megjelenik, de **letiltva**, rövid indoklással
  („iOS-en a YouTube Music nem ad vezérlési lehetőséget más appoknak") —
  őszintébb, mint elrejteni, és megelőzi a „hol van?" kérdést.

Elvetett alternatíva: **Spotify Web API** (player endpointok) — Premium-only,
OAuth-token-infrastruktúrát igényelne a backenden, hálózati késleltetésű, és a
YT Music/Apple Music-ra amúgy sem ad megoldást. A lokális (app-to-app /
rendszer-session) vezérlés mindenhol jobb.

### 2.3 Támogatási mátrix (a UI-nak is ezt kell tükröznie)

| Szolgáltató | Android | iOS |
|---|---|---|
| Spotify | ✅ MediaSession | ✅ App Remote SDK |
| YouTube Music | ✅ MediaSession | ⛔ nem támogatott (letiltva, indoklással) |
| Apple Music | ✅ MediaSession | ✅ MPMusicPlayerController |

## 3. Kulcsdöntések

### 3.1 A választott szolgáltató eszköz-lokális, nem syncelt

A telepített zenei appok eszközönként különböznek (Androidon Apple Music ritka,
iOS-en YT Music nem is vezérelhető), ezért a választás **nem** kerül a syncelt
`UserSettings`-be. SharedPreferences-alapú kis prefs-osztály, a
`WeighInReminderPreferences` / `HealthPreferences` precedens szerint:
`core/music/music_preferences.dart`, kulcs: `workout_music_provider`
(enum-név string, null = még nincs választva). A 39-es terv §2.2-es érvelése
itt fordítva sül el: ez éppen a "per-device" eset.

### 3.2 Egy absztrakt `MusicService`, platformonként más összetételű impl

A watch-szolgáltatás mintáját követjük (`core/watch/watch_workout_service.dart`:
metódusok + event-stream, Riverpod provider):

```
mobile/lib/core/music/
  music_provider_id.dart   // enum: spotify, youtubeMusic, appleMusic + platform-elérhetőség
  music_preferences.dart   // eszköz-lokális választás (3.1)
  music_service.dart       // absztrakt interfész + állapotmodell
  music_service_android.dart  // MethodChannel/EventChannel → MediaSessionBridge (Kotlin)
  music_service_ios.dart      // AppleMusicBridge (Swift) + spotify_sdk kompozit
  music_controller.dart    // Riverpod controller: a UI egyetlen belépési pontja
```

Állapotmodell (a UI-nak ennyi kell, ennél többet ne):

```dart
enum MusicConnectionStatus { notConfigured, permissionNeeded, connectPrompt,
                             appNotInstalled, noActiveSession, connecting,
                             connected, error }

class MusicPlaybackState {
  final String? title; final String? artist;
  final Uint8List? artworkPng;   // null → placeholder ikon
  final bool isPlaying;
}

class MusicSessionState {
  final MusicProviderId? provider;
  final MusicConnectionStatus status;
  final MusicPlaybackState? playback; // csak connected mellett nem-null
}
```

Interfész: `selectProvider(id)`, `play()`, `pause()`, `next()`, `previous()`,
`openProviderApp()`, `requestPermission()` (Android: settings deep-link; iOS
Apple Music: MPMediaLibrary auth; iOS Spotify: authorizeAndPlayURI-ébresztés),
plusz `Stream<MusicSessionState>`. A vezérlő-hívások fire-and-forget jellegűek,
hibára a stream vált `error`-ra — a gombok nem várnak választ (a
`transportControls` amúgy sem ad).

A `connectPrompt` státusz **csak iOS Spotify-n** fordul elő: a design D3 lapja
szerint a kapcsolódás előtt egy előrejelző sheet-állapot áll („A Spotify egy
pillanatra megnyílik…" + Kapcsolódás CTA), mert az App Remote ébresztése
app-váltással jár — enélkül a váltás ijesztő „magától történő" ugrás lenne.
Sikertelen visszatéréskor a státusz `error`-ra vált (sticky gomb: figyelem-
pötty, sheet: C4 hiba-állapot).

Pozíció/progress-csík: **szándékosan kimarad** az első körből. Egyik platform
sem pusholja folyamatosan a pozíciót (interpolálni kellene tickerrel), a
transport-vezérléshez pedig nem kell. Ha később igény lesz rá, a
`MusicPlaybackState` bővíthető töréspont nélkül.

### 3.3 Életciklus: a `LogSessionScreen`-hez kötve, de a service a core-ban él

- A figyelés (session-listener / playerState-subscribe) csak akkor indul, ha a
  `LogSessionScreen` egy **futó** sessionnel áll fenn — a controller
  `activate()` / `deactivate()` hívásait a screen `initState`/`dispose` végzi
  (ugyanaz a minta, mint a `_hrTicker` HR-polling). Így nincs háttérben lógó
  listener, és a Riverpod-provider maga app-szintű maradhat.
- App-háttérbe kerülés: nem kell külön kezelni — Androidon a callback-ek
  élnek, amíg a Flutter engine él; visszatérve (`AppLifecycleState.resumed`)
  egy frissítő `refresh()` hívás szinkronizál (Spotify App Remote pl.
  háttérben bonthat, ekkor újracsatlakozás).
- Edzés befejezésekor (`_persistFinished`) a controller `deactivate()`-et kap;
  a zene természetesen szól tovább, csak mi nem figyeljük már.

### 3.4 UI-elhelyezés: a sticky alsó zóna lesz egy sor

A `LogSessionScreen` sticky alsó zónája (`Positioned(bottom: safeBottom + 24)`,
1637–1676. sor) ma egyetlen teljes szélességű „Befejezés" gomb. Ez lesz:

```
┌─────────────────────────────────────────┐
│ [♪ 54×54]  [   ✓ Befejezés (Expanded) ] │   ← bottom: safeBottom + 24
└─────────────────────────────────────────┘
```

- A zene-gomb 54×54 (a Finish gomb magasságával egyező), radius 20 (ugyanaz a
  formanyelv), `surfaceContainer` háttér + blur, a szolgáltató monokróm
  ikonjával. Lejátszás alatt 3-sávos mini-equalizer animáció **az ikon
  mellett** (a design A3 lapja eldöntötte: glyph + eq együtt, nem csere).
  `permissionNeeded`/`error` állapotban kis figyelmeztető pötty a sarkán.
- A `listBottomPad` számítás (1511. sor) változatlan — a zóna magassága nem nő.
- A gomb **mindig** látszik futó edzés alatt (akkor is, ha még nincs
  szolgáltató választva — akkor az első koppintás a választót nyitja). Így
  felfedezhető a funkció.
- A top bar szándékosan érintetlen: már most zsúfolt (timer + watch-pill + HR
  + kcal), egy hatodik pill nem fér el kis kijelzőn.

### 3.5 Sheet-ek: a meglévő modal-bottom-sheet minta

Mindkét sheet `showModalBottomSheet` + `useRootNavigator: true` +
`showDragHandle: true` (mint `AddExerciseToSessionSheet`), widgetek a
`features/workouts/presentation/widgets/` alatt:

- **`music_provider_picker_sheet.dart`** — 3 sor (ikon + név + állapot-
  alcím: „Nincs telepítve" / „iOS-en nem támogatott" / pipa a kiválasztotton).
  Telepítettség-detektálás: Android package-query (natív oldalon), iOS
  `canOpenURL` (`spotify:`, `youtubemusic://`, `music://` sémák a
  `LSApplicationQueriesSchemes`-ben). Nem telepített szolgáltató választható
  ugyan nem, de látszik — a mátrix (2.3) kommunikálása itt történik.
- **`music_player_sheet.dart`** — a lejátszó-sablon. Állapotai:
  1. `connected` + playback: artwork (64×64, radius md, placeholder-ikonnal) ·
     cím (1 sor, ellipsis) + előadó (halvány) · vezérlősor: ⏮ / ▶⏸ (nagy,
     primary-kör) / ⏭ · fejlécben szolgáltató-chip + „Váltás" szövegakció
     (visszanyitja a választót).
  2. `noActiveSession`: üres állapot + „Megnyitás: {szolgáltató}" CTA
     (`openProviderApp()`).
  3. `permissionNeeded` (Android): magyarázó szöveg (prominent disclosure,
     2.1) + „Engedély megadása" CTA (settings deep-link); visszatéréskor
     (lifecycle-resume) automatikus újraellenőrzés.
  4. `appNotInstalled` / `error`: rövid hibaszöveg + újrapróbálás.

### 3.6 Lokalizáció

Minden felhasználó felé néző szöveg HU/EN kulcsokkal az arb-fájlokba
(`../13-localization-guide.md` szerint): kb. 12–15 új kulcs
(`musicButtonTooltip`, `musicPickerTitle`, `musicProviderNotInstalled`,
`musicProviderUnsupportedIos`, `musicNoActiveSession`, `musicOpenAppButton`,
`musicPermissionExplanation`, `musicPermissionCta`, `musicSwitchProvider`,
`musicErrorGeneric`, …). A szolgáltatónevek (Spotify stb.) nem fordulnak.

## 4. Mérföldkövek (prompt-méretű egységek)

- **M1 — Dart-mag + UI-váz. ✅ Kész** — lásd §8. `core/music/` a 3.2 szerinti
  fájlokkal, egy stub-service-szel (mindig `noActiveSession`-t ad); prefs; a
  sticky zene-gomb a `LogSessionScreen`-en; a két sheet minden állapotával;
  l10n kulcsok. Ezzel a teljes UX végigkattintható valós híd nélkül.
- **M2 — Android MediaSession-híd. ✅ Kész** — lásd §9. Kotlin
  `MediaSessionBridge` + no-op `NotificationListenerService` + manifest
  (`<queries>`, permission); engedély-ellenőrzés/deep-link; Method/EventChannel;
  artwork-átvitel; a stub lecserélve `music_service_android.dart`-ra platform-
  ág szerint. **Kézi teszt valós eszközön mindhárom appal még hátravan** — csak
  a Dart-réteg és a Kotlin-fordítás van automatikusan ellenőrizve.
- **M3 — iOS Apple Music-híd.** Swift `AppleMusicBridge`
  (`MPMusicPlayerController.systemMusicPlayer` + notificationök), Info.plist
  kulcs, MPMediaLibrary-auth flow, `music_service_ios.dart` (egyelőre csak
  Apple Music-ággal; Spotify/YT a pickerben iOS-en még letiltva).
- **M4 — iOS Spotify (App Remote).** *Előfeltétel: Spotify Developer
  Dashboard-regisztráció (kézi lépés).* `spotify_sdk` beépítés iOS-re,
  redirect-séma, kapcsolódás/ébresztés flow, playerState-subscribe; a picker
  iOS-en engedélyezi a Spotify-t.
- **M5 — Polírozás + QA.** Equalizer-animáció, hiba-pötty, resume-refresh
  (3.3), edge-case-ek végigpróbálása (app kill mid-workout, engedély-visszavonás,
  szolgáltató-váltás lejátszás közben), végső l10n-átnézés.

Az M2/M3/M4 egymástól függetlenek (mind az M1-re épül) — sorrendjük igény
szerint cserélhető; az Android-híd (M2) adja a legtöbb értéket egy lépésben.

## 5. Kockázatok

- **Play-policy (notification access):** elutasítás-kockázat, ha a disclosure
  hiányos — az M2 engedély-sheet szövege kötelező elem, review-nál külön
  ellenőrizendő.
- **Spotify App Remote kapcsolódási UX:** az ébresztés app-váltással jár;
  rossz esetben a felhasználó „villanást" lát. A sheet-ben előre jelezzük
  („A Spotify egy pillanatra megnyílik").
- **YT Music iOS-hiány:** kommunikációs, nem műszaki kockázat — a letiltott
  sor indokló alcíme kezeli.
- **Emulátoron nem tesztelhető:** mindhárom híd valós eszközt és telepített
  zenei appokat igényel; a CI-ban csak a Dart-réteg (controller-állapotgép)
  unit-tesztelhető, a stub-service-szel.

## 6. Design-review megállapítások (`Lifey Music Control.dc.html`)

A design a terv minden elemét lefedi (A sticky zóna + gomb-állapotok + 360 dp
ellenőrzés, B választó, C lejátszó + üres/hiba, D engedélyek), sötét/világos
és HU/EN párban, token-spec táblával. Az implementációt érintő döntések és
eltérések:

1. **Equalizer: glyph + animáció együtt** (nem csere) — 3 sáv, 3 px széles,
   2 px radius, primary szín, ~0.8–1.0 s-os eltolt ease-in-out ciklusok
   (`eqa/eqb/eqc` keyframe-ek a designban). Reduce-motion esetén statikus
   középmagas sávok.
2. **Figyelem-pötty színe: eltérés a kódbázistól.** A design `#E08A52`-t ad
   meg (2 px ringgel a gomb hátteréből); a kódban létező warn-szín a
   `#D66B5A` (`_RestBanner._warnColor`, törlés-dialógok). **Döntés: a meglévő
   `#D66B5A`-t használjuk** — nem vezetünk be egy egyszeri új színt egy 10 px-es
   pöttyért; ha később „notice" token születik a design rendszerben, átáll.
3. **Sheet-fejléc a lejátszóban:** szolgáltató-chip tonal pillként (24 px
   glyph-kör + név), jobbra `swap_horiz` ikonos „Váltás" szövegakció. A
   választó-sheet kiválasztott sora: primary 14% háttér + 1.5 px primary 45%
   keret + `check_circle`; a tiltott sor teljes egészében 42–45% opacity és
   nem tappolható.
4. **Vezérlő-méretek:** play/pause 64-es primary kör (a sheet vizuális
   központja), prev/next 48×48 (radius 16, `surfaceContainerLow`) — minden
   célpont ≥ 48 dp, ezt tartani kell.
5. **Kilépő animáció:** a gomb eltűnésekor a Befejezés ~200 ms alatt nő
   vissza teljes szélességre (standard easing) — `AnimatedSize`/implicit
   animációval olcsó; gyakorlatban ritkán látszik (befejezéskor a képernyő
   navigál), alacsony prioritás (M5).
6. **Picker-státusz feliratok:** a design „Csatlakoztatva" / „Elérhető"
   alcímeket is használ → két további l10n kulcs a 3.6-os listához
   (`musicProviderConnected`, `musicProviderAvailable`), plusz a
   kapcsolódás-előrejelző szövegei (`musicConnectTitle`, `musicConnectBody`,
   `musicConnectCta`, `musicNotNow`).
7. **Szolgáltató-glyph: placeholder monogramok.** A designban az S/A/YT
   monogramok szándékos placeholderek a végleges **monokróm** brand-ikonokig.
   Nyitott feladat (M1-ben monogrammal indulunk, M5-ben cserélhető): ikonok
   beszerzése a brand-guideline-ok szerint — a Spotify guideline pl. előírja a
   logó minimális méretét és tiltja a módosítást; a monokróm változat
   engedélyezett. Ha a guideline-megfelelés bizonytalan, a monogram
   véglegesnek is elfogadható (semleges, védjegy-kockázat nélkül).
8. **D1/D2 disclosure-szöveg** („…más értesítésedet nem olvassa") — ez a
   Play-policy szempontból kulcsmondat, szó szerint átveendő az arb-fájlokba.

## 7. Javasolt fejlesztési irány

**Android-first sorrend.** A fejlesztői környezet Windows (iOS build/teszt
helyben nem lehetséges), és az Android-híd (M2) egyetlen implementációval
mindhárom szolgáltatót lefedi. Ezért:

1. **M1 — Dart-mag + UI-váz** (1 prompt): a 3.2 szerinti `core/music/` réteg
   stub-service-szel + a teljes UI a kész design tokenjeivel. Konkrét
   érintések:
   - új: `core/music/` (6 fájl a 3.2 szerint, a stub a
     `music_service.dart`-ban `MusicServiceStub`-ként);
   - új: `features/workouts/presentation/widgets/music_provider_picker_sheet.dart`,
     `music_player_sheet.dart`, `music_sticky_button.dart` (a gomb a 4
     állapotával + equalizer-animációval, `TickerProviderStateMixin`);
   - módosul: `log_session_screen.dart` — a sticky zóna `Row`-vá alakul
     (3.4), controller `activate()`/`deactivate()` az `initState`/`dispose`-ban;
   - l10n: ~18 kulcs (3.6 + §6.6) az `app_en.arb`/`app_hu.arb`-ba;
   - unit-teszt: a controller állapot-átmenetei a stubbal.
   A kör végén a teljes UX végigkattintható emulátoron is.
2. **M2 — Android MediaSession-híd** (1–2 prompt): Kotlin oldal + engedély-flow
   a 2.1 szerint; kézi teszt valós eszközön Spotify + YT Music appokkal.
   **Ezzel a funkció Androidon shippelhető** — iOS-en a gomb az M1-es stubbal
   `notConfigured`/letiltott állapotot mutat, ami korrekt köztes állapot
   (az app nincs kiadva, memory: nincs release-koordináció).
3. **Párhuzamos kézi lépés:** Spotify Developer Dashboard-regisztráció
   (Client ID + `lifey://spotify-callback` redirect) — bármikor elintézhető,
   csak az M4-et blokkolja.
4. **M3 + M4 — iOS hidak** (Mac-hozzáférés függő): előbb Apple Music (M3,
   egyszerűbb, nincs külső függés), aztán Spotify App Remote (M4, a
   `connectPrompt` flow-val). Xcode-os build és valós iPhone kell hozzá.
5. **M5 — polírozás**: §6.5 kilépő animáció, glyph-asset csere (§6.7),
   edge-case QA a 4. szakasz szerint.

Az első konkrét lépés tehát az **M1 prompt**: „Implementáld a
docs/music/46-workout-music-controls-plan.md M1 mérföldkövét a
docs/music/Lifey Music Control.dc.html design szerint."

## 8. M1 megvalósítás — jegyzőkönyv

Elkészült fájlok:

- `mobile/lib/core/music/music_provider_id.dart` — `MusicProviderId` enum +
  `displayName`/`monogram`/`isSupportedOnThisPlatform`.
- `mobile/lib/core/music/music_preferences.dart` — eszköz-lokális választás
  (`shared_preferences`, 3.1 szerint).
- `mobile/lib/core/music/music_service.dart` — `MusicConnectionStatus`,
  `MusicPlaybackState`, `MusicSessionState`, az absztrakt `MusicService`
  interfész és az M1-es `MusicServiceStub` + `musicServiceProvider`.
- `mobile/lib/core/music/music_controller.dart` — `MusicController`
  (`Notifier<MusicSessionState>`) + `musicControllerProvider`.
- `mobile/lib/features/workouts/presentation/widgets/provider_glyph.dart`,
  `music_provider_picker_sheet.dart`, `music_player_sheet.dart`,
  `music_sticky_button.dart` — a design (`Lifey Music Control.dc.html`) A–D
  elemei, minden state-tel (a ténylegesen elérhetetlen `connectPrompt`/
  `permissionNeeded`/`connecting`/`error` ágak is megvannak, csak az M1-es
  stub sosem lép be rájuk — M2/M3/M4 aktiválja).
- `mobile/lib/features/workouts/presentation/log_session_screen.dart` —
  bekötve: `_musicActivated`/`_musicController` mező,
  `_activateMusic()`/`_deactivateMusic()` (initState / `_persistFinished` /
  dispose), a sticky zóna `Row`-vá alakítva (`MusicStickyButton` +
  `Expanded(Befejezés)`).
- 22 l10n kulcs mindkét arb-fájlban (`app_en.arb`/`app_hu.arb`), generálva
  (`flutter gen-l10n`).
- `mobile/test/core/music/music_preferences_test.dart`,
  `music_controller_test.dart` — 9 teszt, mind zöld.

### Döntés: az aktiválás a "nem befejezett session", nem a "ticker indult"

A §3.3 szövege a `LogSessionScreen` `initState`/`dispose`-hoz köti az
activate()/deactivate() hívásokat, de nem mondja ki pontosan *melyik*
initState-ági feltételhez. Implementációban a `_finishedAt == null` feltételt
választottam (ugyanaz, mint `isLogSessionScreenOpen` és a `showFinishButton`
gating), NEM a három "ticker indul" call site-ot (initState meglévő futó
session, `_startScheduledSession`, `_persist` első mentése) — mert a
"Befejezés" gomb (és most már a zene-gomb is) az első frame-től látszik egy
vadonatúj, még nem persistált session-nél is, tehát a zenevezérlésnek is
onnantól élnie kell, nem csak az első set logolása után. Egyetlen sor az
`initState`-ben (`isLogSessionScreenOpen = true` mellett), a
`_startScheduledSession`/`_persist` ág külön hívás nélkül lefedve. A
`_persistFinished` a tickerekhez hasonlóan explicit deaktivál (nem várja meg a
`dispose`-t), mert a képernyő a feedback-sheet/success-dialog alatt még él.

### Talált és javított hiba: broadcast StreamController versenyhelyzet

Az első `MusicServiceStub` implementáció egy `async*` generátorral
"visszajátszotta" az aktuális állapotot minden új feliratkozónak
(`yield _current; yield* _controller.stream;`). Ez versenyhelyzethez vezetett:
ha egy `_emit()` egy már `await`-elt hívás belsejéből (pl.
`activate()`-ben az `await _preferences.selectedProvider()` után) fut le, a
generátor belső feliratkozása a `_controller.stream`-re néha még nem
történt meg — az esemény némán elveszett, és a `MusicController` állapota
`notConfigured` maradt annak ellenére, hogy egy szolgáltató épp ki lett
választva. Unit teszttel (`music_controller_test.dart`) sikerült
reprodukálni. A végleges megoldás: sima `StreamController.broadcast(sync:
true)` + egyszerű `_controller.stream` getter (nincs generátor, nincs manuális
visszajátszás) — mivel a `MusicController.activate()` mindig előbb
feliratkozik, majd utána hívja a service `activate()`-jét (ami mindig emittál
egy friss állapotot), a visszajátszás felesleges is volt. `sync: true` azért
biztonságos itt, mert semmi nem hív `_emit()`-et egy ugyanerre a stream-re
feliratkozott listener callback-jén belülről (nincs reentrancy-kockázat).

Ez a hiba éles környezetben (M2/M3/M4 valós híddal) is jelentkezett volna:
minden `LogSessionScreen.initState → _activateMusic() → activate()` hívás
pontosan ugyanezt a "feliratkozás, majd rögtön utána egy await-elt hívás
végén emittálás" mintát követi, tehát egy korábban már kiválasztott
szolgáltatóval rendelkező, újra megnyitott futó session esetén a zene-gomb az
első frame(ek)en hibásan "nincs beállítva" állapotot mutathatott volna.

### Ellenőrzés

`flutter analyze lib` és a célzott `flutter test` (music + workouts + watch +
workout_session_notifier, összesen 83 teszt) tiszta; a meglévő
`log_session_screen.dart` viselkedés (rest timer, watch-pillek, autosave)
nem változott, csak a sticky zóna elrendezése.

### Következő lépés (M1 lezárásakor)

M2 — Android MediaSession-híd (§4/§7 pont 2): a `MusicServiceStub` lecserélése
egy valós Kotlin hídra, a notification-access engedélyfolyammal. Ehhez már
valós Android-eszköz/emulátor kell (a Dart-réteg tesztje itt megáll).

## 9. M2 megvalósítás — jegyzőkönyv

Elkészült/módosult fájlok:

- `mobile/lib/core/music/music_service_android.dart` (új) — `MusicServiceAndroid
  implements MusicService`: `lifey/music` MethodChannel + `lifey/music/events`
  EventChannel, ugyanaz a "best-effort, sosem dob" minta mint
  `WatchWorkoutService`-nél.
- `mobile/lib/core/music/music_service.dart` — `MusicPlaybackState.fromJson`/
  `MusicSessionState.fromJson` faktorok a natív payload dekódolásához;
  `musicServiceProvider` kikerült innen (ciklikus import elkerülése miatt,
  lásd lent).
- `mobile/lib/core/music/music_controller.dart` — platform-ág:
  `musicServiceProvider` most itt dől el (`Platform.isAndroid` →
  `MusicServiceAndroid`, egyébként `MusicServiceStub`, amíg M3/M4 nem lép be).
- `mobile/lib/features/workouts/presentation/widgets/music_provider_picker_sheet.dart`
  — a felesleges `music_service.dart` import törölve (a providert már
  `music_controller.dart`-ból kapja).
- `mobile/android/app/src/main/kotlin/com/khunor/lifey/MediaSessionBridge.kt`
  (új) — a fő híd: `MediaSessionManager` alapú session-követés, állapotgép
  (`notConfigured`/`permissionNeeded`/`appNotInstalled`/`noActiveSession`/
  `connected`/`error`), package-név-alapú szolgáltató-szűrés, transport-
  vezérlés, artwork-kinyerés + downscale (max 300 px) + PNG-kódolás.
- `mobile/android/app/src/main/kotlin/com/khunor/lifey/MusicNotificationListenerService.kt`
  (új) — no-op `NotificationListenerService`; `onListenerConnected`/
  `onListenerDisconnected` visszahív a `MediaSessionBridge`-be.
- `mobile/android/app/src/main/kotlin/com/khunor/lifey/MainActivity.kt` —
  `MediaSessionBridge` regisztrálva `configureFlutterEngine`-ben, a
  `WatchBridge` mintáját követve.
- `mobile/android/app/src/main/AndroidManifest.xml` — `<service>` a
  notification-listenerhez (`BIND_NOTIFICATION_LISTENER_SERVICE` permission);
  `<queries>` a három szolgáltató package-nevéhez (`com.spotify.music`,
  `com.google.android.apps.youtube.music`, `com.apple.android.music`).
- `mobile/test/core/music/music_service_android_test.dart` (új) — 9 teszt:
  MethodChannel-hívások (activate/selectProvider/isProviderInstalled/
  play-pause-next-previous/stb.) + EventChannel-dekódolás (connected/
  noActiveSession/permissionNeeded).

### Döntés: a natív oldal nem tartja meg a kiválasztott szolgáltatót

A `MediaSessionBridge`-ben a `currentProviderId` `deactivate()`-kor törlődik,
és minden `activate()` hívás újra megkapja Dart felől (ami mindig frissen
olvassa a `MusicPreferences`-t). Így a natív oldal state-mentes a
aktiválási ciklusok között — nem lehet elavult providerrel dolgozó zombi-
állapota egy korábbi session-ből.

### Döntés: engedély-visszajelzés push, nem poll

A tervben szereplő "visszatérve (`AppLifecycleState.resumed`) egy frissítő
`refresh()` hívás szinkronizál" (§3.3) helyett Androidon a natív oldal saját
maga értesíti Dartot: `MusicNotificationListenerService.onListenerConnected()`
azonnal lefut, amint az OS a Beállításokból visszatérve (újra)bindeli a
listenert, és ez visszahív a `MediaSessionBridge`-be, ami friss állapotot
emittál az EventChannelen. Emiatt **nem kellett** `WidgetsBindingObserver`-t
bevezetni a `LogSessionScreen`-be — a natív push megbízhatóbb és azonnalibb,
mint egy Dart-oldali resume-hook. (Az iOS Spotify-ág M4-ben viszont
valószínűleg tényleg igényelni fogja majd a resume-hookot, mivel az App
Remote kapcsolat elvesztése/visszaszerzése nem jár ilyen natív eseménnyel.)

### Döntés: `getPackageInfo` API 33+ ág

A build első köre egy deprecation-warningot dobott a `PackageManager.
getPackageInfo(String, Int)` hívásra (deprecated API 33 óta). Mivel a
`compileSdk` 36, ez idővel Play-review figyelmeztetést is adhatna — API
33+ (`Build.VERSION_CODES.TIRAMISU`) ágon az új
`getPackageInfo(String, PackageManager.PackageInfoFlags)` túlterhelést
használja, alatta a régit (`@Suppress("DEPRECATION")`-nel jelölve, hogy
szándékos).

### Ellenőrzés

- `flutter analyze lib` és a teljes `flutter test` (292 teszt) tiszta.
- **`flutter build apk --debug --target-platform android-arm64` kétszer
  lefutott sikeresen** — ez az egyetlen realisztikus automatikus ellenőrzés a
  Kotlin-kódra ebben a környezetben (nincs Android-eszköz/emulátor csatolva,
  úgyhogy a `MediaSessionManager`/`NotificationListenerService` valós
  viselkedése, és a három konkrét appal (Spotify/Apple Music/YouTube Music)
  való működés **nincs kézzel letesztelve** — ez a §4-ben eredetileg is jelzett
  korlát).

### Következő lépés

Kézi teszt valós Android-eszközön (Spotify, YouTube Music, Apple Music
telepítve): engedélykérés-folyam végigcsinálása, lejátszás-vezérlés,
szolgáltató-váltás, app-eltávolítás közbeni viselkedés. Utána M3 — iOS Apple
Music-híd (§4/§7 pont 4), Mac-hozzáférést igényel.
