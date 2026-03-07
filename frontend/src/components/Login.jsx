import { signInWithGoogle } from "../services/firebase";
import { Plane } from "lucide-react";

export default function Login() {
  return (
    <div className="min-h-screen bg-slate-900 flex items-center justify-center">
      <div className="bg-slate-800 rounded-2xl p-10 flex flex-col items-center gap-6 shadow-2xl w-full max-w-sm">
        <div className="bg-blue-600 rounded-full p-4">
          <Plane className="w-10 h-10 text-white" />
        </div>
        <h1 className="text-2xl font-bold text-white">AI Travel Assistant</h1>
        <p className="text-slate-400 text-center text-sm">
          Plan your perfect trip with the help of AI. Sign in to get started.
        </p>
        <button
          onClick={signInWithGoogle}
          className="w-full bg-white text-slate-900 font-semibold py-3 rounded-xl hover:bg-slate-100 transition flex items-center justify-center gap-2"
        >
          <img src="https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg" alt="Google" className="w-5 h-5" />
          Sign in with Google
        </button>
      </div>
    </div>
  );
}
