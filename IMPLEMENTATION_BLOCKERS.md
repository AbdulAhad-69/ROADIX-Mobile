# ROADIX — Implementation Blockers & External Console Configuration

This document records all external platform configurations, credentials, and console setup required for live production deployment beyond local source code and database migrations.

---

## 1. Supabase Dashboard: Phone OTP Provider (Auth -> Providers -> Phone)

### Context:
In development, Supabase Auth allows phone sign-ins using test phone numbers or configured SMS providers. For live Bangladeshi carrier delivery:

### Required Action:
1. Log into [Supabase Dashboard](https://supabase.com/dashboard/project/rgzmoqpkugpcqfryrjkj).
2. Navigate to **Authentication** -> **Providers** -> **Phone**.
3. Enable **Phone Provider**.
4. Select SMS provider:
   - **Twilio**: Account SID, Auth Token, Message Service SID (supports Bangladesh international SMS).
   - Alternatively **MessageBird** or custom HTTP Webhook for local Bangladesh aggregators (e.g., SSL Wireless, BulkSMS BD).
5. For testing without SMS credits:
   - Add test phone numbers under **Authentication** -> **Providers** -> **Phone** -> **Test phone numbers** (e.g., `+8801700000000` with fixed OTP `123456`).

---

## 2. Google Cloud Console: OAuth 2.0 Credentials (Sign In with Google)

### Context:
The ROADIX mobile app has configured Google OAuth intent filtering for deep linking callback:
- Redirect URI: `io.supabase.roadix://login-callback`
- Web Redirect URI: `https://rgzmoqpkugpcqfryrjkj.supabase.co/auth/v1/callback`

### Required Action:
1. In [Google Cloud Console](https://console.cloud.google.com/apis/credentials):
   - Configure **OAuth Consent Screen** (App Name: `ROADIX`, User Support Email, Developer Contact).
   - Create **Web Application** Client ID:
     - Authorized redirect URI: `https://rgzmoqpkugpcqfryrjkj.supabase.co/auth/v1/callback`
   - Copy Client ID and Client Secret into **Supabase Dashboard** -> **Authentication** -> **Providers** -> **Google**.
   - Create **Android** Client ID:
     - Package name: `com.roadix.roadix_mobile`
     - SHA-1 Fingerprint: Run `keytool -list -v -keystore ~/.android/debug.keystore` to extract local debug fingerprint.

---

## 3. Apple Developer Console: Sign in with Apple (iOS Production)

### Required Action:
1. In [Apple Developer Member Center](https://developer.apple.com/account/resources/identifiers/list):
   - Enable **Sign In with Apple** on the App ID `com.roadix.roadix_mobile`.
   - Create a **Services ID** for Web/OAuth flows.
   - Configure Return URL: `https://rgzmoqpkugpcqfryrjkj.supabase.co/auth/v1/callback`.
2. Generate private key (`.p8`) and configure Key ID, Team ID, and Service ID in **Supabase Dashboard** -> **Authentication** -> **Providers** -> **Apple**.

---

## 4. Map Tiles & Geolocation API Keys

### Context:
Currently configured with CARTO open raster tiles (`https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png`) and device hardware GPS via `geolocator`.

### Recommended Upgrade for Production:
1. Register a dedicated MapTiler or Mapbox access token if vector graphics or custom satellite styles are required.
2. For reverse-geocoding (converting GPS coordinates to precise Dhaka street names), plug in OpenStreetMap Nominatim or Google Geocoding API key in `AppConfig`.
