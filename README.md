# PuantajX 🏗️🏗️

**PuantajX** is a modern and efficient personnel tracking and daily reporting application designed to digitize construction and site management. It works seamlessly across mobile (Android/iOS) and web platforms with real-time synchronization.

## ✨ Features

- **📍 Project Management:** Manage multiple construction sites and projects from a single dashboard.
- **👥 Team Management:** Personnel lists, role definitions (Owner, Admin, Viewer), and team-based authorization.
- **📝 Daily Reports:** A professional reporting wizard supported by weather data, shifts, work logs, and visual evidence (photos).
- **⏰ Attendance Tracking:** Personnel attendance control and automated payment/progress tracking foundations.
- **🔄 Real-time Sync:** Powered by Supabase Realtime, data is updated instantly across all devices.
- **📶 Offline Mode:** Enter data even without an internet connection; it automatically syncs once you're back online (Mobile).

## 🚀 Tech Stack

- **Framework:** [Flutter](https://flutter.dev/) (3.x+)
- **State Management:** [Riverpod](https://riverpod.dev/) (Generator-based)
- **Backend:** [Supabase](https://supabase.com/) (Auth, Database, Storage, Realtime, Functions)
- **Local DB:** [Isar](https://isar.dev/) (High-performance NoSQL)
- **Navigation:** [GoRouter](https://pub.dev/packages/go_router)

## 🛠️ Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/KFSoftwareApps/PuantajX.git
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run code generation:**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Launch the app:**
   ```bash
   flutter run
   ```

## 📂 Project Structure

```text
lib/
├── core/           # Common services, themes, widgets, and platform adapters
├── features/       # Feature-based folder structure (Domain-Driven Design approach)
│   ├── auth/       # Login, Registration, Organization & Team Management
│   ├── project/    # Project listing, details, and editing
│   ├── report/     # Daily report wizard and history
│   └── workers/    # Personnel registration and tracking
└── main.dart       # Application entry point
```

## 📄 License

Developed by **KF Software**. All rights reserved.

---
Developed with ❤️ by [KF Software](mailto:kfsoftwareapp@gmail.com)
