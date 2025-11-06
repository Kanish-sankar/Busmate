const functions = require('firebase-functions/v2');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Secure Cloud Function to create a new school admin
 * Only super admins can create school admins
 */
exports.createSchoolAdmin = functions.https.onCall(async (data, context) => {
  try {
    // Check if user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    // Check if user has super admin permissions
    const userDoc = await db.collection('adminusers').doc(context.auth.uid).get();
    if (!userDoc.exists || userDoc.data().role !== 'superAdmin') {
      throw new functions.https.HttpsError('permission-denied', 'Only super admins can create school admins');
    }

    const { email, password, schoolId, permissions, adminName, adminId } = data;

    // Validate required fields
    if (!email || !password || !schoolId || !adminName) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }

    // Create Firebase Auth user
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: adminName,
    });

    // Create admin user document
    await db.collection('adminusers').doc(userRecord.uid).set({
      role: 'schoolAdmin',
      schoolId: schoolId,
      email: email,
      adminName: adminName,
      adminId: adminId || userRecord.uid,
      permissions: permissions || {
        busManagement: true,
        driverManagement: true,
        routeManagement: true,
        viewingBusStatus: true,
        studentManagement: true,
        paymentManagement: true,
        notifications: true,
        adminManagement: false,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: context.auth.uid,
    });

    // Add admin to school's admin collection
    await db.collection('schools').doc(schoolId).collection('admins').doc(userRecord.uid).set({
      adminId: adminId || userRecord.uid,
      adminName: adminName,
      email: email,
      permissions: permissions,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { 
      success: true, 
      adminId: userRecord.uid,
      message: 'School admin created successfully' 
    };

  } catch (error) {
    console.error('Error creating school admin:', error);
    
    // Handle specific Firebase Auth errors
    if (error.code === 'auth/email-already-exists') {
      throw new functions.https.HttpsError('already-exists', 'Email already in use');
    } else if (error.code === 'auth/invalid-email') {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid email address');
    } else if (error.code === 'auth/weak-password') {
      throw new functions.https.HttpsError('invalid-argument', 'Password is too weak');
    }
    
    throw new functions.https.HttpsError('internal', 'Failed to create school admin');
  }
});

/**
 * Secure Cloud Function to delete a user (admin or student)
 * Only authorized admins can delete users
 */
exports.deleteUser = functions.https.onCall(async (data, context) => {
  try {
    // Check authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { userId, userType } = data; // userType: 'admin' or 'student'

    if (!userId || !userType) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }

    // Check permissions based on user type
    const callerDoc = await db.collection('adminusers').doc(context.auth.uid).get();
    if (!callerDoc.exists) {
      throw new functions.https.HttpsError('permission-denied', 'User not found in admin users');
    }

    const callerData = callerDoc.data();
    
    if (userType === 'admin' && callerData.role !== 'superAdmin') {
      throw new functions.https.HttpsError('permission-denied', 'Only super admins can delete admin users');
    }

    if (userType === 'student' && callerData.role !== 'superAdmin' && callerData.role !== 'schoolAdmin') {
      throw new functions.https.HttpsError('permission-denied', 'Insufficient permissions to delete students');
    }

    // For school admins deleting students, ensure they belong to the same school
    if (userType === 'student' && callerData.role === 'schoolAdmin') {
      const studentDoc = await db.collection('students').doc(userId).get();
      if (studentDoc.exists && studentDoc.data().schoolId !== callerData.schoolId) {
        throw new functions.https.HttpsError('permission-denied', 'Cannot delete students from other schools');
      }
    }

    // Delete from Firebase Auth
    await admin.auth().deleteUser(userId);

    // Delete from appropriate Firestore collection
    if (userType === 'admin') {
      await db.collection('adminusers').doc(userId).delete();
      
      // Also remove from school's admin collection if exists
      const adminDoc = await db.collection('adminusers').doc(userId).get();
      if (adminDoc.exists && adminDoc.data().schoolId) {
        await db.collection('schools')
          .doc(adminDoc.data().schoolId)
          .collection('admins')
          .doc(userId)
          .delete();
      }
    } else if (userType === 'student') {
      await db.collection('students').doc(userId).delete();
    }

    return { 
      success: true, 
      message: `${userType} deleted successfully` 
    };

  } catch (error) {
    console.error('Error deleting user:', error);
    
    if (error.code === 'auth/user-not-found') {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }
    
    throw new functions.https.HttpsError('internal', 'Failed to delete user');
  }
});

/**
 * Secure Cloud Function to update user permissions
 * Only authorized admins can update permissions
 */
exports.updateUserPermissions = functions.https.onCall(async (data, context) => {
  try {
    // Check authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { userId, permissions } = data;

    if (!userId || !permissions) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }

    // Check if caller has permission to update permissions
    const callerDoc = await db.collection('adminusers').doc(context.auth.uid).get();
    if (!callerDoc.exists || callerDoc.data().role !== 'superAdmin') {
      throw new functions.https.HttpsError('permission-denied', 'Only super admins can update permissions');
    }

    // Update permissions in adminusers collection
    await db.collection('adminusers').doc(userId).update({
      permissions: permissions,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: context.auth.uid,
    });

    // Also update in school's admin collection if applicable
    const userDoc = await db.collection('adminusers').doc(userId).get();
    if (userDoc.exists && userDoc.data().schoolId) {
      await db.collection('schools')
        .doc(userDoc.data().schoolId)
        .collection('admins')
        .doc(userId)
        .update({
          permissions: permissions,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }

    return { 
      success: true, 
      message: 'Permissions updated successfully' 
    };

  } catch (error) {
    console.error('Error updating permissions:', error);
    throw new functions.https.HttpsError('internal', 'Failed to update permissions');
  }
});

/**
 * Secure Cloud Function to create a new school
 * Only super admins can create schools
 */
exports.createSchool = functions.https.onCall(async (data, context) => {
  try {
    // Check authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    // Check super admin permissions
    const userDoc = await db.collection('adminusers').doc(context.auth.uid).get();
    if (!userDoc.exists || userDoc.data().role !== 'superAdmin') {
      throw new functions.https.HttpsError('permission-denied', 'Only super admins can create schools');
    }

    const { 
      schoolName, 
      email, 
      phoneNumber, 
      address, 
      packageType,
      adminEmail,
      adminPassword,
      permissions 
    } = data;

    // Validate required fields
    if (!schoolName || !email || !phoneNumber || !address) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required school information');
    }

    // Create school document
    const schoolRef = await db.collection('schools').add({
      school_name: schoolName,
      email: email,
      phone_number: phoneNumber,
      address: address,
      package_type: packageType || 'Basic',
      permissions: permissions || {
        busManagement: true,
        driverManagement: true,
        routeManagement: true,
        viewingBusStatus: true,
        studentManagement: true,
        paymentManagement: true,
        notifications: true,
        adminManagement: true,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: context.auth.uid,
      isActive: true,
    });

    let adminUserId = null;

    // Create school admin if credentials provided
    if (adminEmail && adminPassword) {
      const adminUser = await admin.auth().createUser({
        email: adminEmail,
        password: adminPassword,
        displayName: `${schoolName} Admin`,
      });

      adminUserId = adminUser.uid;

      // Create admin user document
      await db.collection('adminusers').doc(adminUser.uid).set({
        role: 'schoolAdmin',
        schoolId: schoolRef.id,
        email: adminEmail,
        adminName: `${schoolName} Admin`,
        permissions: permissions,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: context.auth.uid,
      });
    }

    return { 
      success: true, 
      schoolId: schoolRef.id,
      adminUserId: adminUserId,
      message: 'School created successfully' 
    };

  } catch (error) {
    console.error('Error creating school:', error);
    throw new functions.https.HttpsError('internal', 'Failed to create school');
  }
});

/**
 * Secure Cloud Function to send notifications
 * Only authorized admins can send notifications
 */
exports.sendNotification = functions.https.onCall(async (data, context) => {
  try {
    // Check authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    // Check admin permissions
    const callerDoc = await db.collection('adminusers').doc(context.auth.uid).get();
    if (!callerDoc.exists) {
      throw new functions.https.HttpsError('permission-denied', 'User not authorized to send notifications');
    }

    const { title, message, recipientGroups, schoolIds } = data;

    if (!title || !message || !recipientGroups) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required notification data');
    }

    // Create notification document
    const notificationRef = await db.collection('notifications').add({
      title: title,
      message: message,
      recipientGroups: recipientGroups,
      schoolIds: schoolIds || [],
      sentBy: context.auth.uid,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'sent',
    });

    // Here you would implement the actual notification sending logic
    // This is a simplified version - in production, you'd send to FCM tokens

    return { 
      success: true, 
      notificationId: notificationRef.id,
      message: 'Notification sent successfully' 
    };

  } catch (error) {
    console.error('Error sending notification:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send notification');
  }
});