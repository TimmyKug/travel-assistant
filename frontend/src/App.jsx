import { Routes, Route, Navigate } from "react-router-dom";
import { useAuth } from "./AuthContext";
import Login from "./components/Login";
import Register from "./components/Register";
import Chat from "./components/Chat";
import TripPlanner from "./components/TripPlanner";
import Nav from "./components/Nav";

export default function App() {
  const { user } = useAuth();

  if (!user) {
    return (
      <Routes>
        <Route path="/register" element={<Register />} />
        <Route path="*"         element={<Login />} />
      </Routes>
    );
  }

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
