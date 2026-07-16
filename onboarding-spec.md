# Onboarding 12 Adım — Detaylı Spesifikasyon

## Adım 1: İşletme Bilgileri

| Alan | Tip | Zorunlu | Validasyon | Default |
|------|-----|---------|-----------|---------|
| businessName | string | ✅ | min 2 karakter | — |
| businessType | enum | ✅ | bungalow, tiny_house, villa, hotel, pension, apartment | "bungalow" |
| address | string | ✅ | min 5 karakter | — |
| city | string | ✅ | min 2 karakter | — |
| phone | string | ✅ | min 10 karakter | — |
| whatsappNumber | string | ✅ | min 10 karakter | — |
| email | string | ✅ | email format | — |

**Zod:**
```typescript
businessInfoSchema = z.object({
  businessName: z.string().min(2, "İşletme adı en az 2 karakter olmalıdır"),
  businessType: z.enum(["bungalow", "tiny_house", "villa", "hotel", "pension", "apartment"]),
  address: z.string().min(5, "Adres en az 5 karakter olmalıdır"),
  city: z.string().min(2, "Şehir adı en az 2 karakter olmalıdır"),
  phone: z.string().min(10, "Geçerli bir telefon numarası giriniz"),
  whatsappNumber: z.string().min(10, "Geçerli bir WhatsApp numarası giriniz"),
  email: z.email("Geçerli bir e-posta adresi giriniz"),
})
```

**AI Etkisi:** `businessName` → `${bizName}` (system prompt), `businessType` → `${bizType}` (system prompt)

---

## Adım 2: Konum ve Ulaşım

| Alan | Tip | Zorunlu | Validasyon | Default |
|------|-----|---------|-----------|---------|
| latitude | number/null | ✅ | -90 ile 90 | null |
| longitude | number/null | ✅ | -180 ile 180 | null |
| directions | string | ✅ | min 10 karakter | — |
| parkingInfo | string | opsiyonel | — | — |
| parkingAvailable | boolean | — | — | true |

**AI Etkisi:** `directions` → `canonical_business_info.directions` → AI yol tarifi verebilir

---

## Adım 3: Birim Tipleri (Unit[])

| Alan | Tip | Zorunlu | Validasyon | Default |
|------|-----|---------|-----------|---------|
| id | string (UUID) | ✅ | crypto.randomUUID() | — |
| name | string | ✅ | min 2 karakter | — |
| description | string | opsiyonel | — | — |
| capacity | number | ✅ | 1-20 | 2 |
| count | number | ✅ | 1-50 | 1 |
| basePrice | number | ✅ | min 1 | 0 |
| weekendPrice | number | ✅ | min 0 | 0 |
| amenities | string[] | opsiyonel | — | [] |

**En az 1 birim zorunlu.** Array validasyonu: `unitsSchema = z.array(unitSchema).min(1)`

**AI Etkisi:** `units[]` → `canonical_business_info.units` → AI oda önerebilir, kapasite kontrolü yapabilir. `basePrice` → `pricing_result` → Price validation

---

## Adım 4: Fiyatlandırma

| Alan | Tip | Zorunlu | Validasyon | Default |
|------|-----|---------|-----------|---------|
| currency | enum | ✅ | TRY, EUR, USD | "TRY" |
| seasonalAdjustments[] | array | opsiyonel | name, startDate (MM-DD), endDate, multiplier (0.1-10) | [] |
| minimumStayNights | number | ✅ | min 1 | 1 |

**AI Etkisi:** `currency`, `basePrice` → Price validation layer. `minimumStayNights` → AI minimum konaklama kontrolü

---

## Adım 5: Özel Özellikler (Amenities)

| Alan | Tip | Default |
|------|-----|---------|
| jacuzzi | boolean | false |
| pool | boolean | false |
| bbq | boolean | true |
| kitchen | boolean | true |
| wifi | boolean | true |
| ac | boolean | true |
| parking | boolean | true |
| garden | boolean | true |
| tv | boolean | true |
| fireplace | boolean | false |
| washingMachine | boolean | false |
| petFriendly | boolean | false |

**Kural:** En az 1 özellik seçili olmalı: `.refine(data => Object.values(data).some(Boolean))`

**AI Etkisi:** Amenities → `canonical_business_info.amenities` → AI "jakuzi var mı?" sorusuna doğru yanıt. **Kritik:** AI uyduramaz, sadece bu listedeki bilgileri kullanır

---

## Adım 6: Kurallar

| Alan | Tip | Zorunlu | Validasyon | Default |
|------|-----|---------|-----------|---------|
| checkInTime | string | ✅ | format HH:MM | "14:00" |
| checkOutTime | string | ✅ | format HH:MM | "11:00" |
| petPolicy | enum | ✅ | allowed, not_allowed, on_request | "on_request" |
| petDetails | string | opsiyonel | — | — |
| smokingPolicy | enum | ✅ | allowed, not_allowed, outdoor_only | "outdoor_only" |
| smokingDetails | string | opsiyonel | — | — |
| quietHoursStart | string | ✅ | — | "22:00" |
| quietHoursEnd | string | ✅ | — | "08:00" |
| additionalRules | string | opsiyonel | — | — |

**AI Etkisi:** Rules → `Reliability Guardrails` → `policy_source` kontrolü. Eğer rules yoksa, AI check-in/pet/smoking sorularında handoff olur

---

## Adım 7: İptal Politikası

| Alan | Tip | Zorunlu | Validasyon | Default |
|------|-----|---------|-----------|---------|
| policyType | enum | ✅ | flexible, moderate, strict, custom (discriminated union) | "moderate" |
| freeCancellationDays | number | ✅ | min 1 | 7 |
| refundPercentages[] | array | ✅ | daysBefore, refundPercentage (0-100) | [{7, 100}, {3, 50}, {0, 0}] |
| customPolicy | string | custom ise zorunlu | min 10 karakter | — |

**AI Etkisi:** Cancellation → `canonical_business_info.policies` → AI iptal sorularında doğru iade yüzdesi verebilir

---

## Adım 8: Depozito ve Ödeme

| Alan | Tip | Zorunlu | Validasyon | Default |
|------|-----|---------|-----------|---------|
| depositPercentage | number | ✅ | 0-100 | 30 |
| depositType | enum | ✅ | percentage, fixed | "percentage" |
| depositFixedAmount | number | ✅ | min 0 | 0 |
| iban | string | ✅ | min 10 | — |
| bankName | string | ✅ | min 2 | — |
| accountHolder | string | ✅ | min 2 | — |
| paymentMethods[] | string[] | ✅ | min 1 | ["havale"] |

**AI Etkisi:** IBAN → `canonical_business_info.payment` → AI kapora sürecini yönetir. IBAN kontrolü → `Validate Price & Availability` (HG-004)

---

## Adım 9: Çevre Bilgileri

| Alan | Tip | Zorunlu |
|------|-----|---------|
| nearbyMarkets | string | opsiyonel |
| nearbyRestaurants | string | opsiyonel |
| nearbyAttractions | string | opsiyonel |
| nearbyTransport | string | opsiyonel |
| distanceToBeach | string | opsiyonel |
| distanceToAirport | string | opsiyonel |
| distanceToCenter | string | opsiyonel |

**Kural:** En az 1 alan dolu olmalı

**AI Etkisi:** Çevre bilgileri → AI "yakında market var mı?" sorusunu doğru yanıtlayabilir

---

## Adım 10: Acil Durum

| Alan | Tip | Zorunlu | Validasyon | Default |
|------|-----|---------|-----------|---------|
| emergencyContactName | string | ✅ | min 2 | — |
| emergencyContactPhone | string | ✅ | min 10 | — |
| nearestHospital | string | ✅ | min 2 | — |
| nearestHospitalPhone | string | ✅ | min 10 | — |
| nearestPolice | string | ✅ | min 2 | — |
| nearestPolicePhone | string | ✅ | min 10 | — |
| fireDepartment | string | ✅ | min 3 | "110" |
| additionalContacts | string | opsiyonel | — | — |

---

## Adım 11: Kişisel Karşılama

| Alan | Tip | Zorunlu | Validasyon | Default |
|------|-----|---------|-----------|---------|
| greetingMessage | string | ✅ | min 10 karakter | — |
| personaName | string | ✅ | min 1 | "Resepsiyonistim" |
| personaTone | enum | ✅ | formal, friendly, warm | "warm" |
| welcomeNote | string | opsiyonel | — | — |
| autoReplyEnabled | boolean | — | — | true |

**AI Etkisi:** `personaName` → system prompt'ta `${receptionistName}`. `greetingMessage` → GREETING state'inde AI ilk mesajı bu mesajı temel alır. `personaTone` → AI tonu ayarlar

---

## Adım 12: Onay ve Yayınla

Validasyon yok. Tüm adımların tamamlandığını kontrol eder → `activate_business()` RPC çağrılır → binary gate açılır → AI etkinleşir.