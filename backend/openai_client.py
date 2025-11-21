import json
import os
from typing import Dict, List

from fastapi import HTTPException
from openai import AsyncOpenAI

MODEL_NAME = os.getenv("OPENAI_MODEL", "gpt-5.1-mini")
API_KEY = os.getenv("OPENAI_API_KEY")
client = AsyncOpenAI(api_key=API_KEY) if API_KEY else None


def is_openai_configured() -> bool:
    return client is not None


def _require_client():
    if client is None:
        raise HTTPException(status_code=500, detail="OPENAI_API_KEY is not configured.")


async def summarize_ingredient(inci_name: str, base_info: Dict[str, object]) -> str:
    _require_client()
    concerns = base_info.get("concerns", [])
    concerns_text = "; ".join(str(item) for item in concerns) if concerns else "No specific concerns noted."

    try:
        response = await client.chat.completions.create(
            model=MODEL_NAME,
            response_format={"type": "json_object"},
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are a cosmetics ingredient assistant. You provide concise, neutral, and non-medical summaries of "
                        "ingredient risks. Do not give medical advice."
                    ),
                },
                {
                    "role": "user",
                    "content": (
                        "Summarize this ingredient for general skin safety."
                        " Return JSON with a 'summary' field only.\n"
                        f"INCI: {inci_name}\n"
                        f"Function: {base_info.get('function', 'unknown')}\n"
                        f"Origin: {base_info.get('origin')}\n"
                        f"Risk level: {base_info.get('risk_level', 'unknown')}\n"
                        f"Concerns: {concerns_text}\n"
                        "Keep it short and neutral."
                    ),
                },
            ],
            temperature=0.2,
        )
    except Exception as exc:  # pragma: no cover - external call
        raise HTTPException(status_code=502, detail="OpenAI ingredient summary failed.") from exc

    content = response.choices[0].message.content
    if not content:
        raise HTTPException(status_code=500, detail="Empty response from OpenAI.")

    try:
        parsed = json.loads(content)
        return str(parsed.get("summary", "No summary provided."))
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=500, detail="Failed to parse OpenAI ingredient summary.") from exc


async def summarize_product(product_name: str, ingredients: List[Dict[str, object]]) -> Dict[str, str]:
    _require_client()
    ingredient_list = ", ".join(item.get("inciName", "") for item in ingredients)
    try:
        response = await client.chat.completions.create(
            model=MODEL_NAME,
            response_format={"type": "json_object"},
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are assessing cosmetics for general skin suitability. Provide conservative, neutral summaries and "
                        "do not offer medical or dermatological advice."
                    ),
                },
                {
                    "role": "user",
                    "content": (
                        "Given this product and its ingredients, return JSON with fields overallScore (A/B/C/D) and "
                        "overallSummary (1-2 sentences).\n"
                        f"Product: {product_name}\n"
                        f"Ingredients: {ingredient_list}"
                    ),
                },
            ],
            temperature=0.3,
        )
    except Exception as exc:  # pragma: no cover - external call
        raise HTTPException(status_code=502, detail="OpenAI product summary failed.") from exc

    content = response.choices[0].message.content
    if not content:
        raise HTTPException(status_code=500, detail="Empty response from OpenAI.")

    try:
        parsed = json.loads(content)
        return {
            "overallScore": str(parsed.get("overallScore", "B")),
            "overallSummary": str(
                parsed.get(
                    "overallSummary",
                    "General cosmetic profile with no specific medical claims.",
                )
            ),
        }
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=500, detail="Failed to parse OpenAI product summary.") from exc
