# Firebase Security Rules Reference

## Updated: December 17, 2025

This document outlines the simplified security rules for both Firestore and Realtime Database.

---

## Role-Based Permissions

### 🔴 **Superior Admins** (role: `superior` or `super_admin`)
- ✅ **Firestore**: Read and write EVERYTHING in all collections
- ✅ **Realtime Database**: Read and write EVERYTHING in all paths
- ✅ Can manage all schools, admins, students, drivers, buses, routes
- ✅ Full access without restrictions

### 🟡 **School Admins** (role: `schoolAdmin`, `school_admin`, or `regionalAdmin`)
- ✅ **Firestore**: Read and write ONLY their school's data
- ✅ **Realtime Database**: Read and write their school's GPS/tracking data
- ✅ Can manage students, drivers, buses, routes in their school
- ✅ Can create other school admins in their school (in `/admins` collection)
- ❌ Cannot access other schools' data
- ❌ Cannot modify superior admin accounts

### 🟢 **Drivers** (role: `driver`)
- ✅ **Firestore**: Read their school's collections (students, buses, routes)
- ✅ **Firestore**: Update own profile (lastLogin, fcmToken, currentLocation)
- ✅ **Realtime Database**: Read their school's GPS data
- ✅ **Realtime Database**: Write GPS location for their assigned bus only
- ✅ Can update bus route type (pickup/dropoff) for their assigned bus
- ❌ Cannot create/delete any records
- ❌ Cannot access other schools' data

### 🔵 **Students** (role: `student`)
- ✅ **Firestore**: Read their school's data (buses, routes, drivers)
- ✅ **Firestore**: Read and update own student profile
- ✅ **Firestore**: Update own preferences (language, notifications, stop location, fcmToken)
- ✅ **Realtime Database**: Read their school's GPS/tracking data
- ❌ Cannot write to Realtime Database
- ❌ Cannot access other schools' data
- ❌ Cannot create/delete any records

---

## Firestore Collections

### `/adminusers/{userId}` - User Accounts
- **Superior**: Full read/write access
- **School Admin**: Read/write users in their school only
- **Driver**: Read/update own document (non-sensitive fields)
- **Student**: Read/update own document (preferences only)

### `/schooldetails/{schoolId}` - School Data (PRIMARY)
- **Superior**: Full read/write access
- **School Admin**: Read/write their school only
- **Driver**: Read their school only
- **Student**: Read their school only

#### Sub-collections:
- `/students/{studentId}` - Student profiles
- `/drivers/{driverId}` - Driver profiles
- `/buses/{busId}` - Bus information
- `/routes/{routeId}` - Route schedules
- `/notifications/{notificationId}` - Push notifications

### `/admins/{adminId}` - Admin Portal Users
- **Superior**: Full read/write access
- **School Admin**: Can create other school admins in their school
- **School Admin**: Read admins in their school
- **All Admins**: Read own document

### `/notificationTimers/{studentId}` - Notification Settings
- **Superior**: Full read/write access
- **School Admin**: Read/write their school's timers
- **Student**: Read/write own timers

### `/schools/{schoolId}` - Legacy School Data
- **Superior**: Full read/write access
- **School Admin**: Read/write their school only
- **Driver & Student**: Read their school only

---

## Realtime Database Paths

### `/bus_locations/{schoolId}/{busId}` - Live GPS Tracking
- **Read**: Superior, School Admin (their school), Driver (their school), Student (their school)
- **Write**: Superior, School Admin (their school), Driver (their assigned bus only)
- **Validation**: Must include: isActive, latitude, longitude, heading, speed, timestamp

### `/live_bus_locations/{schoolId}/{busId}` - Current Location
- **Read**: Superior, School Admin (their school), Driver (their school), Student (their school)
- **Write**: Superior, School Admin (their school), Driver (their assigned bus only)
- **Validation**: Must include: latitude, longitude, timestamp

### `/trip_transitions/{schoolId}/{busId}` - Trip Status Changes
- **Read**: Superior, School Admin (their school), Driver (their school), Student (their school)
- **Write**: Superior, School Admin (their school), Driver (their assigned bus only)

### `/route_schedules_cache/{schoolId}/{busId}` - Cached Route Data
- **Read**: Superior, School Admin (their school), Driver (their school), Student (their school)
- **Write**: Superior, School Admin (their school only)

### Root Level
- **Read**: Superior only
- **Write**: Superior only

---

## Custom Claims Required

All users MUST have these custom claims in their authentication token:

```javascript
{
  role: 'student' | 'driver' | 'schoolAdmin' | 'school_admin' | 'superior' | 'super_admin',
  schoolId: 'SCH...' // Required for school-level access
  assignedBusId: 'BUS...' // Required for drivers
}
```

### Setting Custom Claims
Custom claims are automatically set during login via the `_ensureCustomClaims()` method which calls the `setUserClaims` Cloud Function.

---

## Security Features

### ✅ School Isolation
- School admins, drivers, and students can ONLY access their own school's data
- Enforced through `belongsToSchool(schoolId)` check: `userSchoolId() == schoolId`

### ✅ Bus Assignment
- Drivers can only write GPS data for their assigned bus
- Enforced through `userBusId() == busId` check

### ✅ Student Preferences
- Students can only update specific preference fields
- Protected fields like role, schoolId, assignedBusId cannot be modified by students

### ✅ Superior Override
- Superior admins bypass all restrictions
- Used for system administration and cross-school operations

---

## Web Portal Loading Issues - FIXED ✅

**Previous Issue**: School admins couldn't load data in web portal

**Root Cause**: Rules were too restrictive and didn't allow school admins full access to their school

**Solution Applied**:
1. Added explicit full read/write access for superior admins
2. Added full read/write access for school admins to their school data
3. Simplified permission checks to avoid complex nested conditions
4. Added catch-all rule for superior admins at root level

**Result**: School admins can now:
- View all students, drivers, buses in their school
- Create/edit/delete school records
- Manage notifications and schedules
- Access school admin dashboard

---

## Testing Checklist

### Superior Admin
- [ ] Can view all schools in web portal
- [ ] Can edit any school's data
- [ ] Can create/delete school admins
- [ ] Can access all Firebase collections

### School Admin
- [ ] Can login to web portal
- [ ] Can view their school's students
- [ ] Can create/edit/delete students and drivers
- [ ] Can manage buses and routes
- [ ] Cannot access other schools' data

### Driver (Mobile App)
- [ ] Can view students on their bus
- [ ] Can update GPS location
- [ ] Can switch between pickup/dropoff routes
- [ ] Can view bus schedule

### Student (Mobile App)
- [ ] Can view bus live location
- [ ] Can change language preference
- [ ] Can update notification settings
- [ ] Can change stop location
- [ ] Can view route schedule

---

## Deployment Commands

```powershell
# Deploy Firestore rules only
firebase deploy --only firestore:rules

# Deploy Realtime Database rules only
firebase deploy --only database:rules

# Deploy both
firebase deploy --only firestore:rules,database:rules
```

---

## Important Notes

⚠️ **Users must logout and login after rule changes** to get fresh authentication tokens with custom claims.

⚠️ **Hot restart does NOT refresh tokens** - only actual logout/login or clearing browser storage.

⚠️ **Check custom claims** in browser console:
```javascript
firebase.auth().currentUser.getIdTokenResult().then(token => {
  console.log("Custom Claims:", token.claims);
});
```

⚠️ **For troubleshooting**, check Firebase Console → Authentication → Users → Custom Claims to verify claims are set correctly.
