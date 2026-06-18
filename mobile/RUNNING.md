# Running the Lifey mobile app

The app talks to the Spring Boot backend, so **start the backend first** in every case.

## 0. Start the backend

```bash
# from the repo root
docker compose up -d postgres
cd backend && ./mvnw spring-boot:run     # serves http://localhost:8080
```

The base URL is resolved automatically (`lib/core/network/api_config.dart`):

| Target                | Base URL used                       |
|-----------------------|-------------------------------------|
| Android emulator      | `http://10.0.2.2:8080/api/v1`       |
| Web / iOS simulator   | `http://localhost:8080/api/v1`      |
| Physical device       | pass `--dart-define=API_BASE_URL=…` |

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
> (`NSAllowsArbitraryLoads`), so the app can call the `http://` backend.

### iOS Simulator
```bash
open -a Simulator
cd mobile
flutter devices        # confirm the simulator shows up
flutter run            # pick the simulator
```
The simulator shares the Mac's network, so `http://localhost:8080` works with
no extra config.

### Physical iPhone (USB)
1. Plug in the iPhone and tap **Trust** on the phone.
2. Set up signing once in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
   - Select the **Runner** target → **Signing & Capabilities**.
   - Tick **Automatically manage signing** and choose your **Team**
     (a free personal Apple ID works for on-device development).
   - If the bundle id is rejected, change it to something unique, e.g.
     `com.lifey.lifey.<yourname>`.
3. The phone reaches the Mac's backend over the LAN, so pass the Mac's IP:
   ```bash
   ipconfig getifaddr en0     # Mac's LAN IP, e.g. 192.168.0.42
   cd mobile
   flutter run --dart-define=API_BASE_URL=http://192.168.0.42:8080/api/v1
   ```
   Keep the iPhone and Mac on the same Wi-Fi. With a free Apple ID the signing
   certificate expires after 7 days (just re-run to re-sign); a paid Apple
   Developer account removes that limit and enables TestFlight.

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
