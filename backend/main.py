from typing import Dict, List, Optional

from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel, Field

from openai_client import (
    is_openai_configured,
    summarize_ingredient,
    summarize_product,
)

app = FastAPI(title="Cosmetic Ingredient Scanner API")


@app.get("/health")
async def health() -> Dict[str, str]:
    return {"status": "ok"}

DISCLAIMER_TEXT = (
    "This analysis is informational only and not medical advice."
)

PRODUCT_CATALOG: Dict[str, Dict[str, object]] = {
    "4005900889089": {
        "product_name": "Gentle Daily Moisturizer",
        "ingredients_inci": [
            "AQUA",
            "GLYCERIN",
            "CETYL ALCOHOL",
            "PARFUM",
            "PHENOXYETHANOL",
        ],
    },
    "3606000430150": {
        "product_name": "SPF 50 Face Sunscreen",
        "ingredients_inci": [
            "AQUA",
            "C12-15 ALKYL BENZOATE",
            "ETHYLHEXYL METHOXYCINNAMATE",
            "TITANIUM DIOXIDE",
            "PARFUM",
        ],
    },
    "5012000000001": {
        "product_name": "Soothing Night Cream",
        "ingredients_inci": [
            "AQUA",
            "CAPRYLIC/CAPRIC TRIGLYCERIDE",
            "NIACINAMIDE",
            "PARFUM",
        ],
    },
}

INGREDIENT_DB: Dict[str, Dict[str, object]] = {
    "AQUA": {
        "function": "solvent",
        "origin": "mineral",
        "risk_level": "low",
        "concerns": [],
    },
    "GLYCERIN": {
        "function": "humectant",
        "origin": "plant-based",
        "risk_level": "low",
        "concerns": [],
    },
    "CETYL ALCOHOL": {
        "function": "emollient",
        "origin": "plant-based",
        "risk_level": "low",
        "concerns": ["generally well-tolerated fatty alcohol"],
    },
    "PARFUM": {
        "function": "fragrance",
        "origin": "synthetic",
        "risk_level": "medium",
        "concerns": ["fragrance allergens", "potential irritation"],
    },
    "PHENOXYETHANOL": {
        "function": "preservative",
        "origin": "synthetic",
        "risk_level": "medium",
        "concerns": ["may irritate sensitive skin at higher levels"],
    },
    "C12-15 ALKYL BENZOATE": {
        "function": "emollient",
        "origin": "synthetic",
        "risk_level": "low",
        "concerns": [],
    },
    "ETHYLHEXYL METHOXYCINNAMATE": {
        "function": "UV filter",
        "origin": "synthetic",
        "risk_level": "medium",
        "concerns": ["possible photoallergy in sensitive individuals"],
    },
    "TITANIUM DIOXIDE": {
        "function": "UV filter",
        "origin": "mineral",
        "risk_level": "low",
        "concerns": ["avoid inhalation of loose powders"],
    },
    "CAPRYLIC/CAPRIC TRIGLYCERIDE": {
        "function": "emollient",
        "origin": "plant-based",
        "risk_level": "low",
        "concerns": [],
    },
    "NIACINAMIDE": {
        "function": "skin conditioning",
        "origin": "synthetic",
        "risk_level": "low",
        "concerns": ["rare flushing in very high concentrations"],
    },
}


class IngredientRisk(BaseModel):
    inciName: str
    function: str
    origin: Optional[str]
    riskLevel: str
    concerns: List[str]
    aiSummary: str


class ProductAnalysisResponse(BaseModel):
    productName: str
    barcode: str
    ingredients: List[IngredientRisk]
    overallScore: str
    overallSummary: str
    disclaimer: str = Field(default=DISCLAIMER_TEXT)


def normalize_inci(name: str) -> str:
    return name.strip().upper()


def lookup_product_by_barcode(barcode: str) -> Optional[Dict[str, object]]:
    return PRODUCT_CATALOG.get(barcode)


def lookup_ingredient(inci_name: str) -> Dict[str, object]:
    normalized = normalize_inci(inci_name)
    base_info = INGREDIENT_DB.get(normalized)
    if base_info:
        return {
            "inci_name": normalized,
            "function": base_info.get("function", "unknown"),
            "origin": base_info.get("origin"),
            "risk_level": base_info.get("risk_level", "unknown"),
            "concerns": base_info.get("concerns", []),
        }

    return {
        "inci_name": normalized,
        "function": "unknown",
        "origin": None,
        "risk_level": "unknown",
        "concerns": ["Not found in knowledge base"],
    }


def fallback_summary(base_info: Dict[str, object]) -> str:
    inci = base_info.get("inci_name", "Ingredient")
    risk = base_info.get("risk_level", "unknown")
    concerns = base_info.get("concerns", [])
    if concerns:
        concerns_text = "; ".join(str(item) for item in concerns)
    else:
        concerns_text = "No notable concerns recorded."
    return f"{inci} is labeled {risk} risk. {concerns_text}"


def fallback_overall(ingredients: List[IngredientRisk]) -> Dict[str, str]:
    risk_map = {"high": 3, "medium": 2, "low": 1, "unknown": 2}
    if not ingredients:
        return {"overallScore": "B", "overallSummary": "No ingredients provided for scoring."}

    avg_score = sum(risk_map.get(item.riskLevel.lower(), 2) for item in ingredients) / len(ingredients)
    if avg_score >= 2.5:
        score = "C"
        summary = "Contains ingredients that may warrant caution for sensitive skin."
    elif avg_score >= 1.8:
        score = "B"
        summary = "Generally moderate profile with some potential irritants."
    else:
        score = "A"
        summary = "Low-risk profile based on known ingredients."

    return {"overallScore": score, "overallSummary": summary}


@app.get("/cosmetics/analyze", response_model=ProductAnalysisResponse)
async def analyze_cosmetic(barcode: str = Query(..., description="Barcode to look up")):
    product = lookup_product_by_barcode(barcode)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found in cosmetics catalog.")

    ingredients: List[IngredientRisk] = []
    for inci in product.get("ingredients_inci", []):
        base_info = lookup_ingredient(inci)
        ai_summary = fallback_summary(base_info)

        if is_openai_configured():
            ai_summary = await summarize_ingredient(inci_name=inci, base_info=base_info)

        ingredients.append(
            IngredientRisk(
                inciName=base_info.get("inci_name", inci),
                function=base_info.get("function", "unknown"),
                origin=base_info.get("origin"),
                riskLevel=base_info.get("risk_level", "unknown"),
                concerns=[str(item) for item in base_info.get("concerns", [])],
                aiSummary=ai_summary,
            )
        )

    if is_openai_configured():
        overall = await summarize_product(
            product_name=str(product.get("product_name", "Unknown product")),
            ingredients=[ingredient.dict() for ingredient in ingredients],
        )
        overall_score = overall.get("overallScore", "B")
        overall_summary = overall.get("overallSummary", "Moderate risk profile.")
    else:
        fallback = fallback_overall(ingredients)
        overall_score = fallback["overallScore"]
        overall_summary = fallback["overallSummary"]

    return ProductAnalysisResponse(
        productName=str(product.get("product_name", "Unknown product")),
        barcode=barcode,
        ingredients=ingredients,
        overallScore=overall_score,
        overallSummary=overall_summary,
        disclaimer=DISCLAIMER_TEXT,
    )
