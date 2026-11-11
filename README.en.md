# firetv-button-remap

[Português](README.md)

**Make the app buttons on your Fire TV remote open the app you choose.**

Fire TV remotes come with fixed app buttons (Prime Video, Netflix, Disney+, Peacock...). If you
don't use one of those services, the button is wasted, or worse: it opens the store saying the app
is "unavailable in your country". This project changes where those buttons go. No root, no PC
needed after setup, and nothing from Amazon gets uninstalled.

What runs on the stick it was built on: **Prime Video → Max** and **Peacock → SmartTube**.

## Tested on

| | |
|---|---|
| Device | **Fire TV Stick 4K (2nd gen)**, model `AFTKRT` (codename `karat`) |
| System | **Fire OS 8.1.8.5** (`RS8185/3898`), Android 11, API 30 |
| Remote | Alexa Voice Remote with Netflix, Prime Video, Disney+ and Peacock buttons |
| Alongside | The [FireFrame](https://github.com/dyascj/FireFrame) launcher, which also uses an accessibility service |
| PC | Windows 11, PowerShell 7, JDK 17 |

Other **Fire OS 8** devices (Fire TV Stick 4K Max 2nd gen, Fire TV Cube 3rd gen) should work but
**are untested**. On **Fire OS 7** there are reports that the system won't start third-party
accessibility services, so it probably doesn't work. **Vega OS** devices (Fire TV Stick 4K Select)
can't run Android apps and **are not supported**.

If you try another device, please open an issue with the model, Fire OS version and result.

## How it works

When you press an app button, Fire OS writes a line to the system log that identifies the button.
The Prime Video button produces `deeplink_prime_video`, the Peacock button `asin=B08BG9MPT9`. The
`tv.redirect` app reads those lines and, when it recognises a button, opens your chosen app on top.
For the next 5 seconds it also covers whatever Amazon opens right after (Prime Video or the store
page), so your app stays in front.

It runs as an **accessibility service**, the same feature alternative launchers use to catch the
Home button. That keeps it running and lets it open other apps. Permission to read the log
(`READ_LOGS`) is granted once over ADB.

The app has **no internet permission**, only reads `ActivityTaskManager` log lines and stores
nothing. All of it is [one Java file](src/tv/redirect/ButtonService.java).

> Why not a "fake" app with Peacock's package name? That was tried and it doesn't work: the button
> asks Amazon's store for the app by its product code (ASIN), and the store ignores sideloaded apps.

## What you need

- A **Windows 10 or 11** PC with **PowerShell**.
- **JDK 17 or newer** with `javac` on the PATH. Check with `javac -version`. If missing, install
  [Temurin 17](https://adoptium.net/temurin/releases/?version=17).
- The PC and the Fire TV **on the same network and able to reach each other** (see
  [Troubleshooting](#the-pc-cant-find-the-fire-tv)).
- The target apps already installed on the Fire TV.

## Step-by-step setup

### 1. Turn on ADB debugging on the Fire TV

1. **Settings → My Fire TV → About**. Highlight the device name and press OK **7 times** until it
   says you are now a developer.
2. Go back to **Settings → My Fire TV → Developer options**.
3. Turn on **ADB debugging**.

### 2. Note the Fire TV's IP address

**Settings → My Fire TV → About → Network.** Something like `192.168.1.24`.

### 3. Get this project and the Android SDK

Download the repository ZIP (**Code → Download ZIP**) and extract it, or `git clone` it. Open
PowerShell in the folder and run:

```powershell
.\get-sdk.ps1
```

It downloads adb, the build tools and the Android 15 platform from Google (about 125 MB), checks
each file's checksum and keeps everything in `sdk\`. **Running it means accepting the
[Android SDK license](https://developer.android.com/studio/terms).**

If PowerShell refuses to run scripts, allow them for this window only:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

### 4. Connect to the Fire TV

```powershell
.\sdk\platform-tools\adb.exe connect 192.168.1.24
```

The TV shows **"Allow USB debugging?"**. Tick **"Always allow from this computer"** and confirm.
Run the command again: it should say `connected` (or `already connected`).

### 5. Find each button's text

Known so far:

| Button | Log text | Tested |
|---|---|---|
| Prime Video | `deeplink_prime_video` | Yes |
| Peacock | `asin=B08BG9MPT9` | Yes |
| Disney+ | `asin=B07Y8SJGCV` | Seen in the log; remap not tested |
| Netflix | no text of its own (see [Limitations](#limitations)) | No |

For another button or remote, leave this running and press the button:

```powershell
.\sdk\platform-tools\adb.exe -s 192.168.1.24:5555 logcat -v brief -s ActivityTaskManager:I
```

Look for the `START u0` line with `amzns://apps/android?...` at the moment you pressed it. Copy a
piece only that button has, such as `asin=XXXXXXXXXX` or `libraryItemId=...`. Press `Ctrl+C` to stop.

### 6. Find the target apps' package names

```powershell
.\sdk\platform-tools\adb.exe -s 192.168.1.24:5555 shell pm list packages -3
```

Some common ones:

| App | Package |
|---|---|
| Max | `com.hbo.hbonow` |
| SmartTube | `org.smarttube.stable` |
| Globoplay | `com.globo.globotv` |
| Netflix | `com.netflix.ninja` |
| Disney+ | `com.disney.disneyplus` |
| Paramount+ | `com.cbs.ca` |

### 7. Install

Rules are `button text>app package`, separated by `;`:

```powershell
.\install.ps1 -Ip 192.168.1.24 -Rules "deeplink_prime_video>com.hbo.hbonow;asin=B08BG9MPT9>org.smarttube.stable"
```

The script:

1. builds the app with your rules and signs it with a key it creates (`redirect.keystore`);
2. installs it on the Fire TV;
3. grants the log permission;
4. turns the accessibility service on **without turning off** any you already have (like a launcher's);
5. checks the service started with the right rules.

It ends with `Pronto. ativo com regras {...}` ("Done. active with rules").

### 8. Test

Press each button you changed. The new app should open in under half a second. Amazon's screen may
flash for a moment first.

After setup the PC is no longer needed. You can even turn ADB debugging off.

## Changing the rules

Run `install.ps1` again with the new rules from the same folder: it reuses the same key
(`redirect.keystore`) and installs over the old app. **Keep that file.** Without it you have to
uninstall before installing again.

## Uninstall

```powershell
.\sdk\platform-tools\adb.exe -s 192.168.1.24:5555 uninstall tv.redirect
```

The buttons go back to normal right away.

## Troubleshooting

### The PC can't find the Fire TV

If `adb connect` times out with the right IP and debugging on, the router is probably isolating
devices. On the stick this was built on, the ISP router's `_5G` Wi-Fi couldn't talk to the PC on
cable. **Connecting the Fire TV to the 2.4 GHz network** (same name without `_5G`) fixed it. After
setup it can go back to 5 GHz. The other fix is turning off "AP Isolation" in the router.

### `unauthorized` or `Fire TV nao conectado`

Accept "Allow USB debugging?" on the TV and run again. If the prompt doesn't show, turn ADB
debugging off and on.

### The buttons open the original app again

Fire OS turns the service off after some updates, or if someone uses **Force stop** on the app in
Settings → Applications. Run `install.ps1` again.

### `O servico nao iniciou` (the service didn't start)

Check that the service is on the list:

```powershell
.\sdk\platform-tools\adb.exe -s 192.168.1.24:5555 shell settings get secure enabled_accessibility_services
```

It must include `tv.redirect/tv.redirect.ButtonService`. Also look at the app's log:

```powershell
.\sdk\platform-tools\adb.exe -s 192.168.1.24:5555 logcat -d -s tv-redirect
```

### The right app opens, but the original comes back on top

The app covers Amazon's screen for 5 seconds. If an original app takes longer to show up, open an
issue with the log from when you pressed the button.

## Limitations

- **Netflix:** the button opens Netflix directly, with no text that tells it apart from opening
  Netflix from the home screen. Remapping it would also catch those, so it isn't recommended.
- **Buttons for apps you have installed**, like Disney+: the original app still opens behind, which
  uses a bit of memory. Not tested.
- It depends on how Fire OS writes its log. An update may change a button's text; if so, redo step 5.
- Made for Windows. The Android SDK tools exist for Linux and macOS, but the scripts are PowerShell
  and haven't been tested outside Windows.

## License

[MIT](LICENSE). Not affiliated with Amazon. Fire TV, Prime Video and other names belong to their owners.
