# Job Posting – Candidate Matching Engine

**English** | [Türkçe](README.tr.md)

An AI-powered job posting and candidate matching system built on n8n workflow
automation. Candidate CVs and job postings are converted into vectors, matched by
semantic similarity, and suitable candidates receive an explanatory e-mail
generated with Gemini. All components run on Docker, on your own server.

## Architecture

```
Web UI (nginx) ──► n8n webhooks ──► Ollama (nomic-embed-text, 768 dimensions)
                          │
                          ▼
            PostgreSQL + pgvector (candidates, jobs, matches)
                          │
   Daily at 09:00 ─► cosine similarity ≥ 0.75 ─► Gemini 2.5 Flash ─► Gmail SMTP
```

| Component | Role |
|---|---|
| **n8n** | Webhook-based registration/listing flows and the scheduled matching flow |
| **PostgreSQL + pgvector** | Storing CV and job vectors, similarity queries |
| **Ollama** | Local embedding model |
| **Google Gemini** | CV/job summaries and match explanations |
| **Frontend** | Candidate and job registration, listing matches |

## Webhook Endpoints

`register-candidate`, `register-job`, `list-candidates`, `list-jobs`, `list-matches`
— all protected with an `X-API-Key` header.

## Setup

Requirements: Docker Desktop, Ollama, a Gmail account with 2-step verification
enabled (for an SMTP app password) and a Gemini API key.

```bash
ollama pull nomic-embed-text
cp .env.example .env        # fill in your own values
docker compose up -d
```

| Service | Address |
|---|---|
| Web UI | http://localhost:3000 |
| n8n | http://localhost:5678 |
| PostgreSQL | localhost:5432 |

The database schema (`db/init.sql`) is applied automatically when PostgreSQL starts
for the first time. The `API_KEY` value in `frontend/index.html` must match
`N8N_API_KEY` in the `.env` file.

## Documentation

Project report: [English](docs/job-candidate-matching-report-EN.docx) ·
[Türkçe](docs/is-ilani-aday-eslestirme-rapor-TR.docx)
