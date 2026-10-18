# Penny 2 — native iPhone expense tracker

A brand-new Swift/SwiftUI version of Penny. Same idea and features as the Flutter app, rebuilt natively, plus Face ID lock, recurring transactions and richer charts. No Flutter, no CocoaPods, no extra installs — just Xcode.

## Run it

1. Unzip into a folder **outside** iCloud Drive, Desktop or Documents (for example `~/Developer/PennyNative`). iCloud adds hidden file attributes that make Xcode's code signing fail.
2. Double-click **Penny.xcodeproj**.
3. At the top of Xcode, pick an iPhone simulator (e.g. *iPhone 17*) and press **⌘R**.

**Requirements:** Xcode 16 or newer (the project uses Xcode 16's folder-synced format). The app runs on iOS 17 and later, iPhone and iPad.

### On your own iPhone

1. In Xcode: select the **Penny** project → **Penny** target → **Signing & Capabilities** → choose your **Team** (add your Apple ID under Xcode → Settings → Accounts if needed). A free Apple ID works for your own device.
2. If Xcode says the bundle ID is taken, change `com.reshardporter.penny` to something unique.
3. Connect the iPhone, turn on **Settings → Privacy & Security → Developer Mode**, select it at the top of Xcode and press **⌘R**.
4. Free Apple ID only: on the phone open **Settings → General → VPN & Device Management** and trust your developer certificate. Free installs expire after 7 days; press ⌘R again to refresh.

### Run the tests

Press **⌘U**. Tests cover exact-cents parsing and formatting, recurring schedules (no month-end drift), budget carry-forward and CSV formula neutralization.

## Features

- **Overview** — monthly plan hero (left to spend / over budget), money in, money out, net flow, last-7-days chart (touch and hold a bar), top categories and recent activity.
- **Activity** — search descriptions, categories and notes; filter by type and category; swipe to delete with **Undo**; tap to edit; export the filtered list as CSV.
- **Budgets** — a limit per expense category; a new limit applies from that month onward; zero-spend goals allowed; over-budget status shown with icon and text.
- **Insights** — month-over-month comparison, daily average, spending-mix donut, six-month income vs expenses trend, and a budget-pace line.
- **Recurring transactions** — choose *Repeat* when adding, or manage them in Settings › Recurring. Penny records due entries at launch and when you return to the app; pause, resume, edit or delete any series.
- **Face ID / Touch ID / passcode lock** — Settings › Privacy. Locks when you leave the app and hides balances in the app switcher. In the Simulator, enable it via *Features → Face ID → Enrolled*.
- **Settings** — USD, JMD, EUR or GBP labels (no conversion), export everything as CSV, remove sample data, clear transactions.
- Light and dark mode; Dynamic Type; VoiceOver labels on rows, charts and progress.

Data is stored on the device with SwiftData. Amounts are whole cents, so totals never drift. First launch shows labeled sample data; tap **Remove** on the banner to start fresh.

## Project layout

```text
Penny.xcodeproj               Xcode project (folder-synced: new files are picked up automatically)
Penny/PennyApp.swift          App entry, tabs, lock overlay, undo toast, launch tasks
Penny/Models/                 Ledger types, SwiftData models, money, summaries, budgets, CSV
Penny/Support/                Theme, shared state, Face ID lock, recurring engine, sample data
Penny/Views/                  Overview, Activity, Budgets, Insights, Settings, Recurring, forms
Penny/Assets.xcassets         App icon and accent color
PennyTests/                   Unit tests (Swift Testing)
```

## Troubleshooting

- **"Command CodeSign failed"** — run `xattr -cr .` inside the project folder, then *Product → Clean Build Folder* (⇧⌘K) and run again. Make sure the folder isn't in iCloud Drive.
- **"Signing requires a development team"** — only for real devices; see *On your own iPhone* above. The simulator needs no team.
- **Project won't open / shows as unsupported** — update Xcode to version 16 or newer.
