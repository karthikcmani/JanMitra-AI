import json
import logging
import math
import os
import re
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.grievance_model import KnowledgeChunk, KnowledgeDocument

logger = logging.getLogger(__name__)

# Lightweight zero-cost vector embedding & similarity provider
_sentence_transformer_model = None


def get_embedding_model():
    global _sentence_transformer_model
    if _sentence_transformer_model is None:
        try:
            from sentence_transformers import SentenceTransformer
            _sentence_transformer_model = SentenceTransformer("all-MiniLM-L6-v2")
            logger.info("Loaded SentenceTransformer model 'all-MiniLM-L6-v2'")
        except Exception as e:
            logger.info(f"SentenceTransformers unavailable ({e}). Using normalized TF-IDF vectorizer fallback.")
            _sentence_transformer_model = "fallback"
    return _sentence_transformer_model


def compute_vector(text: str) -> List[float]:
    """Generates a dense vector embedding for text using SentenceTransformers or zero-cost token vectorizer."""
    model = get_embedding_model()
    if model != "fallback" and model is not None:
        try:
            embedding = model.encode(text, normalize_embeddings=True)
            return embedding.tolist()
        except Exception as e:
            logger.warning(f"Embedding error: {e}")

    # Deterministic TF-IDF / Word Hash fallback vector (64 dimensions)
    words = re.findall(r"\w+", text.lower())
    vec = [0.0] * 64
    if not words:
        return vec
    for w in words:
        idx = hash(w) % 64
        vec[idx] += 1.0
    norm = math.sqrt(sum(x * x for x in vec))
    if norm > 0:
        vec = [round(x / norm, 4) for x in vec]
    return vec


def cosine_similarity(vec_a: List[float], vec_b: List[float]) -> float:
    """Computes cosine similarity between two vectors."""
    if not vec_a or not vec_b or len(vec_a) != len(vec_b):
        return 0.0
    dot = sum(a * b for a, b in zip(vec_a, vec_b))
    norm_a = math.sqrt(sum(a * a for a in vec_a))
    norm_b = math.sqrt(sum(b * b for b in vec_b))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return round(dot / (norm_a * norm_b), 4)


DEFAULT_GOVT_DOCUMENTS = [
    {
        "title": "Kerala Panchayat Raj Act, 1994 - Public Works & Water Supply",
        "document_type": "ACT",
        "department": "Local Self Government Department (LSGD)",
        "act_number_or_go_no": "Act 13 of 1994",
        "content_summary": "Statutory duties of Grama Panchayats regarding maintenance of village roads, public wells, street lighting, and sanitation.",
        "full_text": """
KERALA PANCHAYAT RAJ ACT, 1994 (Act 13 of 1994)
Section 166: Mandatory functions of Grama Panchayat
1. Maintenance and repair of village roads, bridges, culverts, and drainages under the jurisdiction of the Grama Panchayat.
2. Supply of wholesome drinking water, maintenance of public wells, ponds, and piped drinking water schemes in rural wards.
3. Collection and disposal of solid waste, maintenance of public sanitation, street light installation and repair.
4. Issue of building permits and trade licenses within Grama Panchayat boundaries.
Section 218: Transfer of water courses and public pathways to Grama Panchayats. All public water courses, springs, reservoirs, and public pathways vest in the Grama Panchayat for maintenance.
""",
    },
    {
        "title": "Kerala Water Authority Water Supply Regulations & Consumer Charter",
        "document_type": "REGULATION",
        "department": "Kerala Water Authority (KWA)",
        "act_number_or_go_no": "KWA Order No. 421/2018",
        "content_summary": "Service standards for drinking water connection, burst pipe repairs, contamination complaints, and billing disputes.",
        "full_text": """
KERALA WATER AUTHORITY WATER SUPPLY REGULATIONS
Rule 8: Repair of Main Supply Pipelines and Burst Leaks.
1. Any reported main pipeline burst or severe water leakage in public roads must be inspected within 12 hours of complaint registration by the Assistant Water Works Officer.
2. Rectification and restoration of disrupted drinking water supply must be completed within 24 to 48 hours.
3. In case of water contamination, alternative tanker drinking water must be arranged immediately by KWA in affected municipal wards.
Rule 15: Public Grievance Redressal Mechanism. Citizens may lodge complaints regarding non-supply, low pressure, inaccurate water meters, or pipe leakages to the Executive Engineer.
""",
    },
    {
        "title": "Kerala State Electricity Board (KSEB) Electricity Supply Code, 2014",
        "document_type": "REGULATION",
        "department": "Kerala State Electricity Board (KSEB)",
        "act_number_or_go_no": "KSERC Regulation 2014",
        "content_summary": "Response timelines for power outages, dangerous low-hanging lines, transformer failures, and damaged electric poles.",
        "full_text": """
KSEB ELECTRICITY SUPPLY CODE & CONSUMER GUARANTEE REGULATIONS
Section 45: Service Interruption & Power Line Hazards.
1. Dangerous low-hanging high voltage lines or leaning electric poles posing public safety hazards must be attended to immediately (within 4 hours of report).
2. Fuse-off calls and localized distribution transformer breakdowns in urban/rural areas must be restored within 6 to 12 hours.
3. Compensation to consumers for delayed restoration beyond statutory limits under Consumer Protection Rules.
Section 52: Shifting of electric poles for road widening projects upon application and estimated deposit.
""",
    },
    {
        "title": "Kerala Municipality Act, 1994 - Civic Infrastructure & Waste Management",
        "document_type": "ACT",
        "department": "Urban Affairs / Municipal Corporation",
        "act_number_or_go_no": "Act 20 of 1994",
        "content_summary": "Municipal responsibilities for drainage clearing, road maintenance, street lights, and illegal construction enforcement.",
        "full_text": """
KERALA MUNICIPALITY ACT, 1994 (Act 20 of 1994)
Section 207: Powers of Municipal Corporation / Council in respect of Municipal Roads and Stormwater Drains.
1. The Municipality is responsible for constructing and maintaining public drains, preventing stormwater stagnation, and repairing potholes on municipal roads.
2. Removal of encroachments on public footpaths and drain covers.
Section 334: Prevention of Public Nuisance, dangerous structures, and unhygienic accumulation of garbage.
Section 406: Demolition or alteration of unauthorized constructions erected in violation of municipal building rules.
""",
    },
    {
        "title": "Disaster Management Act, 2005 & Public Road Hazard Directives",
        "document_type": "ACT",
        "department": "Disaster Management / Public Works Department (PWD)",
        "act_number_or_go_no": "Central Act 53 of 2005 / GO(Rt) 890/2022",
        "content_summary": "Emergency intervention rules for landslide hazards, tree falls on public roads, bridge structural damage, and monsoon flood relief.",
        "full_text": """
DISASTER MANAGEMENT ACT & EMERGENCY PUBLIC HAZARD DIRECTIVES
Section 30: Powers of District Disaster Management Authority (DDMA) headed by District Collector.
1. Immediate clearance of fallen trees, landslides, or dangerous wall collapses blocking public transportation arteries.
2. Emergency repair orders issued to PWD (Public Works Department) and KWA for restoring essential public utility lines post-natural disaster.
3. Safety audits of public bridges and culverts prior to monsoon season.
""",
    },
]


class KnowledgeBaseService:
    """Manages legal knowledge documents, semantic chunking, and embedding vectors."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def seed_default_knowledge_base(self) -> int:
        """Seeds standard public Government Orders, Acts, and Regulations into database."""
        added_count = 0
        for doc_def in DEFAULT_GOVT_DOCUMENTS:
            existing = await self.db.execute(
                select(KnowledgeDocument).where(KnowledgeDocument.title == doc_def["title"])
            )
            if existing.scalar_one_or_none():
                continue

            doc = KnowledgeDocument(
                title=doc_def["title"],
                document_type=doc_def["document_type"],
                department=doc_def["department"],
                act_number_or_go_no=doc_def["act_number_or_go_no"],
                content_summary=doc_def["content_summary"],
                full_text=doc_def["full_text"].strip(),
                is_active=True,
            )
            self.db.add(doc)
            await self.db.flush()

            # Create semantic chunks
            paragraphs = [p.strip() for p in doc.full_text.split("\n") if p.strip()]
            chunk_idx = 0
            for para in paragraphs:
                if len(para) < 20:
                    continue
                chunk_idx += 1
                vec = compute_vector(para)
                chunk = KnowledgeChunk(
                    document_id=doc.id,
                    chunk_index=chunk_idx,
                    chunk_text=para,
                    section_title=f"{doc.title} - Sec {chunk_idx}",
                    embedding_json={"vector": vec},
                )
                self.db.add(chunk)

            doc.chunk_count = chunk_idx
            added_count += 1

        await self.db.commit()
        return added_count

    async def search_relevant_chunks(
        self, query_text: str, top_k: int = 4
    ) -> List[Dict[str, Any]]:
        """Performs vector similarity search against indexed government knowledge chunks."""
        # Ensure default documents exist
        await self.seed_default_knowledge_base()

        query_vec = compute_vector(query_text)
        res = await self.db.execute(select(KnowledgeChunk))
        all_chunks = res.scalars().all()

        scored_chunks = []
        for chunk in all_chunks:
            chunk_vec = (chunk.embedding_json or {}).get("vector", [])
            sim = cosine_similarity(query_vec, chunk_vec) if chunk_vec else 0.0

            # Text keyword boost for exact law terms
            lower_chunk = chunk.chunk_text.lower()
            lower_query = query_text.lower()
            if any(k in lower_chunk for k in ["water", "pipe", "road", "drain", "electric", "pole", "waste", "panchayat", "municipality"] if k in lower_query):
                sim = min(1.0, sim + 0.15)

            if sim > 0.1:
                # Fetch parent document details
                doc_res = await self.db.execute(
                    select(KnowledgeDocument).where(KnowledgeDocument.id == chunk.document_id)
                )
                parent_doc = doc_res.scalar_one_or_none()
                scored_chunks.append({
                    "chunk_id": chunk.id,
                    "document_title": parent_doc.title if parent_doc else "Government Document",
                    "document_type": parent_doc.document_type if parent_doc else "ACT",
                    "department": parent_doc.department if parent_doc else "LSGD",
                    "act_number_or_go_no": parent_doc.act_number_or_go_no if parent_doc else "",
                    "section_title": chunk.section_title,
                    "chunk_text": chunk.chunk_text,
                    "similarity_score": sim,
                })

        scored_chunks.sort(key=lambda x: x["similarity_score"], reverse=True)
        return scored_chunks[:top_k]
