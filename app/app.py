"""
Travel Assistant Web App
- Auth:        Firebase Authentication (ID token verified server-side)
- AI:          Google Gemini 1.5 Flash (free tier, 500 req/day cap)
- Database:    Firestore — users/{uid}/sessions/{sid}/messages subcollection
- Monitoring:  Prometheus metrics at /metrics
"""

import os
import time
import uuid
import logging
from datetime import datetime, timezone, date
from functools import wraps

import firebase_admin
from firebase_admin import auth as firebase_auth, credentials
from flask import Flask, request, jsonify, render_template, g
import google.generativeai as genai
from google.cloud import firestore
from prometheus_client import (
    Counter, Histogram, Gauge,
    generate_latest, CONTENT_TYPE_LATEST
)

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

app = Flask(__name__)
GEMINI_API_KEY    = os.environ["GEMINI_API_KEY"]
DAILY_REQUEST_CAP = int(os.getenv("DAILY_REQUEST_CAP", "500"))

# Firebase Admin — uses VM service account via ADC (roles/firebase.sdkAdminServiceAgent required)
firebase_admin.initialize_app(credentials.ApplicationDefault())

genai.configure(api_key=GEMINI_API_KEY)
gemini_model = genai.GenerativeModel(
    model_name="gemini-1.5-flash",
    system_instruction="""You are an expert AI travel assistant.
You help users plan trips, suggest destinations, find local attractions,
recommend restaurants, advise on budgets, visas, packing, and cultural tips.
Be concise, enthusiastic, and practical. Format responses with clear sections
when listing multiple items. Always ask follow-up questions to refine suggestions."""
)

db = firestore.Client()

REQUEST_COUNT        = Counter("travel_app_requests_total",       "Total HTTP requests",       ["method","endpoint","status"])
GEMINI_REQUEST_COUNT = Counter("gemini_api_requests_total",       "Total Gemini API calls",    ["status"])
GEMINI_REQUEST_LATENCY = Histogram("gemini_api_latency_seconds",  "Gemini API latency",        buckets=[0.5,1,2,5,10,20])
DAILY_REQUESTS_USED  = Gauge("gemini_daily_requests_used",        "Gemini requests used today")
DAILY_REQUESTS_REMAINING = Gauge("gemini_daily_requests_remaining","Gemini requests remaining")

# ─── Auth decorator ───────────────────────────────────────────────────────────

def require_auth(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        header = request.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            return jsonify({"error": "Missing Authorization header"}), 401
        try:
            decoded        = firebase_auth.verify_id_token(header.split(" ", 1)[1])
            g.uid          = decoded["uid"]
            g.email        = decoded.get("email", "")
            g.display_name = decoded.get("name", g.email)
        except firebase_auth.ExpiredIdTokenError:
            return jsonify({"error": "Token expired — please sign in again"}), 401
        except Exception as e:
            logger.warning("Auth failure: %s", e)
            return jsonify({"error": "Unauthorized"}), 401
        return f(*args, **kwargs)
    return wrapper

# ─── Firestore helpers ────────────────────────────────────────────────────────

def user_ref(uid):    return db.collection("users").document(uid)
def session_ref(uid, sid): return user_ref(uid).collection("sessions").document(sid)

def ensure_user_profile(uid, email, display_name):
    user_ref(uid).set({"email": email, "display_name": display_name,
                        "created_at": firestore.SERVER_TIMESTAMP}, merge=True)

def get_today_usage():
    doc = db.collection("api_usage").document(date.today().isoformat()).get()
    return doc.to_dict().get("request_count", 0) if doc.exists else 0

def increment_usage():
    today = date.today().isoformat()
    ref   = db.collection("api_usage").document(today)
    tx    = db.transaction()
    @firestore.transactional
    def _upd(t):
        snap = ref.get(transaction=t)
        n = (snap.to_dict().get("request_count", 0) if snap.exists else 0) + 1
        t.set(ref, {"request_count": n, "date": today, "updated_at": firestore.SERVER_TIMESTAMP})
        return n
    count = _upd(tx)
    DAILY_REQUESTS_USED.set(count)
    DAILY_REQUESTS_REMAINING.set(max(0, DAILY_REQUEST_CAP - count))
    return count

def get_or_create_session(uid, sid, first_msg):
    ref = session_ref(uid, sid)
    if not ref.get().exists:
        title = (first_msg[:60] + "…") if len(first_msg) > 60 else first_msg
        ref.set({"title": title, "created_at": firestore.SERVER_TIMESTAMP,
                 "updated_at": firestore.SERVER_TIMESTAMP, "message_count": 0})

def save_message(uid, sid, user_msg, ai_msg):
    session_ref(uid, sid).collection("messages").add({
        "user_message": user_msg, "ai_response": ai_msg,
        "created_at": firestore.SERVER_TIMESTAMP, "model": "gemini-1.5-flash"})
    session_ref(uid, sid).update({"updated_at": firestore.SERVER_TIMESTAMP,
                                   "message_count": firestore.Increment(1)})

def get_chat_history(uid, sid, limit=10):
    docs = list(session_ref(uid, sid).collection("messages")
                .order_by("created_at", direction=firestore.Query.DESCENDING)
                .limit(limit).stream())
    history = []
    for doc in reversed(docs):
        d = doc.to_dict()
        history += [{"role":"user","parts":[d["user_message"]]},
                    {"role":"model","parts":[d["ai_response"]]}]
    return history

# ─── Middleware ───────────────────────────────────────────────────────────────

@app.before_request
def _before(): g.start_time = datetime.now(timezone.utc)

@app.after_request
def _after(r):
    if hasattr(g, "start_time"):
        REQUEST_COUNT.labels(method=request.method,
                             endpoint=request.endpoint or "unknown",
                             status=r.status_code).inc()
    return r

# ─── Template helper ─────────────────────────────────────────────────────────

def _fb_config():
    return {"apiKey":           os.environ["FIREBASE_WEB_API_KEY"],
            "authDomain":       os.environ["FIREBASE_AUTH_DOMAIN"],
            "projectId":        os.environ["GOOGLE_CLOUD_PROJECT"],
            "storageBucket":    os.getenv("FIREBASE_STORAGE_BUCKET",""),
            "messagingSenderId":os.getenv("FIREBASE_MESSAGING_SENDER_ID",""),
            "appId":            os.getenv("FIREBASE_APP_ID","")}

# ─── Page routes ─────────────────────────────────────────────────────────────

@app.route("/")
def index():   return render_template("index.html",   firebase_config=_fb_config())
@app.route("/login")
def login():   return render_template("login.html",   firebase_config=_fb_config())
@app.route("/account")
def account(): return render_template("account.html", firebase_config=_fb_config())

# ─── Auth API ────────────────────────────────────────────────────────────────

@app.route("/api/auth/sync", methods=["POST"])
@require_auth
def auth_sync():
    ensure_user_profile(g.uid, g.email, g.display_name)
    return jsonify({"uid": g.uid, "email": g.email, "display_name": g.display_name})

# ─── Account API ─────────────────────────────────────────────────────────────

@app.route("/api/account", methods=["GET"])
@require_auth
def get_account():
    doc = user_ref(g.uid).get()
    p   = doc.to_dict() if doc.exists else {}
    p.update({"uid": g.uid,
               "session_count": len(list(user_ref(g.uid).collection("sessions").stream()))})
    p.pop("created_at", None)
    return jsonify(p)

@app.route("/api/account", methods=["PUT"])
@require_auth
def update_account():
    name = (request.get_json(silent=True) or {}).get("display_name","").strip()
    if not name: return jsonify({"error": "display_name required"}), 400
    user_ref(g.uid).update({"display_name": name})
    firebase_auth.update_user(g.uid, display_name=name)
    return jsonify({"ok": True, "display_name": name})

@app.route("/api/account", methods=["DELETE"])
@require_auth
def delete_account():
    uid = g.uid
    for s in user_ref(uid).collection("sessions").stream():
        for m in session_ref(uid, s.id).collection("messages").stream():
            m.reference.delete()
        s.reference.delete()
    user_ref(uid).delete()
    firebase_auth.delete_user(uid)
    logger.info("Account deleted: %s", uid)
    return jsonify({"ok": True})

# ─── Sessions API ────────────────────────────────────────────────────────────

@app.route("/api/sessions", methods=["GET"])
@require_auth
def list_sessions():
    docs = (user_ref(g.uid).collection("sessions")
            .order_by("updated_at", direction=firestore.Query.DESCENDING)
            .limit(50).stream())
    return jsonify({"sessions": [
        {"session_id": d.id, "title": d.to_dict().get("title","Untitled"),
         "message_count": d.to_dict().get("message_count", 0)} for d in docs]})

@app.route("/api/sessions/<sid>", methods=["GET"])
@require_auth
def get_session(sid):
    docs = (session_ref(g.uid, sid).collection("messages")
            .order_by("created_at").stream())
    return jsonify({"session_id": sid, "messages": [
        {"user": d.to_dict().get("user_message"), "ai": d.to_dict().get("ai_response")}
        for d in docs]})

@app.route("/api/sessions/<sid>", methods=["DELETE"])
@require_auth
def delete_session(sid):
    for m in session_ref(g.uid, sid).collection("messages").stream():
        m.reference.delete()
    session_ref(g.uid, sid).delete()
    return jsonify({"ok": True})

# ─── Chat API ────────────────────────────────────────────────────────────────

@app.route("/api/chat", methods=["POST"])
@require_auth
def chat():
    data     = request.get_json(silent=True) or {}
    user_msg = (data.get("message") or "").strip()
    sid      = str(uuid.uuid4()) if data.get("new_session") else (data.get("session_id") or str(uuid.uuid4()))
    if not user_msg:
        return jsonify({"error": "message is required"}), 400
    used = get_today_usage()
    if used >= DAILY_REQUEST_CAP:
        return jsonify({"error": "Daily request limit reached.", "usage": used, "cap": DAILY_REQUEST_CAP}), 429
    try:
        ensure_user_profile(g.uid, g.email, g.display_name)
        get_or_create_session(g.uid, sid, user_msg)
        chat_s   = gemini_model.start_chat(history=get_chat_history(g.uid, sid))
        t0       = time.time()
        resp     = chat_s.send_message(user_msg)
        latency  = time.time() - t0
        GEMINI_REQUEST_LATENCY.observe(latency)
        GEMINI_REQUEST_COUNT.labels(status="success").inc()
        ai_text   = resp.text
        new_count = increment_usage()
        save_message(g.uid, sid, user_msg, ai_text)
        logger.info("Chat OK uid=%s sid=%s usage=%d latency=%.2fs", g.uid, sid, new_count, latency)
        return jsonify({"response": ai_text, "session_id": sid,
                        "usage": {"used": new_count, "cap": DAILY_REQUEST_CAP}})
    except Exception as e:
        GEMINI_REQUEST_COUNT.labels(status="error").inc()
        logger.error("Gemini error: %s", e, exc_info=True)
        return jsonify({"error": "AI service unavailable."}), 503

# ─── Infra routes ────────────────────────────────────────────────────────────

@app.route("/api/usage")
def api_usage():
    used = get_today_usage()
    rem  = max(0, DAILY_REQUEST_CAP - used)
    DAILY_REQUESTS_USED.set(used); DAILY_REQUESTS_REMAINING.set(rem)
    return jsonify({"date": date.today().isoformat(), "used": used,
                    "cap": DAILY_REQUEST_CAP, "remaining": rem,
                    "percent": round(used / DAILY_REQUEST_CAP * 100, 1)})

@app.route("/metrics")
def metrics(): return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}

@app.route("/health")
def health(): return jsonify({"status":"ok","timestamp":datetime.now(timezone.utc).isoformat()})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT","5000")), debug=False)
