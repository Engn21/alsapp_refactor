# ALSApp - Agriculture and Livestock Support Application

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue?logo=flutter)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-16+-success?logo=node.js)](https://nodejs.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-13+-blue?logo=postgresql)](https://www.postgresql.org)
[![Prisma](https://img.shields.io/badge/Prisma-ORM-2D3748?logo=prisma)](https://www.prisma.io)
[![License](https://img.shields.io/badge/License-Academic-orange)]()

> **For detailed information about the application, visit our website: [tarimhayvancilikdestek.com.tr](https://tarimhayvancilikdestek.com.tr)**

---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Supported Crop and Livestock Types](#supported-crop-and-livestock-types)
- [Technology Stack](#technology-stack)
- [System Architecture](#system-architecture)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [API Endpoints](#api-endpoints)
- [Configuration](#configuration)
- [Localization](#localization)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

ALSApp (Agriculture and Livestock Support Application) is a comprehensive digital platform designed to help Turkish farmers and livestock breeders manage their agricultural operations efficiently. The application provides:

- **Real-time tracking** of crops and livestock with type-specific metrics
- **Weather alerts** with agricultural recommendations
- **Government support program discovery** from the Ministry of Agriculture and Forestry
- **Multi-language support** (Turkish, English, French)
- **Cross-platform mobile app** built with Flutter

The system bridges the gap between traditional farming practices and modern digital technologies, making agricultural management accessible to farmers of all technical skill levels.

---

## Key Features

### 🌾 Crop Management
- Track 10 different crop types with type-specific fields
- Record planting dates, harvest dates, and yield data
- Log spray applications and pesticide usage
- Monitor quality metrics (protein %, moisture %, sugar %, oil %)
- Automated scheduling for irrigation and fertilization

### 🐄 Livestock Management
- Track 10 different livestock types with specialized metrics
- Record milk production logs with fat percentage
- Track egg production for poultry
- Monitor weight changes over time
- Health status and vaccination tracking
- Automated reminders for veterinary visits and care schedules

### 🌤️ Weather Integration
- Real-time weather data via OpenWeatherMap API
- Location-based forecasts using device GPS
- Intelligent alerts for:
  - Rain risk
  - High humidity (fungal disease warning)
  - Cold weather (frost protection)
  - High wind conditions

### 📋 Government Support Programs
- Automated discovery of agricultural support programs
- Categorized by crop type (bitkisel) and livestock (hayvansal)
- Direct links to Ministry of Agriculture and Official Gazette
- Application deadline tracking

### 🔔 Smart Notifications
- Threshold-based alerts for production metrics
- Scheduled reminders for farm activities
- Weather-based agricultural recommendations

---

## Supported Crop and Livestock Types

### 10 Crop Types

| Type | Turkish | Key Metrics |
|------|---------|-------------|
| Wheat | Buğday | Protein 11-15%, Moisture 12-14%, Min Yield 3.0 t/ha |
| Sugar Beet | Pancar | Sugar 16-20%, Moisture 70-80%, Min Yield 50.0 t/ha |
| Corn | Mısır | Protein 8-11%, Moisture 13-15%, Min Yield 7.5 t/ha |
| Cotton | Pamuk | Moisture 7-9%, Min Yield 3.0 t/ha |
| Sunflower | Ayçiçeği | Oil 40-50%, Moisture 8-10%, Min Yield 2.2 t/ha |
| Tomato | Domates | Moisture 93-95%, Min Yield 60.0 t/ha |
| Grape | Üzüm | Sugar 17-25%, Moisture 75-85%, Min Yield 9.0 t/ha |
| Olive | Zeytin | Oil 15-25%, Moisture 45-55%, Min Yield 4.0 t/ha |
| Rice | Pirinç | Protein 6-8%, Moisture 12-14%, Min Yield 5.5 t/ha |
| Soybean | Soya | Protein 38-42%, Moisture 12-14%, Min Yield 2.5 t/ha |

### 10 Livestock Types

| Type | Turkish | Key Metrics |
|------|---------|-------------|
| Cow | İnek | Min Milk 15 L/day, Fat 3.2%, Ideal Weight 550 kg |
| Sheep | Koyun | Ideal Weight 70 kg, Wool quality tracking |
| Goat | Keçi | Min Milk 2.5 L/day, Fat 3.4%, Ideal Weight 55 kg |
| Chicken | Tavuk | Min Eggs 0.7/day (70% rate), Ideal Weight 2 kg |
| Duck | Ördek | Min Eggs 0.8/day, Ideal Weight 3 kg |
| Turkey | Hindi | Ideal Weight 12 kg, Feed conversion tracking |
| Bee | Arı | Hive health, Queen status, Honey production logs |
| Fish | Balık | Water temperature, pH levels, Avg weight tracking |
| Buffalo | Manda | Min Milk 10 L/day, Fat 6.5%, Ideal Weight 600 kg |
| Camel | Deve | Min Milk 6 L/day, Fat 3.5%, Ideal Weight 500 kg |

---

## Technology Stack

### Frontend (Mobile Application)
- **Framework:** Flutter 3.0+
- **Language:** Dart
- **State Management:** Provider pattern
- **Local Storage:** Flutter Secure Storage
- **HTTP Client:** Dio
- **Charts:** fl_chart
- **Maps:** flutter_map with OpenStreetMap
- **Localization:** flutter_localizations with intl

### Backend (API Server)
- **Runtime:** Node.js 16+
- **Framework:** Express.js
- **Language:** TypeScript
- **ORM:** Prisma
- **Database:** PostgreSQL
- **Authentication:** JWT (jsonwebtoken)
- **Validation:** Zod
- **Security:** Helmet, bcryptjs

### External Services
- **Weather:** OpenWeatherMap API
- **Government Data:** Ministry of Agriculture RSS feeds

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Mobile Application                        │
│                      (Flutter/Dart)                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Screens    │  │   Services   │  │   Widgets    │      │
│  │  - Dashboard │  │  - API       │  │  - Navigation│      │
│  │  - Products  │  │  - Weather   │  │  - Map       │      │
│  │  - Weather   │  │  - Location  │  │  - Language  │      │
│  │  - Supports  │  │  - Support   │  │  - Charts    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTPS/REST API
                         │ (JWT Authentication)
┌────────────────────────▼────────────────────────────────────┐
│                    Backend Server                            │
│                  (Node.js + Express)                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │   Auth   │ │  Crops   │ │Livestock │ │ Weather  │       │
│  │Controller│ │Controller│ │Controller│ │Controller│       │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                    │
│  │ Supports │ │  Notif   │ │   Dash   │                    │
│  │Controller│ │Controller│ │Controller│                    │
│  └──────────┘ └──────────┘ └──────────┘                    │
└────────────────────────┬────────────────────────────────────┘
                         │ Prisma ORM
┌────────────────────────▼────────────────────────────────────┐
│                      PostgreSQL                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │    Users     │  │    Crops     │  │  Livestock   │      │
│  │  Crop Logs   │  │ Milk/Egg Logs│  │   Supports   │      │
│  │Notifications │  │   Metrics    │  │   Alerts     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘

External APIs:
┌──────────────┐  ┌──────────────┐
│ OpenWeather  │  │  Ministry    │
│   Map API    │  │  RSS Feeds   │
└──────────────┘  └──────────────┘
```

---

## Quick Start

### Prerequisites

- **Node.js** 16.x or higher
- **PostgreSQL** 13.x or higher (or Docker)
- **Flutter** 3.0 or higher
- **Git**

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/alsapp.git
cd alsapp
```

### 2. Start PostgreSQL (Docker)

```bash
docker compose up -d
```

### 3. Backend Setup

```bash
cd backend

# Copy environment file
cp .env.example .env

# Edit .env with your configuration
# DATABASE_URL, JWT_SECRET, OPENWEATHER_API_KEY

# Install dependencies
npm install

# Generate Prisma client
npx prisma generate

# Run database migrations
npx prisma migrate dev --name init

# (Optional) Seed sample data
npm run prisma:seed

# Start development server
npm run dev
```

The backend will be available at `http://localhost:8080`

### 4. Frontend Setup

```bash
cd ../frontend

# Install Flutter dependencies
flutter pub get

# Run the app
flutter run
```

**API Base URL Configuration:**
- Android Emulator: `http://10.0.2.2:8080/api`
- iOS Simulator: `http://localhost:8080/api`
- Physical Device: Use your computer's local IP address

---

## Project Structure

```
alsapp_refactor/
├── backend/
│   ├── src/
│   │   ├── config/
│   │   │   ├── type-fields.ts       # Type-specific field definitions
│   │   │   └── type-thresholds.ts   # Alert thresholds
│   │   ├── controllers/
│   │   │   ├── auth.controller.ts   # Authentication
│   │   │   ├── crops.controller.ts  # Crop management
│   │   │   ├── livestock.controller.ts
│   │   │   ├── weather.controller.ts
│   │   │   ├── supports.controller.ts
│   │   │   └── notifications.controller.ts
│   │   ├── middleware/
│   │   │   ├── auth.ts              # JWT verification
│   │   │   └── error.ts             # Error handling
│   │   ├── routes/
│   │   ├── lib/
│   │   │   ├── prisma.ts            # Database client
│   │   │   └── notifications.ts     # Notification helpers
│   │   └── index.ts                 # Entry point
│   ├── prisma/
│   │   ├── schema.prisma            # Database schema
│   │   ├── migrations/              # Migration history
│   │   └── seed.ts                  # Sample data
│   └── package.json
│
├── frontend/
│   └── lib/
│       ├── screens/
│       │   ├── dashboard_screen.dart
│       │   ├── login_screen.dart
│       │   ├── product_list_screen.dart
│       │   ├── product_detail_screen.dart
│       │   ├── weather_screen.dart
│       │   ├── supports_list_screen.dart
│       │   └── profile_screen.dart
│       ├── services/
│       │   ├── api_service.dart     # Backend API client
│       │   ├── weather_service.dart # Weather API
│       │   ├── support_service.dart
│       │   └── location_service.dart
│       ├── data/
│       │   ├── type_fields.dart     # Type-specific UI fields
│       │   └── support_programs.dart
│       ├── widgets/
│       ├── l10n/
│       │   └── app_localizations.dart
│       ├── theme/
│       │   └── app_theme.dart
│       └── main.dart
│
├── docker-compose.yml
└── README.md
```

---

## API Endpoints

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | Login and get JWT |
| GET | `/api/auth/me` | Get current user info |

### Crops
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/crops` | List user's crops |
| GET | `/api/crops/:id` | Get crop details |
| POST | `/api/crops` | Create new crop |
| PUT | `/api/crops/:id` | Update crop |
| DELETE | `/api/crops/:id` | Delete crop |
| POST | `/api/crops/:id/spray` | Log spray application |
| POST | `/api/crops/:id/harvest` | Log harvest |
| POST | `/api/crops/:id/quality` | Log quality metrics |

### Livestock
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/livestock` | List user's livestock |
| GET | `/api/livestock/:id` | Get livestock details |
| POST | `/api/livestock` | Create new livestock |
| PUT | `/api/livestock/:id` | Update livestock |
| DELETE | `/api/livestock/:id` | Delete livestock |
| POST | `/api/livestock/:id/milk` | Log milk production |
| POST | `/api/livestock/:id/weight` | Log weight measurement |

### Weather
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/weather` | Get weather by location |
| GET | `/api/weather/coords` | Get weather by lat/lon |

### Support Programs
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/supports` | List support programs |
| POST | `/api/dash` | Legacy dashboard endpoint |

### Notifications
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/notifications` | List user notifications |
| PATCH | `/api/notifications/:id/read` | Mark as read |

---

## Configuration

### Backend Environment Variables

Create a `.env` file in the `backend/` directory:

```env
# Database
DATABASE_URL="postgresql://user:password@localhost:5432/alsapp"

# Authentication
JWT_SECRET="your-secure-secret-key"
JWT_EXPIRATION="24h"

# Server
PORT=8080
NODE_ENV=development

# External APIs
OPENWEATHER_API_KEY="your-openweathermap-api-key"
```

### Frontend Configuration

Edit `frontend/lib/config/api_config.dart`:

```dart
class ApiConfig {
  static const String baseUrl = 'http://10.0.2.2:8080/api';
  // For iOS simulator: 'http://localhost:8080/api'
  // For physical device: 'http://YOUR_IP:8080/api'
}
```

---

## Localization

ALSApp supports three languages:

- 🇬🇧 **English** (en)
- 🇹🇷 **Turkish** (tr)
- 🇫🇷 **French** (fr)

Translation strings are managed in `frontend/lib/l10n/app_localizations.dart`.

Users can switch languages in real-time using the language selector in the app bar.

---

## Development

### Running Tests

```bash
# Backend tests
cd backend
npm test

# Frontend tests
cd frontend
flutter test
```

### Database Management

```bash
# Create a new migration
npx prisma migrate dev --name your_migration_name

# Reset database
npx prisma migrate reset

# Open Prisma Studio (database GUI)
npx prisma studio
```

### Building for Production

```bash
# Backend
cd backend
npm run build
npm start

# Frontend (Android)
cd frontend
flutter build apk --release

# Frontend (iOS)
flutter build ios --release
```

---

## Documentation

Additional documentation is available:

- [Type-Specific Tracking Guide](docs/type_specific_tracking.md)
- [Support Programs Guide](SUPPORT_PROGRAMS_GUIDE.md)
- [Tracking Implementation Guide](TRACKING_IMPLEMENTATION_GUIDE.md)

---

## Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## Contact & Support

- **Website:** [tarimhayvancilikdestek.com.tr](https://tarimhayvancilikdestek.com.tr)
- **Issues:** Use GitHub Issues for bug reports and feature requests

---

## License

This project is developed for academic purposes at TED University, Department of Computer Engineering.

---

<p align="center">
  <strong>ALSApp: Bridging Traditional Agricultural Knowledge with Modern Digital Technologies</strong>
</p>

<p align="center">
  <em>Supporting Turkish Farmers in the Digital Transformation of Agriculture</em>
</p>

<p align="center">
  © 2025 TED University - Department of Computer Engineering
</p>

