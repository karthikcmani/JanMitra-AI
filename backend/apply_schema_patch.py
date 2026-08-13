import asyncio
from sqlalchemy import text
from app.database.session import engine

async def apply_patch():
    print("Applying schema patch for department routing & analysis tables...")
    async with engine.begin() as conn:
        await conn.execute(text("ALTER TABLE grievances ADD COLUMN IF NOT EXISTS category VARCHAR(150);"))
        await conn.execute(text("ALTER TABLE grievances ADD COLUMN IF NOT EXISTS department_id VARCHAR(150);"))
        await conn.execute(text("""
            CREATE TABLE IF NOT EXISTS grievance_analysis (
                id VARCHAR(36) PRIMARY KEY,
                grievance_id VARCHAR(36) NOT NULL REFERENCES grievances(id) ON DELETE CASCADE,
                extracted_entities JSON,
                predicted_category VARCHAR(150),
                legal_grounding_references JSON,
                ai_explanation TEXT,
                created_at TIMESTAMP WITH TIME ZONE NOT NULL
            );
        """))
    print("Schema patch applied successfully!")

if __name__ == "__main__":
    asyncio.run(apply_patch())
