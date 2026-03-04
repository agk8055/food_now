# Food Now 🍔🚀

A comprehensive, multi-vendor food delivery and e-commerce application built with Flutter and Firebase.

## Features ✨

### 🧑‍💼 User (Buyer) Features
*   **Authentication**: Secure login/signup using Firebase Auth and Google Sign-In.
*   **Home & Discovery**: Browse restaurants, food items, and Supermart products.
*   **Geolocation & Search**: Location-based restaurant discovery and advanced search functionality.
*   **Ordering System**: Seamless checkout experience and order history tracking (`BuyerOrdersScreen`).
*   **Profile Management**: Manage user profiles, delivery addresses, and personal details.

### 🏪 Seller Features
*   **Seller Registration & Onboarding**: Dedicated flow for new sellers to register their shop.
*   **Dashboard & Analytics**: Real-time insights into sales and business metrics (`SellerDashboard`, `SellerAnalyticsScreen`).
*   **Inventory Management**: Easy addition and management of food items/products.
*   **Order Management**: View, accept, prepare, and manage incoming customer orders.
*   **Shop Profile Management**: Edit shop details, availability, and operating hours.

### 🛡️ Admin Features
*   **Admin Dashboard**: Centralized control panel for platform management (`AdminDashboard`).
*   **Shop Verification**: Approve or reject new seller registrations.

## 🛠️ Tech Stack & Dependencies

*   **Framework**: [Flutter](https://flutter.dev/)
*   **Backend as a Service**: [Firebase](https://firebase.google.com/)
    *   `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging`
*   **Authentication**: `google_sign_in`
*   **Location Services**: `geolocator`, `geocoding`, `dart_geohash`
*   **Local Storage**: `shared_preferences`
*   **UI & Animations**: `lottie`, `google_fonts`, `flutter_native_splash`, `video_player`, `cupertino_icons`
*   **Networking & Utilities**: `http`, `intl`

## 🚀 Getting Started

### Prerequisites
*   Flutter SDK
*   Dart SDK
*   A Firebase Project with Android/iOS configured

### Installation

1.  **Clone the repository**
    ```bash
    git clone https://github.com/your-username/food_now.git
    cd food_now
    ```

2.  **Install dependencies**
    ```bash
    flutter pub get
    ```

3.  **Firebase Setup**
    Ensure you have `firebase_options.dart` configured in your `lib` directory (typically generated via FlutterFire CLI).
    *   Set up Firestore Database.
    *   Enable Email/Password and Google Sign-In in Firebase Authentication.

4.  **Run the app**
    ```bash
    flutter run
    ```

## 📱 Screenshots & Previews
*(Add screenshots of the Home Screen, Checkout, and Seller Dashboard here)*

## 🤝 Contributing
Contributions, issues, and feature requests are welcome!

## 📜 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
