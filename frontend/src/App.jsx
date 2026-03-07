import { useEffect, useState } from "react";
import { Routes, Route, Navigate } from "react-router-dom";
import { onAuthStateChanged } from "firebase/auth";
import { auth } from "./services/firebase";
import { upsertUser } from "./services/api";
import Login from "./components/Login";
import Chat from "./components/Chat";
import TripPlanner from "./components/TripPlanner";
import Nav from "./components/Nav";

export default function App() {
  const [user, setUser]       = useState(undefined); // undefined = loading
  const [ready, setReady]     = useState(false);

  useEffect(() => {
    return onAuthStateChanged(auth, async (firebaseUser) => {
      setUser(firebaseUser);
      if (firebaseUser) {
        await upsertUser().catch(console.error);
      }
      setReady(true);
    });
  }, []);

  if (!ready) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-slate-900">
        <div className="text-white text-xl animate-pulse">Loading...</div>
      </div>
    );
  }

  if (!user) return <Login />;

  return (
    <div className="min-h-screen bg-slate-900 text-white">
      <Nav user={user} />
      <main className="max-w-6xl mx-auto px-4 py-6">
        <Routes>
          <Route path="/"      element={<Chat />} />
          <Route path="/trips" element={<TripPlanner />} />
          <Route path="*"      element={<Navigate to="/" />} />
        </Routes>
      </main>
    </div>
  );
}
