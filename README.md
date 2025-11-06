# 🚌 BusMate - School Bus Management System

[![Flutter](https://img.shields.io/badge/Flutter-3.32.8-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore-orange.svg)](https://firebase.google.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-lightgrey.svg)](https://flutter.dev/)

A comprehensive school bus management system with real-time GPS tracking, built with Flutter and Firebase. Includes both mobile app for parents/drivers and web dashboard for school administrators.

**By [Jupenta Technologies](https://jupenta.com)**

---

## 📱 Applications

### 1. **BusMate Mobile App** (`busmate_app/`)
Mobile application for parents and drivers with real-time tracking capabilities.

**Features:**
- 📍 Real-time GPS bus tracking on OpenStreetMap
- 👨‍👩‍👧‍👦 Parent dashboard with child tracking
- 🚗 Driver interface for route management
- 🔔 Push notifications for bus status updates
- 🔐 Secure authentication (Parent & Driver roles)
- 📊 Trip history and analytics

**Platforms:** Android, iOS

### 2. **BusMate Web Dashboard** (`busmate_web/`)
Web-based admin dashboard for school management and monitoring.

**Features:**
- 🏫 Multi-school support with data isolation
- 🚌 Bus fleet management (unlimited capacity)
- 👥 Student and driver management
- 🗺️ Real-time fleet monitoring on map
- 💰 Payment tracking (WhatsApp integration)
- 📈 Analytics and reports
- 👔 Role-based access (Superior Admin & School Admin)

**Platform:** Web (Chrome, Firefox, Safari, Edge)

---

## 🏗️ Architecture

### Data Structure
```
Firestore Database:
├── admins/                          # Web dashboard users
│   ├── {adminId}                    # Admin document
│   └── ...
├── adminusers/                      # Mobile app users (drivers/parents)
│   ├── {userId}                     # User document
│   └── ...
├── schooldetails/                   # School data (root)
│   ├── {schoolId}/                  # Individual school
│   │   ├── buses/                   # Subcollection: School buses
│   │   │   └── {busId}             # Bus document
│   │   ├── drivers/                 # Subcollection: School drivers
│   │   │   └── {driverId}          # Driver document
│   │   └── students/                # Subcollection: School students
│   │       └── {studentId}         # Student document
│   └── ...
└── bus_status/                      # Real-time GPS tracking data
    └── {busId}                      # Current bus location
```

### Cost Optimization ⚡
Our architecture achieves **85-90% reduction in Firestore reads** through:
1. **Subcollection Architecture**: Data isolation per school (50-80% reduction)
2. **One-time Reads**: `.get()` instead of `.snapshots()` (70-85% reduction)
3. **Removed Auto-fetch**: Manual refresh instead of continuous listeners (97% reduction)

**Result:** Free Firebase tier supports **100+ schools** with 1,000 daily actions = only 6,000 reads (12% of free tier limit)

📖 [Full Cost Analysis](Important%20Documents/FIREBASE_COST_OPTIMIZATION.md)

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.32.8 or higher)
- Firebase account
- Node.js (for Cloud Functions)
- Android Studio / Xcode (for mobile builds)
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/busmate.git
   cd busmate
   ```

2. **Set up Firebase**
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Enable Firestore Database, Authentication, and Cloud Functions
   - Download configuration files:
     - `google-services.json` → `busmate_app/android/app/`
     - `GoogleService-Info.plist` → `busmate_app/ios/Runner/`
   - Run FlutterFire CLI:
     ```bash
     cd busmate_app
     flutterfire configure
     cd ../busmate_web
     flutterfire configure
     ```

3. **Install dependencies**
   ```bash
   # Mobile app
   cd busmate_app
   flutter pub get
   
   # Web dashboard
   cd ../busmate_web
   flutter pub get
   
   # Cloud Functions
   cd functions
   npm install
   ```

4. **Configure Environment**
   - Copy `.env.example` to `.env` and fill in your credentials
   - Update Firebase security rules from `firestore.rules`

5. **Run the applications**
   ```bash
   # Mobile app (Android/iOS)
   cd busmate_app
   flutter run
   
   # Web dashboard
   cd busmate_web
   flutter run -d chrome
   ```

---

## 🔧 Configuration

### Firestore Security Rules
Deploy the security rules from `firestore.rules`:
```bash
firebase deploy --only firestore:rules
```

### Cloud Functions
Deploy backend functions:
```bash
cd busmate_web/functions
firebase deploy --only functions
```

### Development Quick Login (Web Dashboard)
For development only, use these test credentials:

**Super Admin:**
- Email: `kanishadmin@gmail.com`
- Password: `123456`

**School Admin:**
- Email: `school@gmail.com`
- Password: `123456`

⚠️ **Remove quick login buttons before production deployment!**

---

## 📚 Documentation

### Key Documents
- [Firebase Cost Optimization](Important%20Documents/FIREBASE_COST_OPTIMIZATION.md) - Complete optimization analysis
- [Technical Documentation](Important%20Documents/TECHNICAL_DOCUMENTATION.md) - System architecture
- [Implementation Guide](Important%20Documents/IMPLEMENTATION_GUIDE.md) - Step-by-step setup
- [Screen Routes](Important%20Documents/SCREEN_ROUTES.md) - Navigation structure
- [Firebase Test Setup](Important%20Documents/FIREBASE_TEST_USER_SETUP.md) - Test user creation

### Project Structure
```
busmate/
├── busmate_app/               # Mobile application
│   ├── lib/
│   │   ├── presentation/      # UI screens and widgets
│   │   ├── meta/              # Business logic and helpers
│   │   └── main.dart          # App entry point
│   ├── android/               # Android configuration
│   └── ios/                   # iOS configuration
│
├── busmate_web/               # Web dashboard
│   ├── lib/
│   │   ├── modules/           # Feature modules
│   │   │   ├── Authentication/
│   │   │   ├── SchoolAdmin/
│   │   │   └── SuperAdmin/
│   │   └── main.dart          # Web entry point
│   └── functions/             # Firebase Cloud Functions
│
├── Important Documents/       # Comprehensive documentation
├── firestore.rules            # Firebase security rules
└── firestore.indexes.json     # Firestore indexes
```

---

## 🎯 Features in Detail

### For Parents 👨‍👩‍👧‍👦
- Track child's bus in real-time
- Receive notifications when bus is near
- View bus route and estimated arrival time
- Access trip history
- Emergency contact integration

### For Drivers 🚗
- Navigate assigned routes
- Mark stops as completed
- Send status updates to parents
- View student pickup/drop-off list
- Offline mode support

### For School Admins 🏫
- Manage entire bus fleet
- Assign drivers and routes
- Monitor all buses on single map
- Track payments (WhatsApp integration)
- Generate reports and analytics
- Student and driver management

### For Superior Admins 👔
- Manage multiple schools
- View system-wide analytics
- School onboarding and setup
- Payment oversight
- System configuration

---

## 🔐 Security

- **Authentication**: Firebase Authentication with role-based access
- **Data Isolation**: Subcollection structure prevents cross-school data access
- **Security Rules**: Comprehensive Firestore rules enforce permissions
- **Sensitive Data**: All credentials in `.env` (not committed to git)
- **API Keys**: Stored securely, never exposed client-side

---

## 💰 Cost Efficiency

### Firebase Free Tier Capacity
- **Before Optimization**: 10-20 schools
- **After Optimization**: 100+ schools ✨
- **Reads per day**: 6,000 reads for 1,000 actions (12% of 50K free tier)
- **Cost per school/month** (paid tier): ₹5-10 ($0.06-0.12)

### Optimization Techniques
1. ✅ One-time reads instead of real-time listeners
2. ✅ Subcollection architecture for data isolation
3. ✅ Removed unnecessary cloud functions
4. ✅ Client-side caching
5. ✅ Batch operations for multiple updates

📊 [View detailed cost analysis](Important%20Documents/FIREBASE_COST_OPTIMIZATION.md)

---

## 🛠️ Tech Stack

### Frontend
- **Framework**: Flutter 3.32.8
- **State Management**: GetX
- **Maps**: OpenStreetMap (flutter_osm_plugin)
- **UI**: Material Design 3

### Backend
- **Database**: Firebase Firestore
- **Authentication**: Firebase Auth
- **Functions**: Firebase Cloud Functions (Node.js)
- **Storage**: Firebase Storage (optional)

### Third-Party
- **Maps**: OpenStreetMap / Leaflet
- **Notifications**: Firebase Cloud Messaging (FCM)
- **Payments**: WhatsApp Business integration

---

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📞 Support

- **Email**: support@jupenta.com
- **Website**: [www.jupenta.com](https://jupenta.com)
- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/busmate/issues)

---

## 🎉 Acknowledgments

- Built with ❤️ by [Jupenta Technologies](https://jupenta.com)
- OpenStreetMap for free mapping services
- Firebase for scalable backend infrastructure
- Flutter community for amazing packages

---

## 🗺️ Roadmap

### Current Version (v1.0)
- ✅ Real-time GPS tracking
- ✅ Multi-school support
- ✅ Cost-optimized architecture
- ✅ Role-based authentication
- ✅ Web + Mobile platforms

### Upcoming Features (v2.0)
- 🔄 Krutrim AI integration for route optimization
- 🔄 Advanced analytics dashboard
- 🔄 Parent-teacher communication module
- 🔄 Attendance management
- 🔄 Fuel consumption tracking
- 🔄 Maintenance scheduling

---

## 📸 Screenshots

### Mobile App
| Parent Dashboard | Live Tracking | Driver Interface |
|-----------------|---------------|------------------|
| _Coming soon_   | _Coming soon_ | _Coming soon_    |

### Web Dashboard
| School Overview | Bus Management | Fleet Monitoring |
|----------------|----------------|------------------|
| _Coming soon_  | _Coming soon_  | _Coming soon_    |

---

## ⚠️ Important Notes

1. **Never commit sensitive files**:
   - `.env`
   - `firebase_options.dart`
   - `google-services.json`
   - `*.keystore` / `*.jks`

2. **Before production**:
   - Remove quick login buttons
   - Update Firebase security rules
   - Enable proper authentication
   - Set up proper error logging

3. **For Codemagic builds**:
   - Add environment variables in Codemagic dashboard
   - Configure signing certificates
   - Set up build triggers

---

**Made with 💙 in India by Jupenta Technologies**

