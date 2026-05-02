-- Bu dosya PostgreSQL container ilk başladığında otomatik çalışır.
-- docker-entrypoint-initdb.d/ klasörüne mount edilir.

CREATE EXTENSION IF NOT EXISTS vector;

-- Adaylar tablosu (768 boyut — Ollama nomic-embed-text)
CREATE TABLE IF NOT EXISTS candidates (
  id          SERIAL PRIMARY KEY,
  name        TEXT NOT NULL,
  email       TEXT UNIQUE NOT NULL,
  raw_cv      TEXT,
  cv_summary  TEXT,
  embedding   VECTOR(768),
  created_at  TIMESTAMP DEFAULT NOW()
);

-- İş ilanları tablosu
CREATE TABLE IF NOT EXISTS jobs (
  id           SERIAL PRIMARY KEY,
  company      TEXT NOT NULL,
  position     TEXT NOT NULL,
  description  TEXT,
  job_summary  TEXT,
  embedding    VECTOR(768),
  is_active    BOOLEAN DEFAULT TRUE,
  created_at   TIMESTAMP DEFAULT NOW()
);

-- Eşleşme sonuçları tablosu
CREATE TABLE IF NOT EXISTS matches (
  id           SERIAL PRIMARY KEY,
  candidate_id INT REFERENCES candidates(id),
  job_id       INT REFERENCES jobs(id),
  score        FLOAT,
  explanation  TEXT,
  notified_at  TIMESTAMP,
  created_at   TIMESTAMP DEFAULT NOW()
);

-- Performans indeksleri
CREATE INDEX IF NOT EXISTS candidates_embedding_idx
  ON candidates USING ivfflat (embedding vector_cosine_ops);

CREATE INDEX IF NOT EXISTS jobs_embedding_idx
  ON jobs USING ivfflat (embedding vector_cosine_ops);
