import { onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import * as functions from 'firebase-functions';
import corsLib from 'cors';
import axios from 'axios';
import { Request, Response } from 'express';

// Initialize CORS middleware to allow cross-origin requests
const cors = corsLib({ origin: true });

// API key constant - you can also use functions config
const API_KEY = "AIzaSyC6nOzZg5KtgsY1xEsorgSIn7gqSbjkE5I";

/**
 * Proxy for Google Places Autocomplete
 */
export const autocomplete = functions.https.onRequest(
  (req: Request, res: Response) => {
    cors(req, res, async () => {
      const input = req.query.input as string | undefined;
      const session = req.query.sessiontoken as string | undefined;

      if (!API_KEY) {
        logger.error("API key not configured");
        return res
          .status(500)
          .json({ error: 'API key not configured in functions config.' });
      }
      
      if (!input) {
        logger.warn("Missing input parameter");
        return res
          .status(400)
          .json({ error: 'Missing required query parameter: input.' });
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
        return res.status(200).json(response.data);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.toString() : String(err);
        logger.error(`Autocomplete error: ${errorMessage}`, { error: err });
        return res.status(500).json({ error: errorMessage });
      }
    });
  }
);

/**
 * Proxy for Google Geocoding (by Place ID)
 */
export const geocode = functions.https.onRequest(
  (req: Request, res: Response) => {
    cors(req, res, async () => {
      const placeId = req.query.place_id as string | undefined;
      
      if (!API_KEY) {
        logger.error("API key not configured");
        return res
          .status(500)
          .json({ status: 'ERROR', error: 'API key not configured in functions config.' });
      }
      
      if (!placeId) {
        logger.warn("Missing place_id parameter");
        return res
          .status(400)
          .json({ status: 'ERROR', error: 'Missing required query parameter: place_id.' });
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
        return res.status(200).json(response.data);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : "An unknown error occurred";
        logger.error(`Geocode error: ${errorMessage}`, { error: err });
        return res.status(500).json({ 
          status: 'ERROR',
          error_message: errorMessage 
        });
      }
    });
  }
);

// Initialize Firebase Admin SDK if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

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
    const { email, password, role, schoolId, permissions } = req.body;
    if (!email || !password || !role) {
      logger.error("Missing required fields", { email, password, role });
      res.status(400).send("Missing required fields: email, password, or role");
      return;
    }
    
    // For admin manager roles, both schoolId and permissions are required.
    if (
      (role === "schoolAdmin" || role === "regionalAdmin" || role === "schoolSuperAdmin")
    ) {
      if (!schoolId) {
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
        await admin.auth().getUser(schoolId);
        userExists = true;
      } catch (err: any) {
        if (err.code !== 'auth/user-not-found') {
          throw err;
        }
      }
      if (!userExists) {
        await admin.auth().createUser({ uid: schoolId, email, password });
      }
      docId = schoolId;
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

    if (schoolId) {
      userData.schoolId = schoolId; // Add schoolId if provided
    }
    
    // For admin manager roles, assign the client-provided permissions.
    if (
      role === "schoolAdmin" ||
      role === "schoolSuperAdmin" ||
      role === "regionalAdmin"
    ) {
      userData.permissions = permissions;
    }

    await admin.firestore().collection("adminusers").doc(docId).set(userData);

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
