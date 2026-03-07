import { Link, useLocation } from "react-router-dom";
import { MessageCircle, Map, LogOut, Plane } from "lucide-react";
import { logout } from "../services/firebase";

export default function Nav({ user }) {
  const { pathname } = useLocation();
  const navLink = (to, Icon, label) => (
    <Link
      to={to}
      className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition
        ${pathname === to ? "bg-blue-600 text-white" : "text-slate-400 hover:text-white hover:bg-slate-700"}`}
    >
      <Icon className="w-4 h-4" /> {label}
    </Link>
  );

  return (
    <nav className="bg-slate-800 border-b border-slate-700 px-4 py-3 flex items-center justify-between">
      <div className="flex items-center gap-3">
        <Plane className="w-5 h-5 text-blue-400" />
        <span className="font-bold text-white hidden sm:block">Travel AI</span>
      </div>
      <div className="flex items-center gap-2">
        {navLink("/",      MessageCircle, "Chat")}
        {navLink("/trips", Map,           "My Trips")}
      </div>
      <div className="flex items-center gap-3">
        {user.photoURL && <img src={user.photoURL} alt="" className="w-8 h-8 rounded-full" />}
        <button onClick={logout} className="text-slate-400 hover:text-white transition">
          <LogOut className="w-5 h-5" />
        </button>
      </div>
    </nav>
  );
}
