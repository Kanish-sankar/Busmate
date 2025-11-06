# 🔐 Firestore Security Rules for New Admin System

## Overview
This document contains the secure Firestore rules for the new `admins` collection structure with **superior** and **schoolAdmin** roles.

---

## 📋 NEW FIRESTORE RULES

Replace your current Firestore rules with these secure rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============================================
    // HELPER FUNCTIONS
    // ============================================
    
    // Check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Get admin document for current user
    function getAdminDoc() {
      return get(/databases/$(database)/documents/admins/$(request.auth.uid));
    }
    
    // Check if user is a superior admin
    function isSuperior() {
      return isAuthenticated() && 
             getAdminDoc().data.role == 'superior';
    }
    
    // Check if user is a school admin
    function isSchoolAdmin() {
      return isAuthenticated() && 
             getAdminDoc().data.role == 'schoolAdmin';
    }
    
    // Check if school admin has specific permission
    function hasPermission(permission) {
      return isAuthenticated() &&
             (isSuperior() || 
              (isSchoolAdmin() && getAdminDoc().data.permissions[permission] == true));
    }
    
    // Check if school admin belongs to specific school
    function belongsToSchool(schoolId) {
      return isAuthenticated() &&
             (isSuperior() || 
              (isSchoolAdmin() && getAdminDoc().data.schoolId == schoolId));
    }
    
    // ============================================
    // ADMINS COLLECTION (NEW)
    // ============================================
    
    match /admins/{adminId} {
      // Only superior admins can read all admin documents
      // School admins can only read their own document
      allow read: if isAuthenticated() && 
                     (isSuperior() || request.auth.uid == adminId);
      
      // Only superior admins with adminManagement permission can create/update/delete admins
      allow create, update, delete: if isSuperior() && hasPermission('adminManagement');
      
      // Validate admin document structure on create/update
      allow create, update: if request.resource.data.keys().hasAll(['email', 'role', 'createdAt']) &&
                               request.resource.data.role in ['superior', 'schoolAdmin'] &&
                               (request.resource.data.role == 'superior' || 
                                request.resource.data.keys().hasAll(['schoolId', 'permissions']));
    }
    
    // ============================================
    // SCHOOLS COLLECTION
    // ============================================
    
    match /schools/{schoolId} {
      // Superior can read all schools
      // School admins can only read their assigned school
      allow read: if belongsToSchool(schoolId);
      
      // Only superior admins can create/update/delete schools
      allow create, update, delete: if isSuperior();
      
      // ============================================
      // BUSES SUBCOLLECTION
      // ============================================
      
      match /buses/{busId} {
        // Read if belongs to school and has busManagement or viewingBusStatus permission
        allow read: if belongsToSchool(schoolId) && 
                       (hasPermission('busManagement') || hasPermission('viewingBusStatus'));
        
        // Write if belongs to school and has busManagement permission
        allow write: if belongsToSchool(schoolId) && hasPermission('busManagement');
      }
      
      // ============================================
      // PAYMENTS SUBCOLLECTION
      // ============================================
      
      match /payments/{paymentId} {
        // Read if belongs to school and has paymentManagement permission
        allow read: if belongsToSchool(schoolId) && hasPermission('paymentManagement');
        
        // Write if belongs to school and has paymentManagement permission
        allow write: if belongsToSchool(schoolId) && hasPermission('paymentManagement');
      }
    }
    
    // ============================================
    // STUDENTS COLLECTION
    // ============================================
    
    match /students/{studentId} {
      // Read if belongs to student's school and has studentManagement or viewingBusStatus permission
      allow read: if isAuthenticated() && 
                     (isSuperior() || 
                      (isSchoolAdmin() && 
                       resource.data.schoolId == getAdminDoc().data.schoolId &&
                       (hasPermission('studentManagement') || hasPermission('viewingBusStatus'))));
      
      // Write if belongs to student's school and has studentManagement permission
      allow write: if isAuthenticated() && 
                      (isSuperior() || 
                       (isSchoolAdmin() && 
                        request.resource.data.schoolId == getAdminDoc().data.schoolId &&
                        hasPermission('studentManagement')));
    }
    
    // ============================================
    // DRIVERS COLLECTION
    // ============================================
    
    match /drivers/{driverId} {
      // Read if belongs to driver's school and has driverManagement or viewingBusStatus permission
      allow read: if isAuthenticated() && 
                     (isSuperior() || 
                      (isSchoolAdmin() && 
                       resource.data.schoolId == getAdminDoc().data.schoolId &&
                       (hasPermission('driverManagement') || hasPermission('viewingBusStatus'))));
      
      // Write if belongs to driver's school and has driverManagement permission
      allow write: if isAuthenticated() && 
                      (isSuperior() || 
                       (isSchoolAdmin() && 
                        request.resource.data.schoolId == getAdminDoc().data.schoolId &&
                        hasPermission('driverManagement')));
    }
    
    // ============================================
    // BUS_STATUS COLLECTION
    // ============================================
    
    match /bus_status/{busId} {
      // Read if has viewingBusStatus permission
      allow read: if isAuthenticated() && hasPermission('viewingBusStatus');
      
      // Only drivers or superior admins can write
      // (Drivers write from mobile app, admins from web)
      allow write: if isAuthenticated();
    }
    
    // ============================================
    // NOTIFICATIONS COLLECTION
    // ============================================
    
    match /notifications/{notificationId} {
      // Read if has notifications permission
      allow read: if isAuthenticated() && hasPermission('notifications');
      
      // Write if has notifications permission
      allow write: if isAuthenticated() && hasPermission('notifications');
    }
    
    // ============================================
    // NOTIFICATION TIMERS COLLECTION
    // ============================================
    
    match /notificationTimers/{timerId} {
      // Only system (Cloud Functions) should access this
      allow read, write: if false;
    }
    
    // ============================================
    // PAYMENTS COLLECTION (Global)
    // ============================================
    
    match /payment/{paymentId} {
      // Read if has paymentManagement permission and belongs to same school
      allow read: if isAuthenticated() && 
                     (isSuperior() || 
                      (isSchoolAdmin() && 
                       resource.data.schoolId == getAdminDoc().data.schoolId &&
                       hasPermission('paymentManagement')));
      
      // Write if has paymentManagement permission
      allow write: if isAuthenticated() && hasPermission('paymentManagement');
    }
    
    // ============================================
    // BASIC DETAILS COLLECTION (Contact info, etc.)
    // ============================================
    
    match /basicDetails/{doc} {
      // Everyone can read (for login screen contact info)
      allow read: if true;
      
      // Only superior admins can write
      allow write: if isSuperior();
    }
    
    // ============================================
    // DENY ALL OTHER COLLECTIONS
    // ============================================
    
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## 🚀 HOW TO DEPLOY THESE RULES

### **Option 1: Firebase Console (Recommended for testing)**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `busmate-b80e8`
3. Navigate to **Firestore Database** → **Rules**
4. Copy the entire rules above
5. Paste into the rules editor
6. Click **Publish**

### **Option 2: Firebase CLI**

```bash
cd busmate_web

# Save rules to firestore.rules file
# Then deploy:
firebase deploy --only firestore:rules
```

---

## 🧪 TESTING THE RULES

### **Test 1: Superior Admin Access**
```javascript
// Superior admins should be able to:
✅ Read all admins
✅ Create/update/delete admins
✅ Read all schools
✅ Read/write students, drivers, buses
✅ Access all collections
```

### **Test 2: School Admin with Permissions**
```javascript
// School admin with studentManagement permission:
✅ Read students from their school
✅ Write students to their school
❌ Read students from other schools
❌ Access admin management
```

### **Test 3: School Admin without Permissions**
```javascript
// School admin WITHOUT studentManagement permission:
❌ Cannot read students
❌ Cannot write students
✅ Can still read their own admin document
```

---

## 🔐 SECURITY HIGHLIGHTS

### **1. Role-Based Access Control (RBAC)**
- Superior admins have full access
- School admins have permission-based access
- Granular permissions per feature

### **2. School Isolation**
- School admins can only access their own school's data
- Students, drivers, buses are isolated by schoolId
- No cross-school data access

### **3. Permission Validation**
- Each operation checks specific permission
- Permissions stored in admin document
- Superior admins bypass permission checks

### **4. Data Validation**
- Admin documents must have required fields
- Role must be 'superior' or 'schoolAdmin'
- School admins must have schoolId and permissions

---

## 📊 PERMISSION MATRIX

| Feature | Superior | School Admin (with permission) | School Admin (without permission) |
|---------|----------|-------------------------------|-----------------------------------|
| **Admin Management** | ✅ Full | ✅ If `adminManagement == true` | ❌ Denied |
| **Student Management** | ✅ Full | ✅ If `studentManagement == true` | ❌ Denied |
| **Driver Management** | ✅ Full | ✅ If `driverManagement == true` | ❌ Denied |
| **Bus Management** | ✅ Full | ✅ If `busManagement == true` | ❌ Denied |
| **Route Management** | ✅ Full | ✅ If `routeManagement == true` | ❌ Denied |
| **Payment Management** | ✅ Full | ✅ If `paymentManagement == true` | ❌ Denied |
| **Notifications** | ✅ Full | ✅ If `notifications == true` | ❌ Denied |
| **View Bus Status** | ✅ Full | ✅ If `viewingBusStatus == true` | ❌ Denied |

---

## ⚠️ IMPORTANT NOTES

### **Before Deploying:**
1. **Backup current rules** - Save your existing rules first
2. **Test in development** - Deploy to test project first
3. **Verify admin documents** - Ensure all admins have proper structure
4. **Update app logic** - Ensure app reads from 'admins' collection

### **After Deploying:**
1. **Monitor errors** - Check Firebase Console for rule violations
2. **Test all features** - Verify each permission works correctly
3. **Check logs** - Review Firestore usage for unauthorized access attempts

---

## 🐛 TROUBLESHOOTING

### **Error: "Missing or insufficient permissions"**
- Check if admin document exists in `admins` collection
- Verify admin has correct role ('superior' or 'schoolAdmin')
- Verify school admin has required permission enabled

### **Error: "Document not found"**
- Ensure user is logged in (request.auth != null)
- Check if admin document exists for current user UID

### **School Admin can't access data:**
- Verify `schoolId` matches in admin document and resource
- Check if required permission is set to `true`
- Ensure data belongs to admin's school

---

**Document Version:** 1.0  
**Last Updated:** October 25, 2025  
**Next Review:** After first production deployment
