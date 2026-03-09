"""
Auth router — email/password registration and login with JWT tokens.
"""
import logging
import uuid
import datetime

from fastapi import APIRouter, HTTPException, status, Depends
from pydantic import BaseModel

from metrics import auth_events_total
from services.firebase_auth import (
    get_current_user,
    hash_password,
    verify_password,
    create_access_token,
)
from services.firestore_client import get_db

router = APIRouter()
logger = logging.getLogger(__name__)


class RegisterIn(BaseModel):
    name: str
    email: str
    password: str


class LoginIn(BaseModel):
    email: str
    password: str


class AuthOut(BaseModel):
    user_id: str
    name: str
    token: str


class UserProfile(BaseModel):
    uid: str
    email: str | None
    display_name: str | None


@router.post("/register", response_model=AuthOut)
async def register(body: RegisterIn):
    db = get_db()
    existing = list(
        db.collection("users").where("email", "==", body.email).limit(1).stream()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    uid = str(uuid.uuid4())
    db.collection("users").document(uid).set({
        "uid": uid,
        "email": body.email,
        "display_name": body.name,
        "password_hash": hash_password(body.password),
        "created_at": datetime.datetime.now(datetime.timezone.utc),
    })

    auth_events_total.labels(event="register").inc()
    logger.info("user_registered", extra={"uid": uid, "email": body.email})

    token = create_access_token(uid=uid, email=body.email, name=body.name)
    return AuthOut(user_id=uid, name=body.name, token=token)


@router.post("/login", response_model=AuthOut)
async def login(body: LoginIn):
    db = get_db()
    docs = list(
        db.collection("users").where("email", "==", body.email).limit(1).stream()
    )
    if not docs:
        auth_events_total.labels(event="login_failure").inc()
        logger.warning("login_failed", extra={"email": body.email, "reason": "user_not_found"})
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    user_data = docs[0].to_dict()
    if not verify_password(body.password, user_data.get("password_hash", "")):
        auth_events_total.labels(event="login_failure").inc()
        logger.warning("login_failed", extra={"email": body.email, "reason": "bad_password"})
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    auth_events_total.labels(event="login_success").inc()
    logger.info("login_success", extra={"uid": user_data["uid"]})

    token = create_access_token(
        uid=user_data["uid"],
        email=user_data["email"],
        name=user_data.get("display_name", ""),
    )
    return AuthOut(
        user_id=user_data["uid"],
        name=user_data.get("display_name", ""),
        token=token,
    )


@router.get("/me", response_model=UserProfile)
async def get_user(user: dict = Depends(get_current_user)):
    db = get_db()
    doc = db.collection("users").document(user["uid"]).get()
    if not doc.exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    data = doc.to_dict()
    return UserProfile(uid=data["uid"], email=data["email"], display_name=data.get("display_name"))
