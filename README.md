# Resepsiyonistim — Onboarding Sistemi

> AI resepsiyonistin hatasız, insansı ve güvenilir çalışması için işletme verilerinin %100 doğru ve eksiksiz girilmesini sağlayan onboarding sistemi.

---

## 🎯 Neden Onboarding Kritik?

AI resepsiyonist (Elif) sadece ona verilen verilerle cevap verebilir. Onboarding'te eksik veya yanlış bir bilgi:

| Eksik Veri | Sonuç |
|------------|-------|
| Fiyat girilmemiş | AI fiyat sorusunu "sizi yetkili ekibe yönlendireyim" ile geçiştirir |
| İptal politikası yok | AI iptal sorularında halüsinasyon üretir → güven kaybı |
| Birim tipi/kapasite eksik | AI yanlış grup kapasitesi söyler → overbooking |
| Ödeme/IBAN eksik | AI kapora sürecini tamamlayamaz → rezervasyon düşer |
| Karşılama mesajı yok | AI geneik "Merhaba" der — kişiselleştirme yok |

**Kural:** Onboarding tamamlanmadan panel erişimi yoktur (binary gate). AI etkinleştirme ancak 12/12 adım tamamlanınca gerçekleşir.

---

## 📋 Mevcut 12 Adımlı Onboarding Akışı

| # | Adım | Temel Alanlar | Validasyon |
|---|------|---------------|-----------|
| 1 | **İşletme Bilgileri** | businessName, businessType, address, city, phone, whatsappNumber, email | Zod: min 2 karakter, email format, telefon min 10 |
| 2 | **Konum ve Ulaşım** | lat/lng, directions, parkingInfo, parkingAvailable | Zod: lat -90/90, lng -180/180, directions min 10 |
| 3 | **Birim Tipleri** | unit[]: name, description, capacity, count, basePrice, weekendPrice, amenities | Zod: capacity 1-20, count 1-50, basePrice ≥ 1 |
| 4 | **Fiyatlandırma** | currency, seasonalAdjustments[], minimumStayNights | Zod: currency enum, multiplier 0.1-10 |
| 5 | **Özel Özellikler** | jacuzzi, pool, wifi, ac, kitchen, bbq, garden, tv, fireplace, washingMachine, petFriendly | En az 1 özellik zorunlu |
| 6 | **Kurallar** | checkInTime, checkOutTime, petPolicy, smokingPolicy, quietHours, additionalRules | Zod: enum policy |
| 7 | **İptal Politikası** | policyType (flexible/moderate/strict/custom), freeCancellationDays, refundPercentages[] | Zod: discriminated union |
| 8 | **Depozito ve Ödeme** | depositPercentage, depositType, iban, bankName, accountHolder, paymentMethods[] | Zod: IBAN min 10, bank min 2 |
| 9 | **Çevre Bilgileri** | nearbyMarkets, nearbyRestaurants, nearbyAttractions, nearbyTransport, distances | En az 1 alan dolu |
| 10 | **Acil Durum** | emergencyContactName, emergencyContactPhone, nearestHospital, nearestPolice, fireDepartment | Zod: min 2 ad, min 10 telefon |
| 11 | **Kişisel Karşılama** | greetingMessage, personaName, personaTone (formal/friendly/warm), welcomeNote, autoReplyEnabled | Zod: greetingMessage min 10 |
| 12 | **Onay ve Yayınla** | Summary review, activate | Binary gate kontrolü |

---

## 🔄 Veri Akışı: Onboarding → AI Prompt

```
Onboarding Form (Next.js)
  ↓
Supabase: bungalows.onboarding_progress (JSONB)
  ↓
onboarding_steps tablosu (12 satır, her adım için 1)
  ↓
12/12 tamam → activate_business() RPC → onboarding_completed = true
  ↓
Binary Gate: panel erişimi açılır
  ↓
WF02 (n8n): Supabase REST API → bungalows row fetch
  ↓
canonical_business_info constructed:
  {
    businessName, businessType, receptionistName,
    units[], pricing, amenities, rules, policies,
    deposit, iban, checkIn/out, surroundings
  }
  ↓
AI System Prompt (${bizName}, ${bizType}, ${receptionistName})
  ↓
Validation layers:
  - Price/Availability: pricing_result var mı?
  - Reliability: policy_source var mı?
  - Persona: personaName tutarlı mı?
  ↓
9Router API: ocg/qwen3.7-plus → yanıt
```

### Eksik veri olduğunda ne olur?

1. **Fiyat yok** → `Validate Price & Availability` node'u attribute reddeder → AI "fiyat için size-yardımcı-olayım" fallback
2. **İptal politikası yok** → `Reliability Guardrails` node'u `missing_policy_source` reddeder → handoff
3. **Karşılama mesajı yok** → AI geneik "Merhaba, hoş geldiniz" der → kişiselleştirme yok
4. **Birim tipi yok** → `canonical_business_info.units` boş → AI oda öneremez → handoff

---

## 🚧 Binary Gate Pattern

```
activate_business(p_business_id)
  → 12/12 adım kontrolü
  → TAMSA → onboarding_completed = true
  → activate_wf02() → tenant_settings.ai_enabled = true
  → workflow_events log
  → EKSİK → RAISE EXCEPTION
```

**Güvenlik:** RLS aktif. Owner sadece kendi adımlarını görebilir/güncelleyebilir.

---

## 📁 Bu Repoda Neler Var?

| Dosya | İçerik |
|-------|--------|
| `README.md` | Bu dosya — genel bakış |
| `onboarding-spec.md` | 12 adımın detaylı spesifikasyonu (alanlar, tipler, validasyon, UI mapping) |
| `data-flow.md` | Veri akışı diyagramı + Supabase şeması + RPC fonksiyonları |
| `improvements.md` | Önerilen iyileştirmeler: smart defaults, AI preview, completeness score, data quality checks |
| `supabase-schema.sql` | Tam SQL schema (bungalows, onboarding_steps, RPC'ler, RLS) |
| `validation-schemas.ts` | Zod validation şemaları (mevcut + yeni iyileştirmeler) |
| `types.ts` | TypeScript tip tanımları (OnboardingData, 12 adım interface'leri) |
| `ai-prompt-mapping.md` | Onboarding alanı → AI prompt değişkeni → guardrail eşleştirme tablosu |

---

## 🔗 İlgili Repolar

| Repo | İçerik |
|------|--------|
| `mermancloud-cmd/resepsiyonistim` | Ana Next.js panel (PRIVATE) |
| `mermancloud-cmd/resepsiyonistim-ai-conversation` | AI konuşma sistemi, system prompt, state machine (PRIVATE) |
| `mermancloud-cmd/resepsiyonistim-hermes-context` | Hermes oturum bağlamı (PRIVATE) |