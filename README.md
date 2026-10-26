# EmLoadStore

A SwiftUI alternative app manager for iOS, paired with an Intel Mac command-line host.

## Current features

- iOS app with Home, Apps, Devices, and Settings tabs, using Liquid Glass on iOS 26 and material styling on earlier supported releases.
- macOS SwiftUI app with a local IPA library.
- `EmLoadServer`, a Swift command-line host that uses `idevicepair` to pair and validate a connected device, then securely exports its pairing record.
- iOS Devices tab can import a pairing plist into app-private storage protected with complete file protection.
- Apple ID sign-in runs on the Mac host through `EmLoadServer`; the iOS app does not collect or store Apple ID credentials.

Host authentication uses [SideSign](https://github.com/SideStore/SideSign), pinned to a specific revision. The password is entered through a no-echo terminal prompt and is sent to Apple's authentication service; it is not stored. The resulting session and the Mac-ADI identity are stored in the macOS Keychain. The selected Anisette server supplies device-attestation data and does not receive the Apple ID password. Anisette servers are third-party services, so use only an operator you trust.

The host uses one selected HTTPS server at a time and does not automatically rotate endpoints. Only SideStore registry entries marked as Mac-ADI (`kind: 2`) can be selected. The default is **SideStore (New)** (`https://new.ani.sidestore.io`).

```sh
.build/release/emloadserver anisette-servers
.build/release/emloadserver login --apple-id your-apple-id@example.com
# Or select a supported server from the list:
.build/release/emloadserver login --apple-id your-apple-id@example.com --server "SideStore (New)"

.build/release/emloadserver account
.build/release/emloadserver logout
.build/release/emloadserver reset-anisette
```

`login` prompts for the password without echoing it and interactively handles trusted-device, SMS, or phone-call two-factor codes. Never pass the password as a command-line argument. The last selected endpoint is remembered in the Mac Keychain; use `--server` to explicitly change it. If that saved endpoint is removed from SideStore's registry, login stops instead of silently switching servers. `logout` removes the saved authentication session. `reset-anisette` removes the saved Anisette identity and can cause Apple to request two-factor verification again, but preserves the selected endpoint.

### Sign-in error `-80045`

This response is issued by Apple's private authentication service and can have multiple causes; no client-side fix is guaranteed. Keep the selected endpoint fixed. If you choose to retry, reset the saved Anisette identity at most once with `emloadserver reset-anisette`, then wait before trying again. Resetting may require fresh two-factor verification. Avoid repeated attempts, which can trigger Apple's temporary security limits. The CLI does not automatically retry credentials against alternate servers.

## Build

Open `EmLoadStore.xcodeproj` in Xcode and select either the **EmLoadStore** macOS target or the **EmLoadStoreCompanion** iOS target.

For command-line builds:

```sh
xcodebuild -project EmLoadStore.xcodeproj -scheme EmLoadStore -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project EmLoadStore.xcodeproj -target EmLoadStoreCompanion -configuration Debug -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
```

The iOS build command targets iPhone/iPad devices; it does not launch or build for Simulator.

## EmLoadServer pairing

On an Intel Mac, build [libimobiledevice](https://libimobiledevice.org/) and `ideviceinstaller` from source. The script needs the Xcode command line tools and Python 3 (used for a local CMake install); it does not use Homebrew or sudo, and it can be re-run safely:

```sh
scripts/install-libimobiledevice.sh
export PATH="$HOME/.local/bin:$PATH"
cd EmLoadServer
swift build -c release
```

The script installs everything into `~/.local/opt/libimobiledevice` and links `idevicepair`, `idevice_id`, `ideviceinfo`, and `ideviceinstaller` into `~/.local/bin`. Add the `export PATH` line to `~/.zprofile` so future shells find them. Build on the Intel Mac itself to produce an Intel-compatible executable.

With the iPhone connected by USB and unlocked, approve its Trust prompt.

Sign in to Apple from this host (never from the iPhone app) with the commands above. The host's Keychain is the only place the account session and Anisette identity are persisted; no local Anisette HTTP service is exposed.

Pair and validate the device, then export a new pairing record:

```sh
.build/release/emloadserver pair --udid <DEVICE_UDID> --output <PAIRING_FILE.plist>
```

Find the device UDID with `idevice_id -l`. If libimobiledevice stores its record outside the standard macOS locations, specify its lockdown directory:

```sh
.build/release/emloadserver pair --udid <DEVICE_UDID> --output <PAIRING_FILE.plist> --record-dir <LOCKDOWN_DIRECTORY>
```

The output file is created with owner-only permissions, and existing files are never overwritten. Treat it like a credential: it contains sensitive pairing material, so transfer it only to your own device and do not commit or share it. The iOS app can import the plist into protected app storage. It does not yet connect to the host, sign apps, or install/refresh them.

## Build targets

Open `EmLoadStore.xcodeproj` in Xcode and select **EmLoadStore** for macOS or **EmLoadStoreCompanion** for iOS. The SwiftUI app supports macOS 14 and iOS 17 or later.
