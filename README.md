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
for the first time. The web interface asks for the API key on the first request; enter the
`N8N_API_KEY` value from `.env`. The key is not stored in the code; it is kept
only in that browser tab (`sessionStorage`) and asked again if it is wrong.

> **Note:** This setup is meant for local development. If you publish the
> interface on a public server, the key should never reach the browser; route
> requests through a layer that adds the key on the server side (e.g. nginx
> `proxy_set_header`).

## Documentation

Project report (PDF): [English](docs/job-candidate-matching-report-EN.pdf) ·
[Türkçe](docs/is-ilani-aday-eslestirme-rapor-TR.pdf)
— editable versions: [EN .docx](docs/job-candidate-matching-report-EN.docx) ·
[TR .docx](docs/is-ilani-aday-eslestirme-rapor-TR.docx)
