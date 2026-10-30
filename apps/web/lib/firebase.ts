"use client";

import { getApp, getApps, initializeApp, setLogLevel } from "firebase/app";
import { getFirestore, enableIndexedDbPersistence } from "firebase/firestore";
import { getAuth } from "firebase/auth";
import { getStorage } from "firebase/storage";

import { getFirebaseApiKey } from "./keyRotation";

// Suppress internal Firebase SDK verbose connection errors
setLogLevel("warn");

const firebaseConfig = {
    apiKey: getFirebaseApiKey() || "AIzaSyAyF7MrKxdseKsh-Zux19Qbrrp3sz0Uymg",
    authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN || "eduboard-6fdcc.firebaseapp.com",
    projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || "eduboard-6fdcc",
    storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET || "eduboard-6fdcc.firebasestorage.app",
    messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID || "490296361729",
    appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID || "1:490296361729:web:071ea659c1d4a99d199100",
};

const app = getApps().length ? getApp() : initializeApp(firebaseConfig);

export const auth = getAuth(app);
export const db = getFirestore(app);

// Enable IndexedDB offline persistence for client-side environments safely
if (typeof window !== "undefined") {
    enableIndexedDbPersistence(db).catch((err) => {
        if (err.code === "failed-precondition") {
            console.warn("[Firestore Persistence Warning]: Multiple tabs open. Offline persistence active in primary tab.");
        } else if (err.code === "unimplemented") {
            console.warn("[Firestore Persistence Warning]: IndexedDB is unsupported in this browser environment.");
        } else {
            console.warn("[Firestore Persistence Initialization Notice]:", err.message);
        }
    });
}

// Filter internal @firebase/firestore 10-second offline notices from breaking Next.js dev overlay
if (typeof window !== "undefined") {
    const origError = console.error;
    console.error = (...args: any[]) => {
        const fullMsg = args.map(a => (typeof a === "object" ? JSON.stringify(a) : String(a))).join(" ");
        if (fullMsg.includes("Could not reach Cloud Firestore backend") || fullMsg.includes("Backend didn't respond within 10 seconds")) {
            console.warn("[Firestore Persistence Notice]: Client operating in offline cache mode.");
            return;
        }
        origError.apply(console, args);
    };
}

export const storage = getStorage(app);
export default app;
