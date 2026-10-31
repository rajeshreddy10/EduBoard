'use client';

import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { User, UserRole } from '@/lib/types';
import { api } from '@/lib/api';
import { auth, db } from '@/lib/firebase';
import {
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut,
  onAuthStateChanged,
  GoogleAuthProvider,
  signInWithPopup,
  signInWithRedirect,
  getRedirectResult,
  sendPasswordResetEmail,
  updatePassword as firebaseUpdatePassword,
  updateProfile as firebaseUpdateProfile,
  User as FirebaseUser
} from 'firebase/auth';
import { doc, getDoc, getDocs, setDoc, collection, query, where, serverTimestamp } from 'firebase/firestore';
import * as store from '@/lib/store';

interface AuthContextType {
  user: User | null;
  loading: boolean;
  error: string | null;
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<User>;
  loginWithGoogle: () => Promise<void>;
  signup: (email: string, password: string, name: string, confirmPassword: string, role?: UserRole) => Promise<void>;
  logout: () => Promise<void>;
  resetPassword: (email: string) => Promise<void>;
  updateUserPassword: (password: string) => Promise<void>;
  updateUserProfile: (updates: Partial<User>) => Promise<void>;
  clearError: () => void;
}

export function getCanonicalUserId(email: string, firebaseUid?: string): string {
  if (firebaseUid) return firebaseUid;
  if (auth.currentUser?.uid) return auth.currentUser.uid;
  return 'guest';
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Map Firebase User to App User using Firebase Auth UID as primary key
  const mapUser = async (firebaseUser: FirebaseUser | null): Promise<User | null> => {
    if (!firebaseUser) return null;
    const email = firebaseUser.email || '';
    const uid = firebaseUser.uid;

    console.log(`[Firebase Diagnostic] [Web] Project ID: eduboard-6fdcc | Auth UID: ${uid} | Email: ${email} | Firestore Document Path: /users/${uid}`);

    let userData: any = null;
    try {
      const authDocSnap = await getDoc(doc(db, 'users', uid));
      const legacyId = email && email.includes('@') ? `usr_${email.toLowerCase().trim().replace(/[^a-z0-9]/g, '_')}` : '';
      let legacyData: any = null;
      if (legacyId && legacyId !== uid) {
        const legacySnap = await getDoc(doc(db, 'users', legacyId));
        if (legacySnap.exists()) legacyData = legacySnap.data();
      }

      // Also query by email if neither authDocSnap nor legacySnap was found
      let emailQueryData: any = null;
      if (!authDocSnap.exists() && !legacyData && email) {
        try {
          const q = query(collection(db, 'users'), where('email', '==', email.toLowerCase().trim()));
          const emailSnap = await getDocs(q);
          if (!emailSnap.empty) {
            emailQueryData = emailSnap.docs[0].data();
          }
        } catch (e) {
          console.warn('[Firebase Auth] email query note:', e);
        }
      }

      const authData = authDocSnap.exists() ? authDocSnap.data() : null;
      userData = { ...emailQueryData, ...legacyData, ...authData };

      const name = userData?.full_name || userData?.name || firebaseUser.displayName || email.split('@')[0] || 'EduBoard User';
      const mergedPayload = {
        name,
        full_name: name,
        email,
        address: userData?.address || '',
        organization: userData?.organization || userData?.institution || '',
        institution: userData?.organization || userData?.institution || '',
        phone: userData?.phone || userData?.phoneNumber || userData?.phone_number || '',
        location: userData?.location || '',
        bio: userData?.bio || '',
        role: userData?.role || 'teacher',
        username: userData?.username || email.split('@')[0] || 'user',
        avatar: userData?.avatar || userData?.avatarUrl || firebaseUser.photoURL || '',
        updatedAt: serverTimestamp(),
        updated_at: new Date().toISOString(),
      };

      await setDoc(doc(db, 'users', uid), mergedPayload, { merge: true });
      console.log(`[Firebase Diagnostic] [Web] Firestore Document Path: /users/${uid} Data:`, mergedPayload);
    } catch (err) {
      console.warn("[Firebase Diagnostic] [Web] Firestore user fetch/sync note:", err);
    }

    const name = userData?.full_name || userData?.name || firebaseUser.displayName || email.split('@')[0] || 'EduBoard User';
    const mapped: User = {
      id: uid,
      email: email,
      name: name,
      address: userData?.address || '',
      organization: userData?.organization || userData?.institution || '',
      institution: userData?.organization || userData?.institution || '',
      phone: userData?.phone || userData?.phoneNumber || userData?.phone_number || '',
      location: userData?.location || '',
      bio: userData?.bio || '',
      role: userData?.role || 'teacher',
      username: userData?.username || email.split('@')[0] || 'user',
      avatar: userData?.avatar || userData?.avatarUrl || firebaseUser.photoURL || '',
      isVerified: firebaseUser.emailVerified,
      isBiometricEnabled: userData?.isBiometricEnabled || false,
      createdAt: userData?.createdAt?.toDate?.()?.toISOString() || userData?.createdAt || new Date().toISOString(),
      lastLoginAt: new Date().toISOString(),
    };
    store.setUser(mapped);
    return mapped;
  };

  useEffect(() => {
    // Handle OAuth redirect result if redirect sign-in was triggered
    getRedirectResult(auth).then(async (result) => {
      if (result?.user) {
        console.log('[Firebase Auth] Google redirect login successful for UID:', result.user.uid);
        const email = result.user.email || '';
        const canonicalId = getCanonicalUserId(email, result.user.uid);
        try {
          const userRef = doc(db, 'users', canonicalId);
          const userDoc = await getDoc(userRef);
          if (!userDoc.exists()) {
            await setDoc(userRef, {
              name: result.user.displayName || email.split('@')[0],
              full_name: result.user.displayName || email.split('@')[0],
              email: email,
              role: 'teacher',
              createdAt: serverTimestamp(),
              lastLoginAt: serverTimestamp(),
            });
          }
        } catch (firestoreErr) {
          console.warn("[Firebase Firestore] Redirect user doc write note:", firestoreErr);
        }
      }
    }).catch((err) => {
      console.warn('[Firebase Auth] Redirect result notice:', err.message);
    });

    const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
      setLoading(true);
      try {
        console.log('[Firebase Auth] Auth state changed:', firebaseUser ? `User ${firebaseUser.email} (${firebaseUser.uid})` : 'Unauthenticated');
        const mappedUser = await mapUser(firebaseUser);
        setUser(mappedUser);
      } catch (err) {
        console.error("[Firebase Auth] Auth mapping error:", err);
      } finally {
        setLoading(false);
      }
    });

    return () => unsubscribe();
  }, []);

  // Real-time Firestore profile subscription for instant cross-platform sync
  useEffect(() => {
    if (!user?.id) return;
    let unsubProfile: (() => void) | null = null;
    import('@/lib/services/firebaseData').then(({ userProfileService }) => {
      unsubProfile = userProfileService.subscribeToProfile(user.id, (liveProfile) => {
        if (liveProfile) {
          setUser(prev => prev ? { ...prev, ...liveProfile } : liveProfile);
          store.setUser({ ...user, ...liveProfile });
        }
      });
    }).catch(console.warn);

    return () => {
      if (unsubProfile) unsubProfile();
    };
  }, [user?.id]);

  const login = async (email: string, password: string) => {
    try {
      setError(null);
      const normalizedEmail = email.toLowerCase().trim();
      console.log('[Firebase Auth] Initiating login for account:', normalizedEmail);

      let firebaseUser: FirebaseUser | null = null;
      try {
        const res = await signInWithEmailAndPassword(auth, normalizedEmail, password);
        firebaseUser = res.user;
        console.log('[Firebase Auth] Firebase login successful for Auth UID:', firebaseUser.uid);
      } catch (fbErr: any) {
        console.warn('[Firebase Auth] Primary Firebase login note:', fbErr.code, fbErr.message);
        try {
          await api.login({ email: normalizedEmail, password });
        } catch (apiErr) {
          let userMsg = 'Invalid email or password. Please check your credentials.';
          if (fbErr.code === 'auth/user-not-found' || fbErr.code === 'auth/wrong-password' || fbErr.code === 'auth/invalid-credential') {
            userMsg = 'Invalid email or password. Please try again.';
          } else if (fbErr.code === 'auth/invalid-email') {
            userMsg = 'Please enter a valid email address.';
          } else if (fbErr.code === 'auth/too-many-requests') {
            userMsg = 'Access to this account has been temporarily disabled due to many failed login attempts.';
          }
          setError(userMsg);
          throw new Error(userMsg);
        }
      }

      const uid = firebaseUser?.uid || auth.currentUser?.uid;
      if (!uid) {
        const canonicalId = `usr_${normalizedEmail.replace(/[^a-z0-9]/g, '_')}`;
        console.warn('[Firebase Auth] Auth UID not available yet, using canonical ID:', canonicalId);
      }

      const activeUid = uid || `usr_${normalizedEmail.replace(/[^a-z0-9]/g, '_')}`;

      // Fetch or sync Firestore user profile record using Auth UID
      let firestoreProfile: any = null;
      try {
        const userRef = doc(db, 'users', activeUid);
        const userSnap = await getDoc(userRef);
        if (userSnap.exists()) {
          firestoreProfile = userSnap.data();
        } else {
          // Check query by email fallback
          const emailQuery = query(collection(db, 'users'), where('email', '==', normalizedEmail));
          const emailSnap = await getDocs(emailQuery);
          if (!emailSnap.empty) {
            firestoreProfile = emailSnap.docs[0].data();
          } else {
            firestoreProfile = {
              name: firebaseUser?.displayName || normalizedEmail.split('@')[0],
              full_name: firebaseUser?.displayName || normalizedEmail.split('@')[0],
              email: normalizedEmail,
              role: 'teacher',
              address: '',
              organization: 'EduBoard',
              institution: 'EduBoard',
              phone: '',
              location: '',
              bio: '',
              createdAt: serverTimestamp(),
              lastLoginAt: serverTimestamp(),
            };
          }
          await setDoc(userRef, firestoreProfile, { merge: true });
        }
      } catch (fsErr) {
        console.warn('[Firebase Firestore] Login profile fetch note:', fsErr);
      }

      const loggedInUser: User = {
        id: activeUid,
        email: normalizedEmail,
        name: firestoreProfile?.full_name || firestoreProfile?.name || firebaseUser?.displayName || normalizedEmail.split('@')[0] || 'EduBoard User',
        address: firestoreProfile?.address || '',
        organization: firestoreProfile?.organization || firestoreProfile?.institution || '',
        institution: firestoreProfile?.organization || firestoreProfile?.institution || '',
        phone: firestoreProfile?.phone || firestoreProfile?.phoneNumber || firestoreProfile?.phone_number || '',
        location: firestoreProfile?.location || '',
        bio: firestoreProfile?.bio || '',
        role: firestoreProfile?.role || 'teacher',
        username: firestoreProfile?.username || normalizedEmail.split('@')[0] || 'user',
        avatar: firestoreProfile?.avatar || firestoreProfile?.avatarUrl || firebaseUser?.photoURL || '',
        isVerified: firebaseUser?.emailVerified ?? true,
        isBiometricEnabled: firestoreProfile?.isBiometricEnabled || false,
        createdAt: firestoreProfile?.createdAt?.toDate?.()?.toISOString() || firestoreProfile?.createdAt || new Date().toISOString(),
        lastLoginAt: new Date().toISOString(),
      };

      store.setUser(loggedInUser);
      setUser(loggedInUser);
      return loggedInUser;
    } catch (err: any) {
      console.error('[Firebase Auth] Login error:', err.message);
      setError(err.message || 'Login failed.');
      throw err;
    }
  };

  const loginWithGoogle = async () => {
    try {
      setError(null);
      console.log('[Firebase Auth] Initiating Google OAuth sign-in...');
      const provider = new GoogleAuthProvider();
      provider.setCustomParameters({ prompt: 'select_account' });

      try {
        const result = await signInWithPopup(auth, provider);
        console.log('[Firebase Auth] Google popup login successful for UID:', result.user.uid);

        // Sync backend API session if available
        try {
          const idToken = await result.user.getIdToken();
          if (idToken) {
            await fetch('/api/auth/oauth/google', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ idToken })
            }).catch(() => {});
          }
        } catch {}

        // Ensure user document exists in Firestore using canonical ID
        try {
          const canonicalId = getCanonicalUserId(result.user.email || '', result.user.uid);
          const userRef = doc(db, 'users', canonicalId);
          const userDoc = await getDoc(userRef);

          if (!userDoc.exists()) {
            console.log('[Firebase Firestore] Creating new user profile document for Google user:', canonicalId);
            await setDoc(userRef, {
              name: result.user.displayName || result.user.email?.split('@')[0],
              full_name: result.user.displayName || result.user.email?.split('@')[0],
              email: result.user.email,
              role: 'teacher',
              createdAt: serverTimestamp(),
              lastLoginAt: serverTimestamp(),
            });
          }
        } catch (firestoreErr) {
          console.warn("[Firebase Firestore] User doc write note:", firestoreErr);
        }
      } catch (popupErr: any) {
        console.warn('[Firebase Auth] Popup OAuth attempt note:', popupErr.code, popupErr.message);
        if (
          popupErr.code === 'auth/popup-blocked' ||
          popupErr.code === 'auth/cancelled-popup-request' ||
          popupErr.code === 'auth/operation-not-supported-in-this-environment' ||
          popupErr.code === 'auth/disallowed_useragent' ||
          popupErr.code === 'auth/internal-error'
        ) {
          console.log('[Firebase Auth] Popup blocked or unsupported. Falling back to OAuth redirect mode...');
          await signInWithRedirect(auth, provider);
        } else if (popupErr.code === 'auth/popup-closed-by-user') {
          throw new Error('Google Sign-In popup was closed before completing. Please try again.');
        } else if (popupErr.code === 'auth/unauthorized-domain') {
          const domain = typeof window !== 'undefined' ? window.location.hostname : 'current domain';
          throw new Error(`Domain/IP '${domain}' is not in Firebase Console Authorized Domains. Please add '${domain}' in Firebase Console under Authentication -> Settings -> Authorized domains.`);
        } else {
          throw popupErr;
        }
      }
    } catch (err: any) {
      console.error('[Firebase Auth] Google sign-in error:', err.message);
      const message = err.message || 'Google sign-in failed.';
      setError(message);
      throw new Error(message);
    }
  };

  const signup = async (
    email: string,
    password: string,
    name: string,
    confirmPassword: string,
    role: UserRole = 'student'
  ) => {
    try {
      setError(null);
      if (password !== confirmPassword) throw new Error("Passwords do not match");
      const normalizedEmail = email.toLowerCase().trim();
      const canonicalId = getCanonicalUserId(normalizedEmail);
      console.log('[Firebase Auth] Creating user account:', normalizedEmail, 'canonicalId:', canonicalId);

      const result = await createUserWithEmailAndPassword(auth, normalizedEmail, password);
      const uid = result.user.uid;
      console.log('[Firebase Auth] User created successfully. UID:', uid);

      // Update display name in Firebase Auth
      await firebaseUpdateProfile(result.user, { displayName: name });
      console.log('[Firebase Auth] Updated display name to:', name);

      // Create user document in Firestore using the exact Firebase Auth UID
      try {
        console.log('[Firebase Firestore] Creating user profile record for UID:', uid);
        const userProfilePayload = {
          id: uid,
          uid: uid,
          name,
          full_name: name,
          email: normalizedEmail,
          role,
          createdAt: serverTimestamp(),
          lastLoginAt: serverTimestamp(),
        };
        await setDoc(doc(db, 'users', uid), userProfilePayload, { merge: true });
      } catch (firestoreErr) {
        console.warn("[Firebase Firestore] Profile creation note:", firestoreErr);
      }

      // Sync backend register to populate password_hash and shared record using the identical UID
      try {
        await api.signup({ email: normalizedEmail, password, name, confirmPassword, role, uid });
      } catch (apiErr) {
        console.warn("[Firebase Auth] Backend signup sync note:", apiErr);
      }
    } catch (err: any) {
      console.error('[Firebase Auth] Signup error:', err.message);
      setError(err.message);
      throw err;
    }
  };

  const logout = async () => {
    try {
      console.log('[Firebase Auth] Signing out user...');
      await signOut(auth);
      setUser(null);
      console.log('[Firebase Auth] User signed out successfully.');
    } catch (err: any) {
      console.error('[Firebase Auth] Logout error:', err.message);
      setError(err.message);
    }
  };

  const resetPassword = async (email: string) => {
    try {
      setError(null);
      console.log('[Firebase Auth] Sending password reset email to:', email);
      await sendPasswordResetEmail(auth, email);
      console.log('[Firebase Auth] Password reset email sent successfully.');
    } catch (err: any) {
      console.error('[Firebase Auth] Reset password error:', err.message);
      setError(err.message);
      throw err;
    }
  };

  const updateUserPassword = async (password: string) => {
    try {
      setError(null);
      if (!auth.currentUser) throw new Error("No authenticated user found.");
      console.log('[Firebase Auth/Security] Updating user password...');
      await firebaseUpdatePassword(auth.currentUser, password);
      console.log('[Firebase Auth/Security] Password updated successfully.');
    } catch (err: any) {
      console.error('[Firebase Auth/Security] Password update error:', err.message);
      setError(err.message);
      throw err;
    }
  };

  const updateUserProfile = async (updates: Partial<User>) => {
    try {
      setError(null);
      const activeUid = user?.id || auth.currentUser?.uid;
      if (auth.currentUser) {
        if (updates.name || updates.avatar) {
          console.log('[Firebase Auth] Updating Auth profile fields:', updates);
          await firebaseUpdateProfile(auth.currentUser, {
            displayName: updates.name || auth.currentUser.displayName,
            photoURL: updates.avatar || auth.currentUser.photoURL,
          });
        }
      }
      if (activeUid) {
        console.log('[Firebase Firestore] Syncing profile updates to Firestore for UID:', activeUid, updates);
        const { userProfileService } = await import('@/lib/services/firebaseData');
        await userProfileService.updateProfile(activeUid, updates);
      }
      setUser(prev => prev ? { ...prev, ...updates } : null);
    } catch (err: any) {
      console.error('[Firebase Auth] Update profile error:', err.message);
      setError(err.message);
      throw err;
    }
  };

  const clearError = () => setError(null);

  return (
    <AuthContext.Provider
      value={{
        user,
        loading,
        error,
        isAuthenticated: !!user,
        login,
        loginWithGoogle,
        signup,
        logout,
        resetPassword,
        updateUserPassword,
        updateUserProfile,
        clearError,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
}
