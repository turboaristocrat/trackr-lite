# ⚡ TRACKR Lite

**TRACKR Lite** is an ultra-fast, zero-clutter, installable Progressive Web App (PWA) designed for **Indian Railways Track Machine Operators & Field Engineers** (Southern Railway / TVC Division).

Built specifically for high-speed logging during late-night track blocks with instant 1-tap WhatsApp report generation.

---

## 📱 Features

- **Installable PWA**: Works on any Android phone (Chrome) or iPhone (Safari) with a real app icon on the home screen.
- **100% Offline**: Once loaded, all caching and shift logs are saved locally on the device with zero internet required.
- **Auto-Remember Machine**: Remembers machine type, number, division, and section across sessions.
- **Instant Block & Transit Logging**: Log track blocks and movement runs in under 30 seconds.
- **1-Tap WhatsApp Shift Report**: Automatically formats official Southern Railway division shift reports and launches WhatsApp directly.
- **Local History & Backup**: Review past shifts, re-share reports, or export/import full JSON backups without needing any cloud accounts.

---

## 🚀 How to Install on Mobile

1. Open the live URL on your phone's browser (e.g. Chrome on Android or Safari on iPhone).
2. Tap the browser menu or the install banner:
   - **Android**: Tap **"Install app"** or **"Add to Home screen"**.
   - **iPhone**: Tap **Share (square with arrow)** ➔ **"Add to Home Screen"**.
3. **TRACKR Lite** will now appear as a native app on your phone's home screen!

---

## 🌐 Deploying to GitHub Pages

This repository includes an automated GitHub Action (`.github/workflows/deploy.yml`) that builds and publishes the PWA automatically whenever code is pushed to `main`.

### To Enable GitHub Pages:
1. Go to your repository on GitHub: `https://github.com/turboaristocrat/<repo-name>`.
2. Click **Settings** ➔ **Pages** (in the left sidebar).
3. Under **Build and deployment** ➔ **Source**, select:
   👉 **GitHub Actions**
4. Push a commit to `main` (or run the workflow manually under the **Actions** tab).
5. Your live app will be published at:
   `https://turboaristocrat.github.io/<repo-name>/`

---

## 🛠️ Local Development

```bash
# Get dependencies
flutter pub get

# Run locally on Web
flutter run -d chrome

# Build production web PWA
flutter build web --release
```
