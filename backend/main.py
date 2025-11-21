from typing import List

import httpx
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from openai_client import analyze_ingredients_with_openai

app = FastAPI(title="Ingredient Scanner API")

OPEN_FOOD_FACTS_URL = "https://world.openfoodfacts.org/api/v0/product/{barcode}.json"


class Ingredient(BaseModel):
    name: str
    risk: str
    details: str


class ProductAnalysis(BaseModel):
    productName: str
    ingredients: List[Ingredient]
    overallScore: str


async def fetch_product_from_open_food_facts(barcode: str) -> dict:
    url = OPEN_FOOD_FACTS_URL.format(barcode=barcode)
    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.get(url)
        if response.status_code != 200:
            raise HTTPException(status_code=502, detail="Failed to reach Open Food Facts.")
        return response.json()


@app.get("/analyze", response_model=ProductAnalysis)
async def analyze(barcode: str = Query(..., description="Barcode to look up")):
    product_response = await fetch_product_from_open_food_facts(barcode)

    if product_response.get("status") != 1:
        raise HTTPException(status_code=404, detail="Product not found in Open Food Facts.")

    product = product_response.get("product", {})
    product_name = product.get("product_name") or product.get("product_name_en") or "Unknown product"
    ingredients_text = product.get("ingredients_text") or product.get("ingredients_text_en")

    if not ingredients_text:
        return JSONResponse(
            status_code=200,
            content={
                "productName": product_name,
                "ingredients": [],
                "overallScore": "N/A",
                "message": "Ingredients not available for this product.",
            },
        )

    try:
        analysis = await analyze_ingredients_with_openai(ingredients_text=ingredients_text, product_name=product_name)
    except HTTPException:
        raise
    except Exception as exc:  # pragma: no cover - defensive
        raise HTTPException(status_code=500, detail="Failed to analyze ingredients.") from exc

    return analysis
