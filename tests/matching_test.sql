-- Eşleşme mantığı testleri. db/init.sql uygulanmış bir veritabanında çalışır:
--   psql -v ON_ERROR_STOP=1 -d jobmatching -f tests/matching_test.sql
-- Her şey bir işlem içinde yapılır ve sonunda geri alınır; veri kalmaz.
-- Başarısız bir ASSERT psql'i hata koduyla durdurur.

\set ON_ERROR_STOP on
BEGIN;

-- 768 boyutlu test vektörü: ilk iki bileşen (x, y), geri kalanı 0.
-- Kosinüs benzerliği yalnızca açıya bağlı olduğundan skorlar elle hesaplanabilir.
CREATE FUNCTION pg_temp.v(x FLOAT, y FLOAT) RETURNS vector LANGUAGE sql AS $$
  SELECT (ARRAY[x, y] || array_fill(0::float, ARRAY[766]))::real[]::vector
$$;

INSERT INTO candidates (id, name, email, embedding) VALUES
  (1, 'Ayni yon',   'a@test', pg_temp.v(1, 0)),     -- iş 1 ile benzerlik 1.0
  (2, 'Yakin',      'b@test', pg_temp.v(0.8, 0.6)), -- iş 1 ile 0.8
  (3, 'Uzak',       'c@test', pg_temp.v(0.6, 0.8)), -- iş 1 ile 0.6 (eşik altı)
  (4, 'Vektorsuz',  'd@test', NULL),
  (5, 'Sifir',      'e@test', pg_temp.v(0, 0));

INSERT INTO jobs (id, company, position, embedding, is_active) VALUES
  (1, 'Acme', 'Gelistirici', pg_temp.v(1, 0), TRUE),
  (2, 'Eski', 'Kapali ilan', pg_temp.v(1, 0), FALSE),
  (3, 'Yeni', 'Vektorsuz',   NULL,            TRUE);

DO $$
DECLARE
  got TEXT;
BEGIN
  -- Eşik, aktiflik, NULL ve sıfır vektör filtreleri; sıralama en yüksek skor önce
  SELECT string_agg(format('%s-%s:%s', candidate_id, job_id, round(score::numeric, 2)), ' ')
    INTO got FROM find_new_matches(0.75);
  ASSERT got = '1-1:1.00 2-1:0.80', format('varsayılan eşik: beklenen "1-1:1.00 2-1:0.80", gelen "%s"', got);

  -- Eşik parametresi
  SELECT string_agg(format('%s-%s', candidate_id, job_id), ' ') INTO got FROM find_new_matches(0.5);
  ASSERT got = '1-1 2-1 3-1', format('eşik 0.5: gelen "%s"', got);
  SELECT count(*) INTO got FROM find_new_matches(0.95);
  ASSERT got = '1', format('eşik 0.95: tek eşleşme beklenirken %s', got);

  -- Varsayılan eşik README'deki 0.75 ile aynı
  SELECT string_agg(format('%s-%s', candidate_id, job_id), ' ') INTO got FROM find_new_matches();
  ASSERT got = '1-1 2-1', format('parametresiz çağrı: gelen "%s"', got);

  -- Kaydedilmiş eşleşme tekrar önerilmez (aynı adaya iki kez e-posta gitmez)
  INSERT INTO matches (candidate_id, job_id, score) VALUES (1, 1, 1.0);
  SELECT string_agg(format('%s-%s', candidate_id, job_id), ' ') INTO got FROM find_new_matches(0.75);
  ASSERT got = '2-1', format('kayıtlı eşleşme elenmeli: gelen "%s"', got);

  -- Aynı çift ikinci kez eklenemez
  BEGIN
    INSERT INTO matches (candidate_id, job_id, score) VALUES (1, 1, 0.9);
    ASSERT FALSE, 'aynı aday-ilan çifti iki kez eklenebildi';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;
END $$;

-- İndeksli en yakın komşu sorgusu: boş tabloda kurulan indeks de doğru sonuç
-- vermeli (ivfflat burada kendisi yerine rastgele satırlar döndürüyordu)
INSERT INTO candidates (id, name, email, embedding)
SELECT 100 + g, 'r' || g, 'r' || g || '@test',
       pg_temp.v(cos(g * 0.05), sin(g * 0.05))
FROM generate_series(1, 60) g;

SET LOCAL enable_seqscan = off;
DO $$
DECLARE
  q CONSTANT TEXT := $q$
    SELECT email FROM candidates
    ORDER BY embedding <=> (SELECT embedding FROM candidates WHERE email = 'r30@test')
    LIMIT 3$q$;
  line TEXT;
  uses_index BOOLEAN := FALSE;
  got TEXT;
BEGIN
  FOR line IN EXECUTE 'EXPLAIN (COSTS OFF) ' || q LOOP
    uses_index := uses_index OR line LIKE '%candidates_embedding_idx%';
  END LOOP;
  ASSERT uses_index, 'en yakın komşu sorgusu vektör indeksini kullanmıyor';

  EXECUTE 'SELECT string_agg(email, '' '') FROM (' || q || ') s' INTO got;
  ASSERT got IN ('r30@test r29@test r31@test', 'r30@test r31@test r29@test'),
    format('en yakın komşular: gelen "%s"', got);
END $$;

ROLLBACK;
\echo 'Tüm eşleşme testleri geçti.'
