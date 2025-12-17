/**
 * Quick script to set custom claims for superior admin
 * Run this once to fix permission issues
 * 
 * Usage:
 * 1. Open browser console on the web app
 * 2. Paste this code
 * 3. Run: await setClaimsForCurrentUser()
 */

async function setClaimsForCurrentUser() {
  console.log('🔐 Setting custom claims for current user...');
  
  try {
    const user = firebase.auth().currentUser;
    
    if (!user) {
      console.error('❌ No user logged in');
      return;
    }
    
    console.log(`👤 Current user: ${user.email} (${user.uid})`);
    
    // Call the setUserClaims Cloud Function
    const setUserClaims = firebase.functions().httpsCallable('setUserClaims');
    const result = await setUserClaims({ uid: user.uid });
    
    console.log('✅ Cloud Function response:', result.data);
    
    // Force token refresh
    const newToken = await user.getIdToken(true);
    console.log('🔄 Token refreshed');
    
    // Verify new claims
    const tokenResult = await user.getIdTokenResult();
    console.log('🔍 New custom claims:', tokenResult.claims);
    
    if (tokenResult.claims.role) {
      console.log('✅ SUCCESS! Custom claims are now set.');
      console.log('   - Role:', tokenResult.claims.role);
      console.log('   - School ID:', tokenResult.claims.schoolId || 'N/A');
      console.log('');
      console.log('👉 Please reload the page to apply changes: location.reload()');
    } else {
      console.error('❌ Claims were not set properly. Please check Cloud Functions logs.');
    }
    
  } catch (error) {
    console.error('❌ Error setting claims:', error);
    console.error('   Code:', error.code);
    console.error('   Message:', error.message);
  }
}

// Auto-run for convenience
console.log('📋 Function loaded. Run: await setClaimsForCurrentUser()');
console.log('Or just run it automatically now...');
setClaimsForCurrentUser();
