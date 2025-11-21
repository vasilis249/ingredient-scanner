import json
import os
from typing import Any, Dict

from fastapi import HTTPException
from openai import AsyncOpenAI

MODEL_NAME = os.getenv("OPENAI_MODEL", "gpt-5.1")
client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))


async def analyze_ingredients_with_openai(ingredients_text: str, product_name: str) -> Dict[str, Any]:
    if not client.api_key:
        raise HTTPException(status_code=500, detail="OPENAI_API_KEY is not configured.")

    system_prompt = (
        "You are a food safety assistant. Given ingredient text, break it into individual ingredients, "
        "assess risk (low/medium/high) for common allergies and health concerns, and return a concise JSON response."
    )

    user_prompt = (
        "Analyze the following ingredients and respond strictly as JSON.\n"
        f"Product name: {product_name}\n"
        f"Ingredients: {ingredients_text}\n"
        "Return fields: productName (string), ingredients (array of objects with name, risk (low|medium|high), details), "
        "and overallScore (single letter like A/B/C/D)."
    )

    try:
        response = await client.chat.completions.create(
            model=MODEL_NAME,
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            temperature=0.2,
        )
    except Exception as exc:  # pragma: no cover - relies on external service
        raise HTTPException(status_code=502, detail="OpenAI analysis failed.") from exc

    message_content = response.choices[0].message.content
    if not message_content:
        raise HTTPException(status_code=500, detail="Empty response from OpenAI.")

    try:
        parsed = json.loads(message_content)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=500, detail="Failed to parse OpenAI response.") from exc

    return parsed
