import { initializeApp } from "firebase/app";
import { getAuth, GoogleAuthProvider, signInWithPopup, signOut } from "firebase/auth";

// Firebase config values are public (not secrets).
// Add VITE_FIREBASE_* values to your local frontend/.env for dev.
// For production, they are baked into the Docker image via the Ansible env.j2 template.
const firebaseConfig = {
  apiKey:            import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain:        import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId:         import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket:     import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId:             import.meta.env.VITE_FIREBASE_APP_ID,
};

const app  = initializeApp(firebaseConfig);
const auth = getAuth(app);

export const signInWithGoogle = () => signInWithPopup(auth, new GoogleAuthProvider());
export const logout           = () => signOut(auth);
export { auth };
