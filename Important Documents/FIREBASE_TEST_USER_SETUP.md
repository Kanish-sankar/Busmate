# Firebase Test User Setup

## Quick Setup Instructions

### Option 1: Firebase Console (Recommended)
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Authentication** → **Users** tab
4. Click **Add User**
5. Enter:
   - **Email**: `kanish@gmail.com`
   - **Password**: `123456`
6. Click **Add User**
7. Copy the **User UID** that was generated
8. Go to **Firestore Database**
9. Go to the `students` collection
10. Click **Add Document**
11. Set Document ID to the **User UID** you copied
12. Add the following fields:
```json
{
  "email": "kanish@gmail.com",
  "name": "Kanish Test User",
  "studentId": "STU001",
  "schoolId": "school_001",
  "assignedBusId": "bus_001",
  "assignedDriverId": "driver_001",
  "fcmToken": "",
  "createdAt": (use Timestamp - current time)
}
```

### Option 2: Using Firebase CLI (Advanced)

If you have Firebase CLI installed, you can run this script from your terminal:

```bash
# Login to Firebase
firebase login

# Select your project
firebase use your-project-id

# Use Firebase Admin SDK or Firestore REST API to create the user
```

### Option 3: Create User Programmatically

You can also create a test registration function in your app temporarily:

```dart
// Add this temporary function in your auth_login.dart
Future<void> createTestUser() async {
  try {
    // Create Firebase Auth user
    UserCredential userCredential = await auth.createUserWithEmailAndPassword(
      email: 'kanish@gmail.com',
      password: '123456',
    );
    
    String uid = userCredential.user!.uid;
    
    // Create Firestore document
    await FirebaseFirestore.instance.collection('students').doc(uid).set({
      'email': 'kanish@gmail.com',
      'name': 'Kanish Test User',
      'studentId': 'STU001',
      'schoolId': 'school_001',
      'assignedBusId': 'bus_001',
      'assignedDriverId': 'driver_001',
      'fcmToken': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    print('Test user created with UID: $uid');
    Get.snackbar('Success', 'Test user created successfully!');
  } catch (e) {
    print('Error creating test user: $e');
    Get.snackbar('Error', 'Failed to create test user: $e');
  }
}
```

## Test Credentials

After setup, use these credentials to login:

- **Email**: `kanish@gmail.com`
- **Password**: `123456`

## How It Works Now

1. User enters email and password
2. App authenticates with Firebase Auth
3. On success, app checks if user exists in `students` or `drivers` collection
4. If found in `students`: Navigate to Stop Location Screen (Parent/Student view)
5. If found in `drivers`: Navigate to Driver Screen
6. User data is stored in GetStorage for session management
7. FCM token is updated for push notifications

## Collections Structure

### Students Collection
```
students/{userId}
  - email: string
  - name: string
  - studentId: string
  - schoolId: string
  - assignedBusId: string
  - assignedDriverId: string
  - fcmToken: string
  - createdAt: timestamp
```

### Drivers Collection
```
drivers/{userId}
  - email: string
  - name: string
  - driverId: string
  - schoolId: string
  - assignedBusId: string
  - fcmToken: string
  - createdAt: timestamp
```

## Testing

After creating the test user:
1. Run the app: `flutter run`
2. Go to Sign In screen
3. Enter email: `kanish@gmail.com`
4. Enter password: `123456`
5. Click Sign In
6. Should navigate to Stop Location screen (if student) or Driver screen (if driver)

## Troubleshooting

- If login fails, check Firebase Console logs
- Ensure Firebase Authentication is enabled for Email/Password
- Ensure Firestore rules allow read/write (adjust for production)
- Check that the document ID in Firestore matches the Firebase Auth UID

## Security Notes

- These are test credentials - DO NOT use in production
- Change Firebase Security Rules before deploying
- Implement proper password requirements in production
- Add email verification in production
