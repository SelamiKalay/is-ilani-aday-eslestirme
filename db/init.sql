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

-- Aynı aday-ilan çifti iki kez kaydedilip iki kez e-posta gitmesin.
-- Tablo tanımı yerine ayrı indeks: init.sql var olan veritabanına yeniden
-- uygulandığında da eklenir (CREATE TABLE IF NOT EXISTS mevcut tabloyu değiştirmez).
CREATE UNIQUE INDEX IF NOT EXISTS matches_candidate_job_key
  ON matches (candidate_id, job_id);

-- Performans indeksleri
-- HNSW: ivfflat kümelerini indeks oluşturulduğu andaki veriden öğrenir; tablo
-- boşken (bu dosya her zaman boş veritabanında çalışır) kurulan ivfflat
-- indeksi en yakın komşu sorgularında yanlış sonuç döndürür. HNSW veri
-- gerektirmez.
CREATE INDEX IF NOT EXISTS candidates_embedding_idx
  ON candidates USING hnsw (embedding vector_cosine_ops);

CREATE INDEX IF NOT EXISTS jobs_embedding_idx
  ON jobs USING hnsw (embedding vector_cosine_ops);

-- Eşleşme mantığı: aktif ilan × aday çiftlerinden kosinüs benzerliği eşiği
-- geçen ve daha önce kaydedilmemiş olanlar, en yüksek skor önce.
-- N8n akışında: SELECT * FROM find_new_matches(0.75);
CREATE OR REPLACE FUNCTION find_new_matches(min_score FLOAT DEFAULT 0.75)
RETURNS TABLE (candidate_id INT, job_id INT, score FLOAT)
LANGUAGE sql STABLE AS $$
  SELECT c.id, j.id, 1 - (c.embedding <=> j.embedding)
  FROM candidates c
  JOIN jobs j ON j.is_active
  WHERE c.embedding IS NOT NULL
    AND j.embedding IS NOT NULL
    -- sıfır vektörde mesafe NaN olur; NaN >= eşik PostgreSQL'de doğru sayıldığı için açıkça elenir
    AND (c.embedding <=> j.embedding) <> 'NaN'
    AND 1 - (c.embedding <=> j.embedding) >= min_score
    AND NOT EXISTS (
      SELECT 1 FROM matches m WHERE m.candidate_id = c.id AND m.job_id = j.id
    )
  ORDER BY 3 DESC, c.id, j.id
$$;
