# İş İlanı – Aday Eşleştirme Motoru

[English](README.md) | **Türkçe**

n8n iş akışı otomasyonu üzerine kurulu, yapay zekâ destekli bir iş ilanı ve aday
eşleştirme sistemi. Adayların CV'leri ve iş ilanları vektörlere dönüştürülür,
anlamsal benzerliğe göre eşleştirilir ve uygun adaylara Gemini ile üretilmiş
açıklamalı bir e-posta gönderilir. Tüm bileşenler Docker üzerinde, kendi
sunucunuzda çalışır.

## Mimari

```
Web arayüzü (nginx) ──► n8n webhook'ları ──► Ollama (nomic-embed-text, 768 boyut)
                                   │
                                   ▼
                     PostgreSQL + pgvector (adaylar, ilanlar, eşleşmeler)
                                   │
            Her gün 09:00 ─► kosinüs benzerliği ≥ 0.75 ─► Gemini 2.5 Flash ─► Gmail SMTP
```

| Bileşen | Görev |
|---|---|
| **n8n** | Webhook tabanlı kayıt/listeleme akışları ve zamanlanmış eşleştirme akışı |
| **PostgreSQL + pgvector** | CV ve ilan vektörlerinin saklanması, benzerlik sorguları |
| **Ollama** | Yerel embedding modeli |
| **Google Gemini** | CV/ilan özetleri ve eşleşme açıklaması üretimi |
| **Frontend** | Aday ve ilan kaydı, eşleşmelerin listelenmesi |

## Webhook Uç Noktaları

`register-candidate`, `register-job`, `list-candidates`, `list-jobs`, `list-matches`
— tümü `X-API-Key` başlığı ile korunur.

## Kurulum

Gereksinimler: Docker Desktop, Ollama, 2 adımlı doğrulaması açık bir Gmail hesabı
(SMTP uygulama şifresi için) ve bir Gemini API anahtarı.

```bash
ollama pull nomic-embed-text
cp .env.example .env        # değerleri kendi bilgilerinizle doldurun
docker compose up -d
```

| Servis | Adres |
|---|---|
| Web arayüzü | http://localhost:3000 |
| n8n | http://localhost:5678 |
| PostgreSQL | localhost:5432 |

Veritabanı şeması (`db/init.sql`) PostgreSQL ilk açıldığında otomatik uygulanır.
Web arayüzü ilk istekte API anahtarını sorar; `.env` dosyasındaki
`N8N_API_KEY` değerini girin. Anahtar koda yazılmaz, yalnızca o tarayıcı
sekmesinde (`sessionStorage`) tutulur ve yanlışsa yeniden sorulur.

> **Not:** Bu yapı yerel geliştirme içindir. Arayüzü herkese açık bir sunucuda
> yayınlayacaksanız anahtar tarayıcıya hiç gönderilmemeli; istekleri anahtarı
> sunucu tarafında ekleyen bir ara katman (ör. nginx `proxy_set_header`)
> üzerinden geçirin.

## Eşleşme Mantığı ve Testler

Eşleşme kuralı veritabanında `find_new_matches(min_score)` fonksiyonudur
(`db/init.sql`): aktif ilanlar × adaylar arasında kosinüs benzerliği eşiği
(varsayılan 0.75) geçen, `matches` tablosunda henüz kaydı olmayan ve vektörü boş
ya da sıfır olmayan çiftler, en yüksek skor önce. N8n akışı
`SELECT * FROM find_new_matches(0.75);` çağırır. Bir çift yalnızca bir kez
kaydedilebilir (`candidate_id, job_id` üzerinde benzersiz indeks); böylece aynı ilan için adaya iki kez e-posta gitmez.

```bash
docker compose up -d --wait postgres
docker compose exec -T postgres psql -U postgres -d jobmatching -v ON_ERROR_STOP=1 -f - < tests/matching_test.sql
```

GitHub Actions her push'ta `docker-compose.yml` dosyasını doğrular ve bu testleri çalıştırır.

> **Mevcut veritabanı:** `init.sql` yalnızca ilk açılışta çalışır. Yeni fonksiyonu
> ve indeksleri var olan bir volume'a uygulamak için önce eski ivfflat indekslerini
> silin (`DROP INDEX candidates_embedding_idx, jobs_embedding_idx;`), sonra
> `docker compose exec -T postgres psql -U postgres -d jobmatching -f - < db/init.sql`
> çalıştırın. `matches` tablosunda tekrarlanan çiftler varsa önce onları silin;
> yoksa benzersiz indeks oluşturulamaz.

## Dokümantasyon

Proje raporu (PDF): [Türkçe](docs/is-ilani-aday-eslestirme-rapor-TR.pdf) ·
[English](docs/job-candidate-matching-report-EN.pdf)
— düzenlenebilir sürümler: [TR .docx](docs/is-ilani-aday-eslestirme-rapor-TR.docx) ·
[EN .docx](docs/job-candidate-matching-report-EN.docx)
