import { initializeApp } from 'firebase/app'
import { getAuth, GoogleAuthProvider, signInWithPopup, signOut } from 'firebase/auth'

// Replace with your Firebase project config (safe to commit — it's public config, not a secret)
const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
}

const app = initializeApp(firebaseConfig)
export const auth = getAuth(app)
export const googleProvider = new GoogleAuthProvider()

export const loginWithGoogle = () => signInWithPopup(auth, googleProvider)
export const logout = () => signOut(auth)

export const getIdToken = async () => {
  const user = auth.currentUser
  if (!user) throw new Error('Not logged in')
  return user.getIdToken()
}
