# 🔍 FIREBASE CLOUD RUN FUNCTIONS - COST SPIKE INVESTIGATION

## 📊 Current Situation
- **Charge:** 2,688 Rs (87% of 3,087 Rs total cost)
- **Service:** Cloud Run Functions (not Firestore)
- **Trigger:** Spike occurred after dev Firebase deployment
- **Timeline:** 10-day period

---

## 🚨 Possible Root Causes

### **1. ⚠️ Function Runtime Loop (HIGH PRIORITY)**
Some functions might be running in infinite loops or very long-running processes.

**Check:**
```bash
# View recent function execution logs
firebase functions:log --limit 50
```

**Look for:**
- Functions taking >30 seconds to complete
- "Timeout" or "Exceeded execution time" errors
- Logs showing recursive or repeated calls within same invocation

---

### **2. ⚠️ Excessive Function Invocations (HIGH PRIORITY)**
Functions might be called millions of times in a short period.

**Check:**
```bash
# Check Cloud Monitoring for invocation counts
gcloud functions list --project=busmate-b80e8
gcloud functions describe migrateRegionalAdmins --project=busmate-b80e8 --gen2
```

**Look for:**
- Invocation count spikes in the functions dashboard
- Functions called more than normal patterns

---

### **3. ⚠️ High Memory Allocation (MEDIUM PRIORITY)**
Functions might be allocated with high memory causing higher CPU costs.

**Check firebase.json:**
```bash
cat busmate_web/firebase.json | grep -A 5 "functions"
```

**Look for:**
- Memory allocation > 512MB (default is 256MB)
- CPU allocation higher than needed

---

### **4. ⚠️ Individual Writes Instead of Batch (MEDIUM PRIORITY)**
**FOUND:** `migrateRegionalAdmins` function uses individual writes in a loop

```typescript
// ❌ PROBLEMATIC - Each write = 1 operation
for (const doc of adminUsersSnapshot.docs) {
  await db.collection('admins').doc(userId).set({...});  
}
```

**If 1000 admins exist:** 1000 individual writes = 1000 operations

---

### **5. ⚠️ Debugging Endpoints Left Enabled (LOW PRIORITY)**
Functions have debug endpoints that might be running.

**Check index.ts line 343:**
```typescript
if (ENABLE_DEBUG_ENDPOINTS.value() !== "true") {
  res.status(404).send({ error: "Not Found" });
  return;
}
```

**If DEBUG mode is enabled in production, `migrateRegionalAdmins` would be exposed to accidental/malicious repeated calls.**

---

## 🔧 Immediate Steps to Diagnose

### Step 1: Check Function Logs
```bash
cd busmate_web
firebase functions:log --limit 100 --project=busmate-b80e8
```

**What to look for:**
- Timestamp of cost spike
- Which function(s) were running
- Error messages or timeouts
- Repeated execution patterns

### Step 2: Check Firebase Console
1. Go to https://console.firebase.google.com
2. Select **busmate-b80e8** project
3. Navigate to **Functions** > **Logs**
4. Filter by date range where spike occurred
5. Look for:
   - Functions with status "ERROR"
   - Functions taking >10 seconds
   - High invocation counts

### Step 3: Check Function Memory Configuration
```bash
firebase deploy --only functions --dry-run
```

Look at memory settings for each function.

### Step 4: Check Cloud Monitoring
1. https://console.cloud.google.com/monitoring
2. Select project: **busmate-b80e8**
3. Metrics > **Cloud Functions**
4. View:
   - Invocation count over time
   - Execution time trends
   - Error rate

---

## 🛠️ Common Fixes

### **Fix 1: Disable Debug Endpoints**
**File:** [busmate_web/functions/src/index.ts](busmate_web/functions/src/index.ts#L343)

```typescript
// Change from:
if (ENABLE_DEBUG_ENDPOINTS.value() !== "true") {

// To always disabled for production:
if (true) {  // Always deny debug endpoints
  res.status(404).send({ error: "Not Found" });
  return;
}
```

Or remove the function entirely if not needed in production.

### **Fix 2: Batch Writes in migrateRegionalAdmins**
**File:** [busmate_web/functions/src/index.ts](busmate_web/functions/src/index.ts#L367)

```typescript
// ❌ BEFORE: Individual writes
for (const doc of adminUsersSnapshot.docs) {
  await db.collection('admins').doc(userId).set({...});
}

// ✅ AFTER: Batch writes
const batch = db.batch();
for (const doc of adminUsersSnapshot.docs) {
  batch.set(db.collection('admins').doc(doc.id), {...});
}
await batch.commit();
```

### **Fix 3: Set Memory Limits**
**File:** [busmate_web/firebase.json](busmate_web/firebase.json)

```json
{
  "functions": [
    {
      "source": "functions",
      "runtime": "nodejs22",
      "codebase": "default",
      "memory": 256,  // 256MB (default)
      "cpu": 0.25,    // 0.25 vCPU
      "timeout": 60   // 60 seconds max
    }
  ]
}
```

### **Fix 4: Add Execution Timeout**
Prevent runaway functions from draining costs:

```typescript
export const myFunction = onRequest(
  { 
    cors: true,
    timeoutSeconds: 30  // Max 30 seconds
  },
  async (req, res) => {
    // ... function code ...
  }
);
```

---

## 📋 Comparison: What's Normal?

| Metric | Normal | Alert Level |
|--------|--------|------------|
| Invocations/day | <10K | >100K |
| Avg execution time | <2s | >30s |
| Error rate | <1% | >5% |
| Memory used | <150MB | >300MB |
| Daily cost | <5 Rs | >100 Rs |

**Your current:** 2,688 Rs in 10 days = 268.8 Rs/day (🔴 **53x normal**)

---

## ✅ Action Plan

1. **URGENT** - Check function logs for last 10 days to identify spike moment
2. **URGENT** - Identify which function(s) caused the spike
3. **HIGH** - Disable or restrict debug endpoints if exposed
4. **HIGH** - Fix migrateRegionalAdmins batch write issue
5. **MEDIUM** - Redeploy functions with fixes
6. **MEDIUM** - Monitor for next 2-3 days to verify cost reduction
7. **LOW** - Set up billing alert at 500 Rs threshold

---

## ❓ Questions to Answer

1. **When exactly did deployment happen?** (to correlate with cost spike timestamp)
2. **Which functions were deployed?** (all of them or specific ones?)
3. **To which project?** (busmate-b80e8 or busmate-dev or both?)
4. **Did anyone call `migrateRegionalAdmins` endpoint manually?**
5. **Are there any error logs showing function failures/retries?**

---

**Next Step:** Run Firebase functions logs command and share the output to identify root cause.
