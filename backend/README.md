# JanMitra AI – Backend Foundation (Milestone 1)

Production-ready FastAPI backend with PostgreSQL authentication serving as the foundation for the **JanMitra AI** Public Grievance Intelligence and Administrative Decision Support Platform.

---

## 🏗 System Architecture

```
backend/
├── app/
│   ├── main.py                  # FastAPI Application Entry Point
│   ├── core/                    # Security (JWT, Bcrypt) & Config (Pydantic Settings)
│   ├── database/                # Async SQLAlchemy 2.x Session & Engine
│   ├── models/                  # SQLAlchemy ORM Models (Users Table)
│   ├── schemas/                 # Pydantic v2 Validation Schemas
│   ├── repositories/            # Async Repository Pattern
│   ├── services/                # Business Logic Layer (AuthService)
│   ├── dependencies/            # FastAPI Dependency Injection & OAuth2 Bearer
│   ├── routers/                 # API Endpoint Controllers (/api/v1/auth)
│   ├── ai/                      # Placeholder for AI Analysis Engine
│   ├── ocr/                     # Placeholder for OCR Document Processor
│   ├── legal/                   # Placeholder for Legal Retrieval & RAG System
│   └── routing/                 # Placeholder for Department Triage Engine
├── alembic/                     # Database Migration Scripts
├── alembic.ini                  # Alembic Migration Configuration
├── requirements.txt             # Python Package Dependencies
├── .env.example                 # Environment Variable Template
└── README.md                    # Project Documentation
```

---

## ⚡ Quick Start

### 1. Prerequisites
- Python 3.13+
- PostgreSQL 16+ running on `localhost:5432` with database `janmitra_ai` created.

### 2. Environment Setup
Create a `.env` file in `backend/`:
```env
PROJECT_NAME="JanMitra AI"
API_V1_STR="/api/v1"
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_SERVER=localhost
POSTGRES_PORT=5432
POSTGRES_DB=janmitra_ai
DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5432/janmitra_ai
SYNC_DATABASE_URL=postgresql+psycopg2://postgres:postgres@localhost:5432/janmitra_ai
SECRET_KEY=janmitra_ai_super_secret_jwt_key_2026_change_in_production_12345
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=1440
REFRESH_TOKEN_EXPIRE_MINUTES=10080
CORS_ORIGINS=["http://localhost","http://localhost:3000","http://localhost:8000","*"]
```

### 3. Install Dependencies
```bash
cd backend
pip install -r requirements.txt
```

### 4. Run Database Migrations
```bash
# Generate initial migration
alembic revision --autogenerate -m "create users table"

# Apply migrations to PostgreSQL
alembic upgrade head
```

### 5. Launch FastAPI Server
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Access Swagger Documentation at: `http://localhost:8000/docs`

---

## 🔑 Authentication Endpoints (/api/v1/auth)

| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `POST` | `/api/v1/auth/register` | Register a new citizen account | No |
| `POST` | `/api/v1/auth/login` | Authenticate credentials & issue JWT tokens | No |
| `GET` | `/api/v1/auth/me` | Fetch authenticated user profile | Yes (Bearer JWT) |
| `POST` | `/api/v1/auth/logout` | Stateless JWT logout strategy | Yes (Bearer JWT) |
