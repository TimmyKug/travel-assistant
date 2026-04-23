import { Link, useLocation } from "react-router-dom";
import { MessageCircle, Map, LogOut, Plane } from "lucide-react";
import { useAuth } from "../AuthContext";
import type { AuthUser } from "../types";

interface NavProps {
  user: AuthUser;
}

export default function Nav({ user }: NavProps) {
  const { logout } = useAuth();
  const { pathname } = useLocation();

  const isActive = (to: string) => (to === "/trips" ? pathname.startsWith("/trips") : pathname === to);

  const navLink = (to: string, Icon: React.ElementType, label: string) => (
    <Link
      to={to}
      className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition
        ${isActive(to) ? "bg-blue-600 text-white" : "text-slate-400 hover:text-white hover:bg-slate-700"}`}
    >
      <Icon className="w-4 h-4" /> {label}
    </Link>
  );

  return (
    <nav className="bg-slate-800 border-b border-slate-700 px-4 py-3 flex items-center justify-between">
      <div className="flex items-center gap-3">
        <Plane className="w-5 h-5 text-blue-400" />
        <span className="font-bold text-white hidden sm:block">Travel Assistant</span>
      </div>
      <div className="flex items-center gap-2">
        {navLink("/",      MessageCircle, "Chat")}
        {navLink("/trips", Map,           "My Trips")}
      </div>
      <div className="flex items-center gap-3">
        <span className="text-slate-400 text-sm hidden sm:block">{user.name}</span>
        <button onClick={logout} className="text-slate-400 hover:text-white transition">
          <LogOut className="w-5 h-5" />
        </button>
      </div>
    </nav>
  );
}
