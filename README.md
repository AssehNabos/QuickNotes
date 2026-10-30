# QuickNotes

A fast, private, offline-first note-taking app for Android, iOS and web.
Notes stay on the device, in SQLite (browser IndexedDB on web).

## Features

- Create, view, edit and delete notes with a title, content, category and colour
- Live search across title, content and category
- Categories with counts, plus a filtered view
- Pin notes to the top and mark favourites
- Reminders for any note, delivered as local notifications
- Light, dark and system themes, remembered between launches
- Database migrations, so upgrades keep your notes

## Requirements

- Flutter 3.27 or newer (stable channel)
- Dart 3.3 or newer (included with Flutter)
- Android Studio with the Android SDK, and JDK 17
- A physical Android device or emulator (Android 6.0 / API 23 or newer)
- Microsoft Edge or Google Chrome to run the web app

Check your setup with `flutter doctor`.

## 1. Set up the project

The source folders (`lib/`, `test/`, `web/`, `pubspec.yaml`) are complete.
Flutter also needs its platform folders (`android/` and `ios/`), which the
Flutter tool generates. From the repository root, back up the project first,
then run:

```bash
flutter create --project-name quicknotes --org com.example --platforms=android,ios .
```

`flutter create` only adds missing files. It keeps your existing `lib/` and
`pubspec.yaml`. If it asks to overwrite anything, answer no.

Then fetch the packages:

```bash
flutter pub get
```

## 2. Android configuration for reminders

Reminders use `flutter_local_notifications`, which needs a few Android
settings.

### AndroidManifest.xml

Edit `android/app/src/main/AndroidManifest.xml`. Add these permissions
directly inside `<manifest>`, above `<application>`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

Add these receivers inside `<application>`, so reminders survive a reboot:

```xml
<receiver
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
    android:exported="false" />
<receiver
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
    android:exported="false">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
    </intent-filter>
</receiver>
```

### Core library desugaring

Edit `android/app/build.gradle` (or `build.gradle.kts`). Inside `android { }`:

```gradle
compileOptions {
    coreLibraryDesugaringEnabled true
    sourceCompatibility JavaVersion.VERSION_17
    targetCompatibility JavaVersion.VERSION_17
}
```

Inside `dependencies { }`:

```gradle
coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
```

If Gradle asks for a newer `desugar_jdk_libs` version, use the one it suggests.

## 3. Run the app

```bash
flutter run -d edge
```

Use `flutter devices` to see available targets, or replace `edge` with
`chrome` or a connected Android device. Web notes are stored in that browser's
IndexedDB and are tied to the app's origin and port.

On first launch, Android 13 and newer asks for notification permission the
first time you set a reminder.

## 4. Run the tests

```bash
flutter analyze
flutter test
```

The tests cover:

| Area | File | What it checks |
|---|---|---|
| Model | `test/models/note_test.dart` | Validation, SQLite mapping, reminder clearing |
| Repository | `test/data/note_repository_test.dart` | CRUD, search (including `%` and `_`), persistence after reopening, reminder validation |
| Migration | `test/data/database_migration_test.dart` | A version 1 database upgrades to version 2 with notes intact |
| State | `test/providers/notes_provider_test.dart` | State updates, reminder scheduling and cancelling, filters, category counts |
| Dashboard | `test/ui/home_screen_test.dart` | Empty state, results, no-match message, tab navigation |

### Manual checks on a device

These cannot be automated, so run them by hand:

1. Create several notes, edit one, and delete one. Confirm the deleted note is gone.
2. Search by a word in the title, in the content, and in the category. Search for a word that does not exist.
3. Pin and favourite notes. Close the app fully, reopen it, and confirm both states are kept.
4. Switch between Light, Dark and System in Settings. Close and reopen the app, and confirm the choice is kept.
5. Set a reminder about two minutes ahead. Lock the phone and confirm the notification arrives.
6. Turn the phone off and on, then confirm a reminder set before the restart still fires.
7. Test on a small phone and a tablet or large emulator for layout.

## 5. Build a release APK

### Create a signing key (once)

```bash
keytool -genkey -v -keystore ~/quicknotes-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias quicknotes
```

Keep this file and its passwords safe. You need the same key for every
future update, or Android will refuse to install the update over the
existing app.

### Configure signing

Create `android/key.properties` (do not commit it to version control):

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=quicknotes
storeFile=/absolute/path/to/quicknotes-release.jks
```

In `android/app/build.gradle`, add above `android { }`:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

Inside `android { }`, add a signing config and use it for release builds:

```gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile file(keystoreProperties['storeFile'])
        storePassword keystoreProperties['storePassword']
    }
}
buildTypes {
    release {
        signingConfig signingConfigs.release
        minifyEnabled true
        shrinkResources true
    }
}
```

### Build

```bash
flutter clean
flutter pub get
flutter build apk --release --split-per-abi
```

The APKs are written to `build/app/outputs/flutter-apk/`:

- `app-arm64-v8a-release.apk` for most modern phones
- `app-armeabi-v7a-release.apk` for older 32-bit phones
- `app-x86_64-release.apk` for emulators and some tablets

If you are not sure which to use, build without `--split-per-abi` to get one
universal `app-release.apk`.

### Install

With a device connected over USB and USB debugging on:

```bash
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Or copy the APK to the phone, open it in the file manager, and allow
installs from that source.

## Known limitations

- Reminders are scheduled inexactly to save battery, so they can arrive a
  few minutes late.
- Tapping a reminder opens the app but not the specific note yet.
- Note content is plain text. Rich text formatting (Flutter Quill) and the
  reference design's Alignment, Style and Size tools are not included.
- Notes are not backed up or synced. Uninstalling the app deletes them.
- iOS builds need a Mac with Xcode and notification permissions set up in the
  iOS project.

## Project structure

```
lib/
  main.dart                 Entry point, loads preferences and notifications
  app.dart                  Root MaterialApp and theme wiring
  core/
    constants/              App constants, schema names, colour palette
    errors/                 Typed app exceptions
    services/               Preferences and notification services
    theme/                  Material 3 light and dark themes
  data/
    database/               SQLite connection, schema and migrations
    models/                 Immutable Note model
    repositories/           All SQL, parameterised
  providers/                Riverpod state (notes, theme, core services)
  ui/
    screens/                Home shell and all screens
    widgets/                Note card, grid, empty state, logo
    utils/                  Formatters, feedback, shared note actions
test/
  helpers/                  Fakes and test setup
  models/ data/ providers/ ui/
```
