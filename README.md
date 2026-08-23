# Cavite Explorer Tourist Guide

<p align="center">
  <img src="cavite_explorer_mobile/assets/images/cavite-explorer-logo.png" alt="Cavite Explorer logo" width="150" />
</p>

<p align="center">
  A location-aware tourism, verified public-transport, landmark badge, and local-partner rewards platform for Cavite.
</p>

## Live services

| Service | Address |
| --- | --- |
| Admin portal | <https://cavite-explorer-admin.dogoodiecommunity.chatgpt.site> |
| Backend API | <https://cavite-explorer-backend.onrender.com> |
| Health check | <https://cavite-explorer-backend.onrender.com/health> |
| Android package ID | `ph.caviteexplorer.app` |

The backend is hosted on Render's free tier. After a period of inactivity, the first request may take longer while the service wakes up.

## Hackathon review guide

Cavite Explorer is a working tourism and local-mobility prototype, not merely a design concept. It is designed around a practical problem for visitors: finding meaningful places in Cavite, understanding a locally verified way to reach them, and being rewarded for an actual visit.

For a quick review, judges can:

1. Open the mobile app and browse landmark information, photos, visitor stories, ratings, and nearby destinations.
2. Choose a landmark to compare available verified commute options, then start the live commute guide.
3. Visit a configured landmark radius to see the badge-verification countdown and local notification flow.
4. Open the badge collection to see earned and locked badges, including a unique QR-based partner redemption credential for an earned badge.
5. Sign in to the admin portal as an administrator or editor to review the mapped-landmark, route-builder, partner-approval, and data-maintenance workflows.

The deployed API health endpoint is available without credentials. The administrative portal and role-specific functions require valid authorized accounts.

## What the system does

Cavite Explorer connects four workflows in one platform:

1. **Tourists** discover landmarks, compare verified commute options, follow live location guidance, collect visit badges, save places, and share memories.
2. **Partners** submit their business for approval and validate one-time badge discounts using QR codes.
3. **Editors** maintain landmark and transport information without receiving account-administration privileges.
4. **Administrators** control accounts, publication, partner approval, analytics, and all managed content.

### Mobile application

- Landmark discovery, search, municipality filters, popularity rankings, ratings, and nearby results
- Detailed landmark pages with overview, history, visit planning, reminders, community reviews, and badge offers
- Saved/favorite landmarks and pull-to-refresh data updates
- Verified jeepney, modern jeepney, bus, multicab, tricycle, and UV Express information
- Route alternatives balancing fare, transfers, and walking distance
- Live commute guidance that follows the user's position and advances steps automatically
- Badge countdowns based on landmark radius and required visit time
- Background visit tracking and local Android notifications
- Badge collection with unique QR redemption credentials
- Partner discovery and one-time discount redemption per partner
- Verified visitor reviews, ratings, photos, and a private-first memory journal
- Full-screen swipeable photo galleries
- Separate partner onboarding, dashboard, QR scanner, and redemption reports

### Key innovation and data model

- **Verified-first commute engine:** Routes, signboards, fares, boarding areas, transfer points, road labels, and route geometry are maintained by authorized local administrators instead of being invented by an AI model.
- **Human-readable assistance:** Groq is used to phrase verified route data clearly. It is not treated as the source of transport truth.
- **Visit-to-reward loop:** GPS verification, required stay duration, background tracking, a unique badge credential, proximity-based partner eligibility, and server-side one-time redemption checks form one complete reward workflow.
- **Community content with verification:** Ratings, photos, stories, and memories are linked to actual landmark visits, helping reduce low-quality or unrelated place reviews.
- **Role-based operations:** Admins govern accounts and approval; editors curate place and transport data; partners manage offers and scan QR codes; tourists discover, navigate, collect, and share.

### Admin portal

- Role-aware authentication for administrators and editors
- Account search, role management, activation/deactivation, and secure invitations
- Landmark create/edit flow with map pinning, multiple photos, publication state, visitor information, history, reminders, and badge configuration
- Verified transport route builder with exact geometry, signboards, direction, access/transfer points, road labels, fares, and verification dates
- Tricycle terminal coverage management
- Partner application review and approval
- Offer management, analytics, and stale-route reminders

## Role and permission summary

| Capability | Guest | Tourist (`user`) | Partner | Editor | Admin |
| --- | :---: | :---: | :---: | :---: | :---: |
| Browse published landmarks | Yes | Yes | Partner app only | Yes | Yes |
| Use commute guidance | Limited | Yes | No | Preview/manage | Preview/manage |
| Save places, badges, memories, reviews | No | Yes | No | No | No |
| Scan badge QR codes | No | No | Yes | No | No |
| Submit a partner business | No | No | Yes | No | No |
| Create/edit landmark and transport content | No | No | No | Yes | Yes |
| Publish/archive/delete landmarks | No | No | No | No | Yes |
| Approve/reject partners | No | No | No | No | Yes |
| Invite and manage privileged accounts | No | No | No | No | Yes |

For complete step-by-step instructions, see [Cavite Explorer Role Workflows](output/pdf/Cavite-Explorer-Role-Workflows.pdf).

## Architecture

```text
Android Flutter app -----------+
                               |
Admin web portal --------------+--> NestJS REST API on Render
                                      |       |       |
                                      |       |       +--> Groq route-language assistance
                                      |       +----------> Cloudinary image storage
                                      +------------------> Neon PostgreSQL + Neon Auth

Brevo API <--------------------------- admin/editor/partner invitation delivery
Neon shared email <------------------- mobile verification and password-reset codes
OpenStreetMap / Leaflet <------------- map tiles, search, and route visualization
```

The commute engine treats administrator-verified transport data as the source of truth. AI helps present the result in understandable language; it does not invent replacement routes.

## Known limitations

- **Landmark coverage is not yet complete for all of Cavite.** The current landmark catalogue is a curated and growing dataset, focused on the locations that have been entered and reviewed so far. It does **not** yet represent every historical site, museum, park, cultural space, church, restaurant, community attraction, or municipality in Cavite.
- **Transportation-route data is still incomplete.** The current database does not yet cover every jeepney, modern jeepney, bus, multicab, UV Express, or tricycle service in Cavite and nearby cities.
- Commute suggestions are limited to the routes and transfer connections that administrators or editors have already mapped and verified. A valid local route may therefore be missing from the results.
- Route names, signboards, fares, stops, schedules, and road paths can change. Transport records require continued field validation and regular updates before the system is used as a complete public commuting reference.
- Landmark descriptions, visitor schedules, fees, contact details, accessibility notes, badge settings, and partner offers also require ongoing local verification. The platform is built to make these updates manageable through the admin/editor portal.
- The current release is optimized and tested for Android distribution. iOS distribution requires a macOS/Xcode build environment and separate Apple signing before it can be released.
- Render's free-tier cold starts and public OpenStreetMap tile availability may affect first-load speed during demonstrations.
- Users should treat the current commute feature as a field-testing guide and confirm critical trip details locally when a route has limited or outdated coverage.

### Coverage and safety policy

The app intentionally avoids presenting unmapped places or unverified transport services as if they were complete data. When there is no supported commute path, the intended product behavior is to communicate that no verified route is available rather than fabricate a recommendation. This protects visitors while giving admins a clear reason to add the missing landmark, route, terminal, road geometry, or transfer point.

## Repository layout

```text
.
|-- cavite-explorer-admin/      # React 19 + vinext administrative portal
|-- cavite-explorer-backend/    # NestJS API, Prisma schema, and operational scripts
|-- cavite_explorer_mobile/     # Flutter Android/iOS source (Android release is supported here)
|-- output/pdf/                 # Generated role workflow manual
|-- render.yaml                 # Render Blueprint for the backend
`-- README.md
```

## Prerequisites

- Node.js 22.16 or a compatible Node.js 22 release
- npm
- Flutter stable (the project was validated with Flutter 3.44)
- Android Studio, Android SDK, and a Java runtime for Android builds
- PostgreSQL database (Neon is currently used)
- Neon Auth project
- Cloudinary account for persistent image storage
- Brevo API key and verified sender for invitation emails
- Groq API key for assisted route-language generation

No Google Maps billing account is required. The map experience uses OpenStreetMap data and tiles. Review the OpenStreetMap tile usage policy before operating at substantial public scale.

## Local development

### 1. Clone the repository

```powershell
git clone https://github.com/mirasol25/caviteExplorerTouristGuide.git
cd caviteExplorerTouristGuide
```

### 2. Configure and run the backend

```powershell
cd cavite-explorer-backend
Copy-Item .env.example .env
npm install
npx prisma generate
npx prisma db push
npm run start:dev
```

The API starts on `http://localhost:3000`. Confirm it with:

```text
http://localhost:3000/health
```

Required backend environment variables:

| Variable | Purpose |
| --- | --- |
| `DATABASE_URL` | Neon/PostgreSQL connection string |
| `JWT_SECRET` | Long random secret for locally issued access tokens |
| `NEON_AUTH_URL` | Neon Auth service endpoint |
| `NEON_JWKS_URL` | Neon JSON Web Key Set endpoint |
| `CLOUDINARY_URL` | Persistent image upload credentials |
| `GROQ_API_KEY` | Assisted commute-language generation |
| `GROQ_MODEL` | Accessible Groq model, currently `openai/gpt-oss-120b` |
| `BREVO_API_KEY` | Transactional admin/editor/partner invitation delivery |
| `BREVO_SENDER_EMAIL` | Verified Brevo sender address |
| `ADMIN_WEB_URL` | Admin portal origin and callback destination |
| `CORS_ORIGINS` | Comma-separated allowed browser origins |
| `PARTNER_INVITE_WEB_URL` | Mobile-compatible partner invite bridge |

See [`cavite-explorer-backend/.env.example`](cavite-explorer-backend/.env.example) for the complete development template. Never commit the real `.env` file.

### 3. Run the admin portal

Create `cavite-explorer-admin/.env.local`:

```env
NEXT_PUBLIC_API_URL=http://localhost:3000
```

Then run:

```powershell
cd ..\cavite-explorer-admin
npm install
npm run dev
```

The local admin portal starts on `http://localhost:3001`.

### 4. Run the Flutter app on an Android emulator

```powershell
cd ..\cavite_explorer_mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

`10.0.2.2` is the Android emulator's bridge to the host computer. Do not use it for a physical phone.

### 5. Run the Flutter app on a physical Android phone during local development

Connect the phone and computer to the same network, enable USB debugging, and use the computer's LAN IPv4 address:

```powershell
flutter run --dart-define=API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:3000
```

Ensure the Windows firewall allows the backend port. For ordinary testing and distribution, use the deployed HTTPS backend instead.

## Build the distributable Android APK

The release build must point to the public HTTPS API:

```powershell
cd cavite_explorer_mobile
flutter clean
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://cavite-explorer-backend.onrender.com
```

Output:

```text
cavite_explorer_mobile/build/app/outputs/flutter-apk/app-release.apk
```

Before distributing:

1. Keep the release keystore and `android/key.properties` private and backed up.
2. Never commit keystore passwords, API secrets, or `.env` files.
3. Install the APK on at least one real Android phone.
4. Test login, permissions, maps, live commute, background tracking, badge completion, photo uploads, QR scanning, and deep links.
5. Preserve the same keystore for every future update; Android will reject updates signed by a different key.

## Deployment

### Backend on Render

The root [`render.yaml`](render.yaml) defines the backend service. Render builds it with:

```text
npm ci --include=dev && npx prisma generate && npm run build
```

and starts it with:

```text
npm run start:prod
```

Add all secret variables in the Render dashboard. Values marked `sync: false` are intentionally not stored in Git.

### Admin portal

The deployed portal must set:

```env
NEXT_PUBLIC_API_URL=https://cavite-explorer-backend.onrender.com
```

Its public origin must also appear in the backend's `ADMIN_WEB_URL`, `FRONTEND_URL`, and `CORS_ORIGINS` configuration.

### Authentication redirects and deep links

- Web callbacks must use the deployed admin HTTPS domain.
- Mobile partner invitations use the `caviteexplorer://accept-invite` deep link through the configured invite bridge.
- Mobile signup verification uses a six-digit Neon email OTP.
- Mobile password resets use a six-digit Neon email OTP; the legacy reset deep link remains available for web/link compatibility.
- Add only valid callback domains to Neon Auth's trusted-domain settings.

## Data and reward rules

- A badge is unique per user and landmark.
- A visit counts only while the user is within the landmark's configured verification radius.
- Leaving pauses the visit; returning within the grace period preserves progress.
- A collected badge has a unique redemption credential and QR code.
- A tourist may redeem that badge once at each eligible partner.
- A partner must be approved and located within the configured 2.5 km landmark reward area.
- A second scan of the same badge by the same partner is rejected.
- Community posts are tied to verified landmark visitors.
- Personal memories may remain private or be shared publicly.

## Validation commands

```powershell
# Backend
cd cavite-explorer-backend
npm run build

# Admin portal
cd ..\cavite-explorer-admin
npm run build

# Flutter
cd ..\cavite_explorer_mobile
flutter analyze
flutter test
```

## Troubleshooting

### `EADDRINUSE: address already in use 0.0.0.0:3000`

Another backend process is already using port 3000. Stop the older process or change the development port.

### Mobile app cannot reach `localhost`

On Android, `localhost` points to the Android device itself. Use `10.0.2.2` for the emulator, a LAN IP for local physical-phone testing, or the deployed Render HTTPS URL.

### Render returns `Cannot GET /`

The API root is not an application page. Use `/health` to verify the service.

### Invitation email is created but not delivered

Verify the Brevo sender, API key, and IP-authorization settings. Also check spam and institutional mail filtering.

### `Invalid callbackURL` or `Invalid redirectURL`

Make the exact web origin or callback domain trusted in Neon Auth. Do not register Android emulator-only hosts as production domains.

### Images disappear after deployment

Do not depend on Render's temporary local filesystem. Confirm `CLOUDINARY_URL` is configured and new database image values are Cloudinary URLs.

### OpenStreetMap warning or slow tile loading

Use an identifiable app user agent, cache responsibly, and move to a suitable OSM-compatible tile provider if public traffic grows beyond community tile-server expectations.

## Security notes

- `.env`, `key.properties`, keystores, API keys, and database credentials are secrets.
- User and role authorization is enforced in the backend, not only by hiding interface controls.
- Administrators cannot change their own role; another administrator must do so.
- Disabled accounts are rejected by the authentication guard.
- Invitation links are one-time, hashed in storage, and expire after seven days.
- QR redemption is checked server-side for ownership, partner eligibility, distance, and previous use.

## Project status

The system is ready for controlled Android field testing and hackathon evaluation. Before a broad public launch, complete landmark and route coverage across Cavite, run a real-device test matrix across multiple Android versions, review privacy disclosures and data-retention rules, add operational monitoring/backups, establish a transport-data review schedule, and confirm that map-tile usage remains compliant at the expected traffic level.
