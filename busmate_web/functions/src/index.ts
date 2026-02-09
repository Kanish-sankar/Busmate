import { onRequest, onCall, HttpsError, Request } from "firebase-functions/v2/https";
import { defineSecret, defineString } from "firebase-functions/params";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import axios from 'axios';

// Initialize Firebase Admin SDK once
if (!admin.apps.length) {
  admin.initializeApp();
}

// Secure API key management using environment variables (v2 compatible)
const API_KEY = process.env.GOOGLE_MAPS_API_KEY;
const OLA_MAPS_API_KEY = defineSecret("OLA_MAPS_API_KEY");
const ENABLE_DEBUG_ENDPOINTS = defineString("ENABLE_DEBUG_ENDPOINTS");

function extractBearerToken(req: Request): string | null {
  const authHeader = req.headers["authorization"] as string | undefined;
  if (!authHeader) return null;
  const parts = authHeader.split(" ");
  if (parts.length === 2 && parts[0].toLowerCase() === "bearer") return parts[1];
  return null;
}

async function requireFirebaseAuth(req: Request) {
  const token = extractBearerToken(req);
  if (!token) {
    throw new Error("Missing Authorization Bearer token");
  }
  return admin.auth().verifyIdToken(token);
}

async function getCallerProfile(uid: string): Promise<{ role?: string; schoolId?: string }> {
  const db = admin.firestore();

  const adminsDoc = await db.collection("admins").doc(uid).get();
  if (adminsDoc.exists) {
    const data = adminsDoc.data() as any;
    return { role: data?.role, schoolId: data?.schoolId };
  }

  const adminUsersDoc = await db.collection("adminusers").doc(uid).get();
  if (adminUsersDoc.exists) {
    const data = adminUsersDoc.data() as any;
    return { role: data?.role, schoolId: data?.schoolId };
  }

  return {};
}


export const autocomplete = onRequest(
  { cors: true },
  async (req, res) => {
    const input = req.query.input as string | undefined;
    const session = req.query.sessiontoken as string | undefined;

    if (!API_KEY) {
      logger.error("API key not configured");
      res.status(500).json({ error: 'API key not configured in functions config.' });
      return;
    }
    
    if (!input) {
      logger.warn("Missing input parameter");
      res.status(400).json({ error: 'Missing required query parameter: input.' });
      return;
    }

    try {
      logger.info(`Autocomplete request for: ${input}`);
      const response = await axios.get(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json',
        {
          params: {
            input,
            key: API_KEY,
            components: 'country:in',
            sessiontoken: session,
          },
        }
      );
      
      logger.info(`Autocomplete response status: ${response.data.status}`);
      res.status(200).json(response.data);
    } catch (err) {
      const errorMessage = err instanceof Error ? err.toString() : String(err);
      logger.error(`Autocomplete error: ${errorMessage}`, { error: err });
      res.status(500).json({ error: errorMessage });
    }
  }
);

/**
 * Proxy for Google Geocoding (by Place ID)
 */
export const geocode = onRequest(
  { cors: true },
  async (req, res) => {
    const placeId = req.query.place_id as string | undefined;
    
    if (!API_KEY) {
      logger.error("API key not configured");
      res.status(500).json({ status: 'ERROR', error: 'API key not configured in functions config.' });
      return;
    }
    
    if (!placeId) {
      logger.warn("Missing place_id parameter");
      res.status(400).json({ status: 'ERROR', error: 'Missing required query parameter: place_id.' });
      return;
    }

    try {
      logger.info(`Geocode request for place_id: ${placeId}`);
      const response = await axios.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        {
          params: {
            place_id: placeId,
            key: API_KEY,
          },
        }
      );
      
      // Log response for debugging
      logger.info(`Geocode response status: ${response.data.status}`);
      
      if (response.data.status !== 'OK') {
        logger.warn(`Geocode API returned non-OK status: ${response.data.status}`, 
          { response: response.data });
      }
      
      // Make sure we return exactly what the client expects
      res.status(200).json(response.data);
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : "An unknown error occurred";
      logger.error(`Geocode error: ${errorMessage}`, { error: err });
      res.status(500).json({ 
        status: 'ERROR',
        error_message: errorMessage 
      });
    }
  }
);

//
// Email existence check (Auth) via callable function (v2)
//
export const checkEmailExists = onCall(async (request) => {
  const email = request.data?.email as string | undefined;

  if (!email || typeof email !== "string") {
    throw new HttpsError("invalid-argument", "Missing required field: email");
  }

  try {
    await admin.auth().getUserByEmail(email);
    logger.info("Email exists in Auth", { email });
    return { exists: true };
  } catch (err: any) {
    if (err?.code === "auth/user-not-found") {
      logger.info("Email does not exist in Auth", { email });
      return { exists: false };
    }

    // For any other error, log it but return false (optimistic - allow the email)
    // The actual account creation will catch duplicates anyway
    logger.warn("checkEmailExists encountered error, returning false (optimistic)", { error: err, email, code: err?.code });
    return { exists: false };
  }
});

export const createSchoolUser = onRequest(async (req, res): Promise<void> => {
  // Log the incoming request
  logger.info("createSchoolUser function invoked", {
    method: req.method,
    body: req.body,
  });

  // Handle CORS preflight request
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
    res.status(204).send("");
    return;
  }

  // Set CORS headers for the actual request
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");

  try {
    const decoded = await requireFirebaseAuth(req);
    const callerProfile = await getCallerProfile(decoded.uid);
    const callerRole = (decoded as any)?.role || callerProfile.role;
    const callerSchoolId = (decoded as any)?.schoolId || callerProfile.schoolId;

    if (!callerRole) {
      res.status(403).send({ error: "Forbidden" });
      return;
    }

    const { email, password, role, schoolId, permissions, adminName, adminID } = req.body;
    if (!email || !password || !role) {
      logger.error("Missing required fields", { email, password, role });
      res.status(400).send("Missing required fields: email, password, or role");
      return;
    }

    // Role-based authorization to prevent public abuse while preserving current flows.
    // - schoolAdmin can create only driver/student under their own school
    // - privileged roles can create all roles
    const privilegedRoles = new Set(["superior", "schoolSuperAdmin", "regionalAdmin"]);
    const allowedBySchoolAdmin = new Set(["driver", "student"]);

    const isPrivileged = privilegedRoles.has(String(callerRole));
    if (!isPrivileged) {
      if (callerRole !== "schoolAdmin" || !allowedBySchoolAdmin.has(String(role))) {
        res.status(403).send({ error: "Forbidden" });
        return;
      }
    }

    // If school admin is creating driver/student, enforce/derive schoolId from caller.
    let resolvedSchoolId: string | undefined = schoolId;
    if (!isPrivileged && callerRole === "schoolAdmin") {
      if (!callerSchoolId) {
        res.status(403).send({ error: "Forbidden" });
        return;
      }
      resolvedSchoolId = callerSchoolId;
    }
    
    // For admin manager roles, both schoolId and permissions are required.
    if (
      (role === "schoolAdmin" || role === "regionalAdmin" || role === "schoolSuperAdmin")
    ) {
      if (!resolvedSchoolId) {
        logger.error("Missing schoolId for admin manager", { email, role });
        res.status(400).send("Missing required field: schoolId");
        return;
      }
      if (!permissions) {
        logger.error("Missing permissions for admin manager", { email, role });
        res.status(400).send("Missing required field: permissions");
        return;
      }
    }

    // Create the user with Firebase Admin SDK
    let docId: string;
    if (role === "schoolAdmin") {
      // Only schoolSuperAdmin gets schoolId as UID
      // Check if user with this UID already exists
      let userExists = false;
      try {
        await admin.auth().getUser(resolvedSchoolId!);
        userExists = true;
      } catch (err: any) {
        if (err.code !== 'auth/user-not-found') {
          throw err;
        }
      }
      if (!userExists) {
        await admin.auth().createUser({ uid: resolvedSchoolId!, email, password });
      }
      docId = resolvedSchoolId!;
    } else if (role === "regionalAdmin" || role === "schoolSuperAdmin") {
      // regionalAdmin gets a unique UID
      const userRecord = await admin.auth().createUser({ email, password });
      docId = userRecord.uid;
    } else {
      // Other roles (driver, student)
      const userRecord = await admin.auth().createUser({ email, password });
      docId = userRecord.uid;
    }

    // Prepare the user data to be stored in Firestore.
    const userData: any = {
      email,
      role,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (resolvedSchoolId) {
      userData.schoolId = resolvedSchoolId; // Add schoolId if provided/derived
    }
    
    // Add admin name and ID if provided (for Regional Admins)
    if (adminName) {
      userData.adminName = adminName;
    }
    if (adminID) {
      userData.adminID = adminID;
    }
    
    // For admin manager roles, assign the client-provided permissions.
    if (
      role === "schoolAdmin" ||
      role === "schoolSuperAdmin" ||
      role === "regionalAdmin"
    ) {
      userData.permissions = permissions;
    }

    // Save to appropriate collection based on role
    // Regional and School Admins go to 'admins' collection (used by web auth)
    // Drivers and students go to 'adminusers' collection (used by mobile app)
    const collectionName = (role === "regionalAdmin" || role === "schoolAdmin" || role === "schoolSuperAdmin") 
      ? "admins" 
      : "adminusers";
    
    await admin.firestore().collection(collectionName).doc(docId).set(userData);

    logger.info(`User created successfully: ${docId}`);
    res.status(200).send({ message: "User created successfully", uid: docId });
    return;
  } catch (error) {
    logger.error("Error creating user:", { error });
    const errorMessage = error instanceof Error ? error.message : "An unknown error occurred";
    res.status(500).send({ error: errorMessage });
    return;
  }
});

/**
 * Migrate regional admins from 'adminusers' collection to 'admins' collection
 * Call this once to migrate old data
 */
export const migrateRegionalAdmins = onRequest(async (req, res): Promise<void> => {
  if (ENABLE_DEBUG_ENDPOINTS.value() !== "true") {
    res.status(404).send({ error: "Not Found" });
    return;
  }

  // Set CORS headers
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");

  try {
    const decoded = await requireFirebaseAuth(req);
    const callerProfile = await getCallerProfile(decoded.uid);
    const callerRole = (decoded as any)?.role || callerProfile.role;
    if (callerRole !== "superior") {
      res.status(403).send({ error: "Forbidden" });
      return;
    }

    logger.info("Starting migration of regional admins from adminusers to admins");

    const db = admin.firestore();
    
    // Get all users from adminusers collection where role is 'regionalAdmin'
    const adminUsersSnapshot = await db
      .collection('adminusers')
      .where('role', '==', 'regionalAdmin')
      .get();

    let migratedCount = 0;
    const migratedIds: string[] = [];

    // Migrate each regional admin to admins collection
    for (const doc of adminUsersSnapshot.docs) {
      const data = doc.data();
      const userId = doc.id;

      try {
        // Copy to admins collection
        await db.collection('admins').doc(userId).set({
          email: data.email,
          role: 'regionalAdmin',
          schoolId: data.schoolId,
          permissions: data.permissions || {},
          adminName: data.adminName,
          adminId: data.adminID || userId,
          createdAt: data.createdAt || admin.firestore.FieldValue.serverTimestamp(),
          migratedFrom: 'adminusers',
          migratedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        migratedCount++;
        migratedIds.push(userId);
        logger.info(`Migrated regional admin: ${userId}`);
      } catch (error) {
        logger.error(`Failed to migrate regional admin ${userId}:`, error);
      }
    }

    res.status(200).send({
      success: true,
      message: `Successfully migrated ${migratedCount} regional admins`,
      migratedIds: migratedIds,
    });
  } catch (error) {
    logger.error("Error during migration:", error);
    const errorMessage = error instanceof Error ? error.message : "An unknown error occurred";
    res.status(500).send({ error: errorMessage });
  }
});

/**
 * Ola Maps Distance Matrix API Proxy
 * Proxies requests to Ola Maps API to avoid CORS issues in web browser
 * Keeps API key secure on server-side
 */
export const olaDistanceMatrix = onRequest(
  { cors: true, secrets: [OLA_MAPS_API_KEY] },
  async (req, res) => {
    // Only allow POST requests
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed. Use POST.' });
      return;
    }

    try {
      await requireFirebaseAuth(req);
    } catch (e) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const { origins, destinations, mode } = req.body;
    const olaKey = OLA_MAPS_API_KEY.value();

    if (!olaKey) {
      logger.error("Ola Maps API key not configured");
      res.status(500).json({ error: 'Ola Maps API key not configured.' });
      return;
    }

    if (!origins || !destinations) {
      logger.warn("Missing required parameters");
      res.status(400).json({
        error: 'Missing required parameters: origins and destinations are required.'
      });
      return;
    }

    try {
      logger.info(`Ola Maps Distance Matrix request: ${origins.length} origins, ${destinations.length} destinations`);

      const response = await axios.post(
        'https://api.olamaps.io/routing/v1/distanceMatrix',
        {
          origins,
          destinations,
          mode: mode || 'driving'
        },
        {
          headers: {
            'Authorization': `Bearer ${olaKey}`,
            'Content-Type': 'application/json',
            'X-Request-Id': Date.now().toString()
          },
          timeout: 10000 // 10 second timeout
        }
      );

      logger.info("Ola Maps API call successful");
      res.status(200).json(response.data);
    } catch (error: any) {
      logger.error("Ola Maps API error:", error.response?.data || error.message);

      if (error.response) {
        res.status(error.response.status).json({
          error: error.response.data?.message || 'Ola Maps API error',
          details: error.response.data
        });
      } else if (error.code === 'ECONNABORTED') {
        res.status(504).json({ error: 'Request timeout' });
      } else {
        res.status(500).json({
          error: 'Failed to connect to Ola Maps API',
          message: error.message
        });
      }
    }
  }
);
