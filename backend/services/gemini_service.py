import google.generativeai as genai
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    gemini_api_key: str
    gcp_project_id: str

    class Config:
        env_file = ".env"


@lru_cache
def get_settings() -> Settings:
    return Settings()


def get_gemini_model():
    settings = get_settings()
    genai.configure(api_key=settings.gemini_api_key)
    return genai.GenerativeModel(
        model_name="gemini-1.5-flash",
        system_instruction=(
            "You are an expert travel assistant. Help users plan trips, suggest "
            "destinations, find attractions, estimate budgets, and provide local tips. "
            "Be concise, friendly, and practical. Structure itineraries with dates "
            "and times. When saving a trip, confirm you've done so."
        ),
    )
