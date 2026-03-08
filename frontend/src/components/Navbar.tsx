import { Link, useLocation } from "react-router-dom";
import { logout } from "../services/firebase";
import type { AuthUser } from "../types";

interface NavbarProps {
  user: AuthUser;
}

export default function Navbar({ user }: NavbarProps) {
  const { pathname } = useLocation();

  const link = (to: string, label: string) => (
    <Link
      to={to}
      className={`px-3 py-1 rounded-md text-sm font-medium transition-colors ${
        pathname.startsWith(to)
          ? "bg-blue-100 text-blue-700"
          : "text-slate-600 hover:text-blue-600"
      }`}
    >
      {label}
    </Link>
  );

  return (
    <nav className="bg-white border-b border-slate-200 px-4 py-3 flex items-center justify-between">
      <div className="flex items-center gap-4">
        <span className="font-bold text-blue-600 text-lg">✈️ TravelAI</span>
        {link("/chat", "Chat")}
        {link("/trips", "My Trips")}
      </div>
      <div className="flex items-center gap-3">
        <span className="text-sm text-slate-500">{user.name}</span>
        <button
          onClick={logout}
          className="text-sm text-slate-500 hover:text-red-500 transition-colors"
        >
          Sign out
        </button>
      </div>
    </nav>
  );
}
