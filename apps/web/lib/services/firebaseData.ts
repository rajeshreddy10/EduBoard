import {
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  writeBatch,
  query,
  where,
  orderBy,
  onSnapshot,
  serverTimestamp,
  Unsubscribe
} from 'firebase/firestore';
import { ref, uploadString, getDownloadURL } from 'firebase/storage';
import { auth, db, storage } from '../firebase';
import { Board, Notification, User } from '../types';
import { api } from '../api';
import * as store from '../store';

function sanitizePayload(obj: any): any {
  if (obj === null || obj === undefined) return null;
  // Preserve Firestore FieldValue (e.g. serverTimestamp()), Timestamps, and Dates intact
  if (
    typeof obj === 'object' &&
    (obj.constructor?.name === 'FieldValue' ||
      obj.constructor?.name === 'Timestamp' ||
      obj.constructor?.name === 'ServerTimestampFieldValueImpl' ||
      obj instanceof Date ||
      obj._methodName)
  ) {
    return obj;
  }
  if (Array.isArray(obj)) {
    return obj.map(sanitizePayload);
  }
  if (typeof obj === 'object') {
    const cleaned: any = {};
    for (const key of Object.keys(obj)) {
      const val = obj[key];
      if (val !== undefined) {
        cleaned[key] = sanitizePayload(val);
      }
    }
    return cleaned;
  }
  return obj;
}

/**
 * Whiteboards / History Service (Approved Collection: "whiteboards")
 *
 * Every operation targets an EXISTING board document id — saves update the
 * same record (merge), deletions remove the board AND its version snapshots
 * in one batch, and ownership metadata is preserved so opening a board from
 * History / Recent / Search restores the original record instead of forking it.
 */
const MAX_STROKES_PER_DOC = 2000;
const MAX_VERSIONS_PER_BOARD = 10;
const MAX_INLINE_ASSET_BYTES = 300 * 1024; // ~300KB base64 inline cap before Storage offload

async function compressOversizedContent(board: Board & Record<string, any>): Promise<Board> {
  let strokesList = Array.isArray(board.strokes) ? board.strokes : [];

  // Round coordinate precision to keep typical boards in the 1MB doc budget.
  strokesList = strokesList.map((s: any) => {
    if (s && Array.isArray(s.points)) {
      return {
        ...s,
        points: s.points.map((p: any) => ({
          x: Math.round((p.x || 0) * 10) / 10,
          y: Math.round((p.y || 0) * 10) / 10,
          ...(p.pressure !== undefined ? { pressure: Math.round(p.pressure * 100) / 100 } : {}),
        })),
      };
    }
    return s;
  });

  let size = JSON.stringify(strokesList || []).length;
  while (size > 900_000 && strokesList.length > MAX_STROKES_PER_DOC / 2) {
    strokesList = strokesList.slice(0, Math.floor(strokesList.length * 0.8));
    size = JSON.stringify(strokesList).length;
  }
  return { ...board, strokes: strokesList.slice(0, MAX_STROKES_PER_DOC) };
}

/** Move huge inline base64 documents to Firebase Storage so Firestore writes stay under the 1MB doc limit. */
async function offloadLargeAssets(userId: string, board: Board & Record<string, any>): Promise<Board> {
  try {
    const out = { ...board } as Record<string, any>;
    const swapToStorage = async (key: 'bgFile' | 'activeDocument', dataUrl: string, nameHint: string) => {
      if (typeof dataUrl !== 'string' || !dataUrl.startsWith('data:') || dataUrl.length < MAX_INLINE_ASSET_BYTES) return;
      const ext = (dataUrl.match(/^data:[^;]+/) || [''])[0].split('/')[1] || 'bin';
      const path = `documents/${userId}/${board.id}/${(nameHint || 'document').replace(/[^\w.-]+/g, '_')}.${ext}`;
      const storageRef = ref(storage, path);
      await uploadString(storageRef, dataUrl, 'data_url');
      const url = await getDownloadURL(storageRef);
      if (key === 'bgFile') {
        out[key] = { url, type: (board.bgFile as any)?.type || 'doc' };
      } else {
        out[key] = { ...(board.activeDocument as any), dataUrl: undefined, url, offloadedToStorage: true };
      }
      console.log(`[Firebase Storage] Offloaded large asset for board ${board.id} (${(dataUrl.length / 1024).toFixed(0)}KB) → ${path}`);
    };

    if (board.bgFile?.url) await swapToStorage('bgFile', board.bgFile.url, board.title || 'bg');
    const docDataUrl = (board.activeDocument as any)?.dataUrl || (board.activeDocument as any)?.url;
    if (docDataUrl) await swapToStorage('activeDocument', docDataUrl, (board.activeDocument as any)?.name || board.title || 'doc');
    return out as Board;
  } catch (err) {
    console.warn('[Firebase Storage] Asset offload skipped:', err);
    return board;
  }
}

export const historyService = {
  subscribeToHistory(userId: string, callback: (items: Board[]) => void): Unsubscribe | null {
    if (!userId) return null;
    try {
      const whiteboardsRef = collection(db, 'whiteboards');
      const boardsMap = new Map<string, Board>();

      const notify = () => {
        const sorted = Array.from(boardsMap.values()).sort((a: any, b: any) => {
          const timeA = new Date(a.updatedAt || a.updated_at || a.createdAt || a.created_at || 0).getTime();
          const timeB = new Date(b.updatedAt || b.updated_at || b.createdAt || b.created_at || 0).getTime();
          return timeB - timeA;
        });
        callback(sorted);
      };

      const handleSnapshot = (snap: any) => {
        snap.docChanges().forEach((change: any) => {
          if (change.type === 'removed') {
            boardsMap.delete(change.doc.id);
          } else {
            boardsMap.set(change.doc.id, { id: change.doc.id, ...change.doc.data() } as Board);
          }
        });
        snap.docs.forEach((d: any) => {
          boardsMap.set(d.id, { id: d.id, ...d.data() } as Board);
        });
        notify();
      };

      // Listen across all common ownership field aliases used by Web & Mobile
      const unsub1 = onSnapshot(query(whiteboardsRef, where('owner_id', '==', userId)), handleSnapshot, (err) => {
        console.warn('[Firebase Firestore] [whiteboards:owner_id] listener notice:', err);
      });
      const unsub2 = onSnapshot(query(whiteboardsRef, where('createdBy', '==', userId)), handleSnapshot, (err) => {
        console.warn('[Firebase Firestore] [whiteboards:createdBy] listener notice:', err);
      });
      const unsub3 = onSnapshot(query(whiteboardsRef, where('userId', '==', userId)), handleSnapshot, (err) => {
        console.warn('[Firebase Firestore] [whiteboards:userId] listener notice:', err);
      });
      const unsub4 = onSnapshot(query(whiteboardsRef, where('user_id', '==', userId)), handleSnapshot, (err) => {
        console.warn('[Firebase Firestore] [whiteboards:user_id] listener notice:', err);
      });

      return () => {
        unsub1();
        unsub2();
        unsub3();
        unsub4();
      };
    } catch (error) {
      console.warn('[Firebase Firestore] [whiteboards] Failed to setup listener:', error);
      return null;
    }
  },

  /** Fetch a single EXISTING board by id (used by board deep links / restore). */
  async getHistoryItem(userId: string, historyId: string): Promise<Board | null> {
    if (!historyId) return null;
    try {
      const itemRef = doc(db, 'whiteboards', historyId);
      const docSnap = await getDoc(itemRef);
      if (docSnap.exists()) {
        return { id: docSnap.id, ...docSnap.data() } as Board;
      }
      return null;
    } catch (error) {
      console.warn('[Firebase Firestore] [whiteboards] Error fetching board:', error);
      return null;
    }
  },

  /**
   * Save a board. Operates on the SAME document id with {merge:true}.
   * Preserves `createdBy`/`owner_id`/`createdAt` already stored on the payload
   * (ownership & timeline integrity) — only supplies them when missing.
   */
  async saveHistoryItem(userId: string, boardInput: Board): Promise<void> {
    if (!boardInput?.id) return;
    try {
      const withAssets = await offloadLargeAssets(userId, boardInput as Board);
      const compressed = await compressOversizedContent(withAssets);
      const nowIso = new Date().toISOString();
      const totalShapes = (compressed.strokes?.length || 0) + (compressed.elements?.length || 0);

      const payload = sanitizePayload({
        ...compressed,
        // Populate all ownership and timestamp aliases for cross-platform Web & Mobile sync
        owner_id: (boardInput as any).owner_id || boardInput.createdBy || (boardInput as any).userId || (boardInput as any).user_id || userId,
        createdBy: boardInput.createdBy || (boardInput as any).owner_id || (boardInput as any).userId || (boardInput as any).user_id || userId,
        userId: (boardInput as any).userId || (boardInput as any).user_id || (boardInput as any).owner_id || boardInput.createdBy || userId,
        user_id: (boardInput as any).user_id || (boardInput as any).userId || (boardInput as any).owner_id || boardInput.createdBy || userId,
        createdAt: boardInput.createdAt || (boardInput as any).created_at || nowIso,
        created_at: (boardInput as any).created_at || boardInput.createdAt || nowIso,
        updatedAt: nowIso,
        updated_at: nowIso,
        total_shapes: totalShapes,
        strokeCount: compressed.strokes?.length || 0,
      });
      await setDoc(doc(db, 'whiteboards', boardInput.id), payload, { merge: true });
    } catch (error) {
      console.error('[Firebase Firestore] [whiteboards] Error saving board:', error);
      throw error;
    }
  },

  /**
   * Delete a board plus every dependent record (version snapshots) in a
   * single Firestore WriteBatch — no orphan data, no broken references.
   */
  async deleteHistoryItem(userId: string, historyId: string): Promise<void> {
    if (!historyId) return;
    try {
      const versionsRef = collection(db, 'whiteboard_versions');
      const versionQuery = query(versionsRef, where('whiteboard_id', '==', historyId));
      const versionsSnap = await getDocs(versionQuery);

      const batch = writeBatch(db);
      versionsSnap.forEach(v => batch.delete(v.ref));
      batch.delete(doc(db, 'whiteboards', historyId));
      await batch.commit();
    } catch (error) {
      console.error('[Firebase Firestore] [whiteboards] Error deleting board:', error);
      throw error;
    }
  },

  /**
   * Version snapshots (Approved Collection: "whiteboard_versions").
   * Reads/writes are keyed by `whiteboard_id`; older snapshots beyond
   * MAX_VERSIONS_PER_BOARD are pruned with a batch write on every save.
   */
  async saveBoardVersion(userId: string, boardId: string, versionData: Partial<Board>): Promise<string> {
    if (!boardId) return '';
    try {
      const versionId = `v_${Date.now()}`;
      const payload = sanitizePayload({
        strokes: versionData.strokes || [],
        elements: versionData.elements || [],
        title: versionData.title || '',
        description: versionData.description || '',
        id: versionId,
        whiteboard_id: boardId,
        boardId,
        owner_id: userId,
        created_by: userId,
        createdBy: userId,
        created_at: new Date().toISOString(),
        createdAt: new Date().toISOString(),
      });

      const batch = writeBatch(db);
      batch.set(doc(db, 'whiteboard_versions', versionId), payload);

      // Prune older versions beyond the cap (batch delete same commit).
      const versionsSnap = await getDocs(query(collection(db, 'whiteboard_versions'), where('whiteboard_id', '==', boardId)));
      const older = versionsSnap.docs
        .sort((a, b) => String(b.data().created_at || '').localeCompare(String(a.data().created_at || '')))
        .slice(MAX_VERSIONS_PER_BOARD - 1);
      older.forEach(v => batch.delete(v.ref));

      await batch.commit();
      return versionId;
    } catch (error) {
      console.warn('[Firebase Firestore] [whiteboard_versions] Error saving version:', error);
      return '';
    }
  },

  /** List version snapshots for a board (newest first). */
  async getBoardVersions(boardId: string, limitTo: number = 20): Promise<Partial<Board>[] & {
    id?: string; createdAt?: string;
    createdBy?: string
  }[]> {
    if (!boardId) return [];
    try {
      const snap = await getDocs(query(
        collection(db, 'whiteboard_versions'),
        where('whiteboard_id', '==', boardId)
      ));
      const versions = snap.docs
        .map(documentSnapshot => ({ id: documentSnapshot.id, ...documentSnapshot.data() }))
        .sort((a: any, b: any) => String(b.created_at || b.createdAt || '').localeCompare(String(a.created_at || a.createdAt || '')))
        .slice(0, limitTo);
      return versions as any;
    } catch (error) {
      console.warn('[Firebase Firestore] [whiteboard_versions] Error listing versions:', error);
      return [];
    }
  },

  /**
   * Restore a board from a version snapshot — same board record, same id.
   * Preserves ownership/created timestamps; the restore itself is not
   * versioned again to avoid recursive snapshot growth.
   */
  async restoreBoardVersion(boardId: string, versionId: string): Promise<Board | null> {
    if (!boardId || !versionId) return null;
    try {
      const boardSnap = await getDoc(doc(db, 'whiteboards', boardId));
      const versionSnap = await getDoc(doc(db, 'whiteboard_versions', versionId));
      if (!boardSnap.exists() || !versionSnap.exists()) return null;

      const current = { id: boardSnap.id, ...boardSnap.data() } as Board;
      const version = versionSnap.data() as any;

      const restored: Board = {
        ...current,
        title: version.title || current.title,
        description: version.description || current.description,
        strokes: Array.isArray(version.strokes) ? version.strokes : [],
        elements: Array.isArray(version.elements) ? version.elements : [],
        updatedAt: new Date().toISOString(),
        // Keep ownership + createdAt so the board identity stays intact.
        createdBy: current.createdBy,
        createdAt: current.createdAt,
      };
      (restored as any).owner_id = (current as any).owner_id;

      await this.saveHistoryItem((current as any).owner_id || current.createdBy, restored);
      return restored;
    } catch (error) {
      console.warn('[Firebase Firestore] [whiteboard_versions] Error restoring version:', error);
      return null;
    }
  }
};


/**
 * Notifications Service (Approved Collection: "notifications")
 */
export const notificationService = {
  async getNotifications(userId: string): Promise<Notification[]> {
    if (!userId) return [];
    try {
      console.log('[Firebase Firestore] [notifications] Fetching notifications for user:', userId);
      const notifRef = collection(db, 'notifications');
      const q = query(notifRef, where('userId', '==', userId));
      const snapshot = await getDocs(q);
      const notifications = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Notification));
      notifications.sort((a, b) => new Date(b.timestamp || 0).getTime() - new Date(a.timestamp || 0).getTime());
      return notifications;
    } catch (error) {
      console.error('[Firebase Firestore] [notifications] Error fetching notifications:', error);
      return [];
    }
  },

  subscribeToNotifications(userId: string, callback: (notifications: Notification[]) => void): Unsubscribe | null {
    if (!userId) return null;
    try {
      console.log('[Firebase Firestore] [notifications] Subscribing to live notifications for user:', userId);
      const notifRef = collection(db, 'notifications');
      const q = query(notifRef, where('userId', '==', userId));

      return onSnapshot(q, (snapshot) => {
        const notifs = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Notification));
        notifs.sort((a, b) => new Date(b.timestamp || 0).getTime() - new Date(a.timestamp || 0).getTime());
        callback(notifs);
      }, (error) => {
        console.warn('[Firebase Firestore] [notifications] Notifications subscription warning:', error);
      });
    } catch (error) {
      console.error('[Firebase Firestore] [notifications] Error subscribing to notifications:', error);
      return null;
    }
  },

  async markAsRead(userId: string, notificationId: string): Promise<void> {
    if (!notificationId) return;
    try {
      const notifRef = doc(db, 'notifications', notificationId);
      await updateDoc(notifRef, { read: true });
    } catch (error) {
      console.error('[Firebase Firestore] [notifications] Error marking notification read:', error);
      throw error;
    }
  },

  async markAllAsRead(userId: string): Promise<void> {
    if (!userId) return;
    try {
      const notifRef = collection(db, 'notifications');
      const q = query(notifRef, where('userId', '==', userId), where('read', '==', false));
      const snapshot = await getDocs(q);

      const updatePromises = snapshot.docs.map(d =>
        updateDoc(doc(db, 'notifications', d.id), { read: true })
      );
      await Promise.all(updatePromises);
    } catch (error) {
      console.error('[Firebase Firestore] [notifications] Error marking all notifications read:', error);
      throw error;
    }
  },

  async deleteNotification(userId: string, notificationId: string): Promise<void> {
    if (!notificationId) return;
    try {
      const notifRef = doc(db, 'notifications', notificationId);
      await deleteDoc(notifRef);
    } catch (error) {
      console.error('[Firebase Firestore] [notifications] Error deleting notification:', error);
      throw error;
    }
  },

  async addNotification(userId: string, notification: Partial<Notification>): Promise<Notification> {
    const id = notification.id || `${Date.now()}_${Math.random().toString(36).substr(2, 6)}`;
    const newNotif: Notification = {
      id,
      type: notification.type || 'info',
      title: notification.title || 'Notification',
      message: notification.message || '',
      timestamp: notification.timestamp || new Date().toISOString(),
      read: false,
      actionable: notification.actionable || false,
      actionUrl: notification.actionUrl || '',
    };

    if (userId) {
      try {
        const notifRef = doc(db, 'notifications', id);
        await setDoc(notifRef, { ...newNotif, userId, user_id: userId });
      } catch (error) {
        console.error('[Firebase Firestore] [notifications] Error saving notification:', error);
      }
    }

    return newNotif;
  }
};

/**
 * User Profile & Avatar Service (Approved Collection: "users")
 */
export const userProfileService = {
  async uploadAvatar(userId: string, dataUrl: string): Promise<string> {
    if (!userId || !dataUrl) return dataUrl;
    if (!dataUrl.startsWith('data:')) return dataUrl;

    try {
      const avatarRef = ref(storage, `users/${userId}/avatar`);
      await uploadString(avatarRef, dataUrl, 'data_url');
      const downloadUrl = await getDownloadURL(avatarRef);
      return downloadUrl;
    } catch (error) {
      console.warn('[Firebase Storage] Avatar upload fallback to data URL:', error);
      return dataUrl;
    }
  },

  async getProfile(userId: string): Promise<User | null> {
    if (!userId || userId === 'guest' || userId === 'usr_guest') return null;
    try {
      const userRef = doc(db, 'users', userId);
      const snap = await getDoc(userRef);
      if (snap.exists()) {
        const data = snap.data();
        return {
          id: snap.id,
          name: data.full_name || data.name || 'EduBoard User',
          email: data.email || '',
          address: data.address || '',
          organization: data.organization || data.institution || '',
          institution: data.organization || data.institution || '',
          phone: data.phone || data.phoneNumber || data.phone_number || '',
          location: data.location || '',
          bio: data.bio || '',
          avatar: data.avatar || data.avatarUrl || data.photoURL || '',
          role: data.role || 'teacher',
          username: data.username || data.email?.split('@')[0] || 'user',
          isVerified: data.isVerified ?? true,
          isBiometricEnabled: data.isBiometricEnabled || false,
          createdAt: data.createdAt?.toDate?.()?.toISOString() || data.createdAt || new Date().toISOString(),
          lastLoginAt: data.lastLoginAt?.toDate?.()?.toISOString() || data.lastLoginAt || new Date().toISOString(),
          ...data,
        } as User;
      }
      return null;
    } catch (error: any) {
      const isPermissionError = error?.code === 'permission-denied' ||
        (typeof error?.message === 'string' && error.message.includes('Missing or insufficient permissions'));

      if (isPermissionError) {
        console.warn('[Firebase Firestore] [users] Insufficient permissions for Firestore read; attempting API profile fallback.');
        try {
          const apiProfile = await api.getProfile();
          if (apiProfile) {
            return {
              id: (apiProfile as any).id || userId,
              email: apiProfile.email || '',
              name: apiProfile.name || (apiProfile as any).fullName || 'EduBoard User',
              role: (apiProfile.role as any) || 'teacher',
              username: (apiProfile as any).username || apiProfile.email?.split('@')[0] || 'user',
              avatar: apiProfile.avatar || (apiProfile as any).avatarUrl || '',
              isVerified: true,
              isBiometricEnabled: false,
              createdAt: (apiProfile as any).createdAt || new Date().toISOString(),
              lastLoginAt: new Date().toISOString(),
            };
          }
        } catch {
          const localUser = store.getUser();
          if (localUser && localUser.id && localUser.id !== 'guest') return localUser;
        }
        return null;
      }

      console.warn('[Firebase Firestore] [users] Profile fetch notice:', error?.message || error);
      return null;
    }
  },

  subscribeToProfile(userId: string, callback: (user: User | null) => void): Unsubscribe | null {
    if (!userId || userId === 'guest' || userId === 'usr_guest') return null;
    try {
      const userRef = doc(db, 'users', userId);
      return onSnapshot(userRef, (snap) => {
        if (snap.exists()) {
          const data = snap.data();
          const profile: User = {
            id: snap.id,
            email: data.email || '',
            name: data.full_name || data.name || 'EduBoard User',
            address: data.address || '',
            organization: data.organization || data.institution || '',
            institution: data.organization || data.institution || '',
            phone: data.phone || data.phoneNumber || data.phone_number || '',
            location: data.location || '',
            bio: data.bio || '',
            role: data.role || 'teacher',
            username: data.username || data.email?.split('@')[0] || 'user',
            avatar: data.avatar || data.avatarUrl || data.photoURL || '',
            grade: data.grade || '',
            subject: data.subject || (Array.isArray(data.subjects) ? data.subjects.join(', ') : ''),
            website: data.website || '',
            dob: data.dob || '',
            gender: data.gender || '',
            socialLinks: data.socialLinks || {},
            languages: data.languages || [],
            certifications: data.certifications || [],
            interests: data.interests || [],
            isVerified: data.isVerified ?? true,
            isBiometricEnabled: data.isBiometricEnabled || false,
            createdAt: data.createdAt?.toDate?.()?.toISOString() || data.createdAt || new Date().toISOString(),
            lastLoginAt: data.lastLoginAt?.toDate?.()?.toISOString() || data.lastLoginAt || new Date().toISOString(),
            ...data,
          };
          callback(profile);
        } else {
          callback(null);
        }
      }, (error: any) => {
        console.warn(`[Firebase Firestore] [users] Profile subscription notice:`, error?.message || error);
      });
    } catch (error: any) {
      console.warn(`[Firebase Firestore] [users] Profile listener setup note:`, error?.message || error);
      return null;
    }
  },

  async updateProfile(userId: string, data: Partial<User>): Promise<void> {
    const activeUid = auth.currentUser?.uid || userId;
    if (!activeUid || activeUid === 'guest' || activeUid === 'usr_guest') return;

    console.log(`[Firebase Firestore] [users] Updating profile for target UID: ${activeUid} (currentAuthUid: ${auth.currentUser?.uid || 'none'})`);

    try {
      const payload = { ...data };
      if (payload.avatar && payload.avatar.startsWith('data:')) {
        payload.avatar = await this.uploadAvatar(activeUid, payload.avatar);
      }

      const nowIso = new Date().toISOString();
      const cleanPayload = sanitizePayload({
        ...payload,
        name: payload.name || (payload as any).full_name,
        full_name: payload.name || (payload as any).full_name,
        address: (payload as any).address !== undefined ? (payload as any).address : '',
        organization: (payload as any).organization || payload.institution || '',
        institution: payload.institution || (payload as any).organization || '',
        phone: payload.phone || (payload as any).phoneNumber || (payload as any).phone_number || '',
        phoneNumber: payload.phone || (payload as any).phoneNumber || (payload as any).phone_number || '',
        phone_number: payload.phone || (payload as any).phoneNumber || (payload as any).phone_number || '',
        location: payload.location !== undefined ? payload.location : '',
        bio: payload.bio !== undefined ? payload.bio : '',
        avatar: payload.avatar || '',
        avatarUrl: payload.avatar || '',
        photoURL: payload.avatar || '',
        userId: activeUid,
        user_id: activeUid,
        uid: activeUid,
        id: activeUid,
        updatedAt: serverTimestamp(),
        updated_at: nowIso,
      });

      // 1. Primary write: Firestore client SDK directly to canonical users/{activeUid}
      let writeSuccess = false;
      try {
        const userRef = doc(db, 'users', activeUid);
        await setDoc(userRef, cleanPayload, { merge: true });
        writeSuccess = true;
        console.log(`[Firebase Firestore] [users] Successfully saved profile to /users/${activeUid} via Firestore SDK`);
      } catch (firestoreErr: any) {
        console.warn(`[Firebase Firestore] [users] Client setDoc note (${firestoreErr.code || firestoreErr.message}). Attempting Admin API fallback...`);
      }

      // 2. Server Admin SDK fallback if client write failed or was blocked by rules
      if (!writeSuccess) {
        try {
          const apiPayload = { ...cleanPayload };
          delete (apiPayload as any).updatedAt; // Strip FieldValue before JSON serialization
          await api.updateProfile(apiPayload as any);
          console.log(`[Firebase Firestore] [users] Successfully saved profile to /users/${activeUid} via backend Admin API fallback`);
          writeSuccess = true;
        } catch (apiErr: any) {
          console.error(`[Firebase Firestore] [users] Both client and server writes failed for ${activeUid}:`, apiErr.message || apiErr);
          throw apiErr;
        }
      }

      // 3. Mirror to auth.currentUser if different
      if (auth.currentUser?.uid && auth.currentUser.uid !== activeUid) {
        try {
          const authUidRef = doc(db, 'users', auth.currentUser.uid);
          await setDoc(authUidRef, cleanPayload, { merge: true });
        } catch (_) {}
      }

      // 4. Update Firebase Auth displayName & photoURL if authenticated
      if (auth.currentUser) {
        try {
          const { updateProfile: fbAuthUpdateProfile } = await import('firebase/auth');
          await fbAuthUpdateProfile(auth.currentUser, {
            displayName: cleanPayload.name || auth.currentUser.displayName,
            photoURL: cleanPayload.avatar || auth.currentUser.photoURL,
          });
        } catch (authErr) {
          console.warn('[Firebase Auth] updateUserProfile notice:', authErr);
        }
      }
    } catch (error) {
      console.error('[Firebase Firestore] [users] Error updating profile:', error);
      throw error;
    }
  }
};

/**
 * Theme & User Settings Service (Approved Collection: "userSettings")
 */
export const userSettingsService = {
  subscribeToSettings(userId: string, callback: (settings: any) => void): Unsubscribe | null {
    if (!userId || userId === 'guest' || userId === 'usr_guest') return null;
    try {
      const settingsRef = doc(db, 'userSettings', userId);
      return onSnapshot(settingsRef, (snap) => {
        if (snap.exists()) {
          callback(snap.data());
        }
      }, (err) => {
        console.warn('[Firebase Firestore] [userSettings] Subscription error:', err);
      });
    } catch (error) {
      console.error('[Firebase Firestore] [userSettings] Error setting up settings subscription:', error);
      return null;
    }
  },

  async getSettings(userId: string): Promise<any | null> {
    if (!userId) return null;
    try {
      console.log(`[Firebase Firestore] [userSettings] Fetching settings for user ${userId}`);
      const settingsRef = doc(db, 'userSettings', userId);
      const snap = await getDoc(settingsRef);
      if (snap.exists()) {
        return snap.data();
      }
      return null;
    } catch (error) {
      console.warn('[Firebase Firestore] [userSettings] Error fetching user settings:', error);
      return null;
    }
  },

  async saveSettings(userId: string, settingsData: any): Promise<void> {
    if (!userId) return;
    try {
      console.log(`[Firebase Firestore] [userSettings] Saving settings for user ${userId}`);
      const payload = sanitizePayload({
        ...settingsData,
        userId: userId,
        user_id: userId,
        updatedAt: new Date().toISOString(),
      });
      const settingsRef = doc(db, 'userSettings', userId);
      await setDoc(settingsRef, payload, { merge: true });
      console.log(`[Firebase Firestore] [userSettings] Settings saved successfully for ${userId}`);
    } catch (error) {
      console.error('[Firebase Firestore] [userSettings] Error saving user settings:', error);
      throw error;
    }
  }
};
