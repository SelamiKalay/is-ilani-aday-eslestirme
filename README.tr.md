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
`frontend/index.html` içindeki `API_KEY` değeri `.env` dosyasındaki
`N8N_API_KEY` ile aynı olmalıdır.

## Dokümantasyon

Proje raporu: [Türkçe](docs/is-ilani-aday-eslestirme-rapor-TR.docx) ·
[English](docs/job-candidate-matching-report-EN.docx)
