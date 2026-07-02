# Running the Lifey mobile app

The app talks to the Spring Boot backend, so **start the backend first** in every case.

## 0. Start the backend

```bash
# from the repo root
docker compose up -d postgres
cd backend && ./mvnw spring-boot:run     # serves http://localhost:8080
```

The base URL is resolved automatically (`lib/core/network/api_config.dart`):

| Target                  | Base URL used                                                  |
|-------------------------|-----------------------------------------------------------------|
| Android emulator        | `http://10.0.2.2:8080/api/v1`                                    |
| Web                     | `http://localhost:8080/api/v1`                                   |
| iOS — **any** target (simulator or physical) | the deployed Railway backend, `https://lifey-production-7aa5.up.railway.app/api/v1` |
| Physical Android device, or a local backend on iOS | pass `--dart-define=API_BASE_URL=…` to override |

iOS defaults to the deployed backend because a physical iPhone can't reach
`localhost` (that resolves to the phone itself, not your Mac) — see the
override examples in section 2 if you want the simulator talking to a
backend running on your Mac instead.

---

## 0.5. Generate Drift/Riverpod code

`*.g.dart` files (Drift tables, Riverpod providers) are gitignored and not
committed. After a fresh checkout, switching branches, or any change to a
Drift table or `@riverpod`-annotated provider, regenerate them:

```bash
cd mobile
dart run build_runner build --delete-conflicting-outputs
```

Skipping this causes build failures like `Error: Type 'FooRow' not found` or
`No named parameter with the name 'bar'` — the generated code is out of sync
with the table/provider source. Emulators and simulators often mask this
because a prior debug session left a stale-but-working `.g.dart` in place;
a release build for a physical device (section 2, step 3) is where it
typically surfaces.

---

## 1. Android emulator (recommended on Windows)

One-time setup:
1. Install **Android Studio** (includes the Android SDK + emulator).
2. In Android Studio: *Device Manager → Create device* → pick a phone + a system image (API 34+).

Run:
```bash
cd mobile
flutter emulators                       # list available emulators
flutter emulators --launch <emulator_id>
flutter run                             # pick the emulator if prompted
```

The emulator reaches the host machine's backend via `10.0.2.2` (already wired up).
Cleartext HTTP is enabled for dev in `android/app/src/main/AndroidManifest.xml`.

Hot reload: press `r` in the terminal; hot restart: `R`; quit: `q`.

---

## 2. macOS — iOS simulator & physical iPhone

The cleanest way to run on iOS, since you have a Mac. Run the backend on the
Mac too (section 0), or point at a backend elsewhere with `--dart-define`.

### One-time setup
1. Install **Xcode** from the App Store, open it once to finish component
   installation, then:
   ```bash
   sudo xcodebuild -license accept
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```
2. Install **CocoaPods** (used for iOS plugin deps):
   ```bash
   sudo gem install cocoapods
   ```
3. Check the toolchain and fix anything it flags:
   ```bash
   flutter doctor
   ```

> Cleartext HTTP for dev is already enabled in `ios/Runner/Info.plist`
> (`NSAllowsArbitraryLoads`), so the app can call a plain `http://` backend
> when you override the URL (e.g. testing against a local backend).

### iOS Simulator
```bash
open -a Simulator
cd mobile
flutter devices        # confirm the simulator shows up
flutter run            # pick the simulator
```
By default this hits the deployed Railway backend (see the table above). To
point the simulator at a backend running on your Mac instead:
```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8080/api/v1
```
(The simulator shares the Mac's network, so plain `localhost` works there —
unlike on a physical device.)

### Physical iPhone (USB) — full walkthrough

#### 1. Connect the phone
1. Plug the iPhone into the Mac with a USB/USB-C cable.
2. On the phone, tap **Trust This Computer** when prompted, then enter your
   passcode.
3. **iOS 16+: enable Developer Mode** (one-time, required to run
   Xcode-built apps on the device):
   - On the iPhone: **Settings → Privacy & Security → Developer Mode → On**.
   - The phone asks to restart — let it.
   - After the restart, confirm **Turn On** in the dialog that appears.
4. Confirm the Mac sees it:
   ```bash
   cd mobile
   flutter devices
   ```
   The iPhone's name and a device id should show up in the list.

#### 2. Set up code signing (one-time per Mac)
1. Open the workspace — **not** the `.xcodeproj`:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. In the left sidebar select the **Runner** project → **Runner** target →
   **Signing & Capabilities** tab.
3. If no Apple ID is configured yet in Xcode: **Xcode → Settings →
   Accounts → "+"** → sign in. A free personal Apple ID is enough for
   on-device development (no paid account needed).
4. Back on **Signing & Capabilities**: tick **Automatically manage
   signing**, then pick your **Team** (your name / "Personal Team").
5. If Xcode rejects the bundle id (`com.khunor.lifey`) as already taken —
   rare with a free personal team, but possible — change it to something
   unique, e.g. `com.khunor.lifey.<yourname>`, in that same tab.
6. The first time Xcode generates your signing certificate, **macOS will
   prompt**: *"codesign wants to access key 'Apple Development: ...' in
   your keychain."* This is asking for **your Mac's login password** (the
   one you unlock the screen with) — it is not a project or Apple ID
   password. Enter it and click **Always Allow** (not just "Allow"), so it
   doesn't ask again on every rebuild.

> **Free Apple ID limitation:** the signing certificate this generates
> expires after **7 days**. After that, the app on the phone shows as
> "expired" until you re-run step 3 below to re-sign it. A paid Apple
> Developer Program membership ($99/yr) removes this limit and also
> enables TestFlight distribution.

#### 3. Run it
```bash
cd mobile
flutter run --release -d <device-id>
```
- Get `<device-id>` from `flutter devices`; you can omit `-d ...` entirely
  if the iPhone is the only device connected.
- `--release` is recommended for a phone you're just using day-to-day
  (faster, no attached debug session needed). Drop it if you want to set
  breakpoints / hot reload from the Mac.
- No `--dart-define` needed — iOS already defaults to the deployed Railway
  backend. Only add `--dart-define=API_BASE_URL=...` if you want this
  build to talk to a *different* backend instead — e.g. one running
  locally on the Mac, reached over the LAN (the phone can't use
  `localhost`, that's itself):
  ```bash
  ipconfig getifaddr en0     # Mac's LAN IP, e.g. 192.168.0.42
  flutter run --release -d <device-id> \
    --dart-define=API_BASE_URL=http://192.168.0.42:8080/api/v1
  ```
  Keep the iPhone and Mac on the same Wi-Fi for this to work.

#### 4. First launch: trust the developer profile
The very first time you open the app on the phone, iOS blocks it with an
**"Untrusted Developer"** alert. Fix once:
**Settings → General → VPN & Device Management** → tap your Apple ID under
**Developer App** → **Trust "<your Apple ID>"** → confirm **Trust**.

After that, the app icon launches normally from the home screen like any
other app — until the 7-day free-signing expiry mentioned above, at which
point repeat step 3 (no need to redo steps 1-2 or the trust step unless
something else changed).

---

## 3. Web / Chrome (quickest, no emulator)

```bash
cd mobile
flutter run -d chrome
```

Uses `http://localhost:8080`; the backend already allows CORS for dev
(`WebCorsConfig`). Good for fast UI iteration.

---

## 4. Testing on a physical iPhone from Windows

> A native iOS build **cannot** be produced on Windows — Apple's toolchain
> (Xcode) only runs on macOS. Two realistic options:

### Option A — Web app in iPhone Safari (no Mac, ~2 min)
Best for quickly checking the UI/data on the actual phone.

1. Find your PC's LAN IP: run `ipconfig` and note the IPv4 address (e.g. `192.168.0.42`).
2. Make sure the backend is reachable on the LAN (allow port 8080 through the
   Windows Firewall; Spring binds to all interfaces by default).
3. Serve the web build bound to the LAN, pointing the app at the PC's IP:
   ```bash
   cd mobile
   flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8090 ^
     --dart-define=API_BASE_URL=http://192.168.0.42:8080/api/v1
   ```
4. On the iPhone (same Wi-Fi), open Safari → `http://192.168.0.42:8090`.
   Tap *Share → Add to Home Screen* for an app-like icon.

CORS is already enabled, so the API calls work from Safari.

### Option B — Native iOS build via cloud macOS → TestFlight (proper, paid)
For a real installable native app:

1. Push the repo to GitHub.
2. Use **Codemagic** (free tier) or another macOS CI to build the iOS app —
   it runs `flutter build ipa` on a cloud Mac.
3. Distribute to your iPhone via **TestFlight**.
   - Requires an **Apple Developer Program** membership ($99/yr) for signing
     and TestFlight.
4. Alternatively, rent a cloud Mac (MacinCloud / MacStadium) and build/run
   through Xcode directly.

The `ios/` folder already exists (generated by `flutter create`), so a Mac/CI
can build it without extra setup.

## 5. Google Sign-In setup

"Continue with Google" (see `docs/20-social-login-plan.md`) uses the
`google_sign_in` package (v7+) with direct Google Cloud Console credentials —
no Firebase. Three OAuth client IDs already exist for this project (Google
Cloud Console → APIs & Services → Credentials) and are wired in already:

- **Web client** — used as the `serverClientId` everywhere (Android and iOS).
  This is what the ID token's `aud` claim ends up as, which is what the
  backend (`lifey.oauth.google.client-ids`) verifies.
- **Android client** — registered against `com.khunor.lifey` + the debug
  keystore's SHA-1 (`cd android && ./gradlew signingReport`). Not referenced
  directly in Dart code — Android's Credential Manager matches it by
  package name + SHA-1 automatically.
- **iOS client** — registered against bundle id `com.khunor.lifey`, passed as
  `clientId` in `lib/features/auth/data/google_auth_config.dart`, and its
  *reversed* form is registered as a URL scheme in
  `ios/Runner/Info.plist` (`CFBundleURLTypes`) — required for the native
  sign-in flow to redirect back into the app.

If you ever need to point at a **different** Google Cloud project (e.g. your
own sandbox) without editing the checked-in values, override at run time:

```bash
flutter run \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=<ios-client-id>.apps.googleusercontent.com
```

Note this only overrides the Dart-side values — the iOS `CFBundleURLTypes`
scheme in `Info.plist` is compiled in, so a different iOS client also needs
its reversed form swapped in there manually before it will complete sign-in
on a device/simulator.

Registering a new Android debug keystore (e.g. a fresh machine) means its
SHA-1 must be added to the Android OAuth client in the Console, or sign-in
will fail with a `clientConfigurationError`.
