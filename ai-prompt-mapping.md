# Onboarding Alanı → AI Prompt Değişkeni → Guardrail Eşleştirme

## Tam Eşleştirme Tablosu

| Adım | Onboarding Alanı | AI Prompt Değişkeni | Kullanılan Node | Guardrail / Validation |
|------|-------------------|---------------------|-----------------|------------------------|
| 1 | `businessName` | `${bizName}` | Build AI Prompt, 9Router Chat Completion | — |
| 1 | `businessType` | `${bizType}` | Build AI Prompt | AI prompt: "Isletme tipi: ${bizType}" |
| 1 | `whatsappNumber` | — (= evolution API target) | Send Via Evolution API | — |
| 1 | `email` | — | — | — |
| 2 | `latitude/longitude` | — | — | AI yol tarifi için kullanır (canonical_business_info.directions) |
| 2 | `directions` | `canonical_business_info.directions` | Reliability Guardrails | AI yol tarifi sorularında kaynak |
| 3 | `units[].name` | `canonical_business_info.units[].name` | Validate Price & Availability | Room name matching (HG-003) |
| 3 | `units[].capacity` | `canonical_business_info.units[].capacity` | Validate Price & Availability | HG-006: over-capacity check |
| 3 | `units[].basePrice` | `pricing_result.rooms[].price` | Validate Price & Availability | **P0_UNVERIFIED_PRICE** — fiyat yoksa AI fiyat söyleyemez |
| 3 | `units[].amenities` | `canonical_business_info.units[].amenities` | Reliability Guardrails | AI "jakuzi var mı?" → sadece bu listeden yanıt |
| 4 | `pricing.currency` | `pricing_result.currency` | Validate Price & Availability | Fiyat formatı: ₺/€/$ |
| 4 | `pricing.minimumStayNights` | `canonical_business_info.minStay` | AI prompt (implicit) | AI "minimum X gece" der |
| 4 | `seasonalAdjustments` | `pricing_result.seasonalMultipliers` | Fetch Room Pricing | Sezonluk fiyat hesaplama |
| 5 | `amenities.jacuzzi` | `canonical_business_info.amenities.jacuzzi` | Reliability Guardrails | AI "jakuzi var mı?" → true/false |
| 5 | `amenities.pool` | `canonical_business_info.amenities.pool` | Reliability Guardrails | AI "havuz var mı?" → true/false |
| 5 | `amenities.wifi` | `canonical_business_info.amenities.wifi` | Reliability Guardrails | AI "WiFi var mı?" → true/false |
| 5 | `amenities.petFriendly` | `canonical_business_info.amenities.petFriendly` | Reliability Guardrails | AI "evcil hayvan?" → true/false |
| 5 | (all amenities) | `canonical_business_info.amenities` | Reliability Guardrails | `hasPolicySource` check |
| 6 | `rules.checkInTime` | `canonical_business_info.checkin` | Reliability Guardrails | `policyClaim` + `hasPolicySource` |
| 6 | `rules.checkOutTime` | `canonical_business_info.checkout` | Reliability Guardrails | `policyClaim` + `hasPolicySource` |
| 6 | `rules.petPolicy` | `canonical_business_info.policies.petPolicy` | Reliability Guardrails | AI pet sorularında kaynak |
| 6 | `rules.smokingPolicy` | `canonical_business_info.policies.smokingPolicy` | Reliability Guardrails | AI sigara sorularında kaynak |
| 6 | `rules.quietHoursStart/End` | `canonical_business_info.policies.quietHours` | Reliability Guardrails | AI sessizlik saati sorularında |
| 6 | `rules.additionalRules` | `canonical_business_info.policies.additionalRules` | Reliability Guardrails | AI ek kurallar sorularında |
| 7 | `cancellation.policyType` | `canonical_business_info.policies.cancellation` | Reliability Guardrails | `policyClaim` (iptal/iade) → `hasPolicySource` |
| 7 | `cancellation.refundPercentages[]` | `canonical_business_info.policies.refunds` | Reliability Guardrails | AI "%50 iade" gibi — sadece bu kaynaktan |
| 7 | `cancellation.freeCancellationDays` | `canonical_business_info.policies.freeCancelDays` | Reliability Guardrails | AI "X gün öncesine kadar ücretsiz" |
| 8 | `depositPayment.depositPercentage` | `canonical_business_info.payment.depositPercent` | Validate Price & Availability | AI kapora oranı söyler |
| 8 | `depositPayment.iban` | `canonical_business_info.payment.iban` | Validate Price & Availability | **HG-004**: IBAN kontrolü |
| 8 | `depositPayment.bankName` | `canonical_business_info.payment.bankName` | Validate Price & Availability | AI banka adı söyler |
| 8 | `depositPayment.accountHolder` | `canonical_business_info.payment.accountHolder` | Validate Price & Availability | AI hesap sahibi söyler |
| 8 | `depositPayment.paymentMethods[]` | `canonical_business_info.payment.methods` | Reliability Guardrails | AI ödeme yöntemi söyler |
| 9 | `surroundings.nearbyMarkets` | `canonical_business_info.surroundings.markets` | Reliability Guardrails | AI "yakında market var mı?" |
| 9 | `surroundings.nearbyRestaurants` | `canonical_business_info.surroundings.restaurants` | Reliability Guardrails | AI "yakında restoran?" |
| 9 | `surroundings.distanceToBeach` | `canonical_business_info.surroundings.beach` | Reliability Guardrails | AI "denize mesafe?" |
| 9 | `surroundings.distanceToAirport` | `canonical_business_info.surroundings.airport` | Reliability Guardrails | AI "havalimanına mesafe?" |
| 10 | `emergency.emergencyContactName` | `canonical_business_info.emergency.contact` | Reliability Guardrails | AI acil durum sorularında |
| 10 | `emergency.nearestHospital` | `canonical_business_info.emergency.hospital` | Reliability Guardrails | AI "en yakın hastane?" |
| 11 | `greeting.personaName` | `${receptionistName}` | Build AI Prompt, 9Router Chat | AI system prompt: "Ismin: ${receptionistName}" |
| 11 | `greeting.greetingMessage` | (GREETING state reference) | AI prompt (implicit) | AI ilk mesajı bu mesajı temel alır |
| 11 | `greeting.personaTone` | (ton adjustment) | AI prompt (implicit) | formal/friendly/warm → AI tonu |
| 11 | `greeting.welcomeNote` | `canonical_business_info.welcomeNote` | AI prompt | AI hoş geldin mesajına ekler |

## Guardrail Öncelik Tablosu

| Guardrail | Tetikleyen Onboarding Alanı | Red Durumu |
|-----------|---------------------------|------------|
| **P0_UNVERIFIED_PRICE** | `units[].basePrice` eksik | AI fiyat söyleyemez → handoff |
| **P0_UNVERIFIED_AVAILABILITY** | `units[]` eksik | AI müsaitlik söyleyemez → handoff |
| **HG-003_ROOM_NAME_MISMATCH** | `units[].name` AI yanıtında yok | AI farklı oda adı kullandı → düzelt |
| **HG-004_IBAN_MISSING** | `depositPayment.iban` eksik | AI IBAN veremez → handoff |
| **HG-006_OVER_CAPACITY** | `units[].capacity` aşıldı | AI yanlış kapasite söyledi → düzelt |
| **missing_policy_source** | `rules` + `cancellation` eksik | AI policy sorularında → handoff |
| **uncertain_claim** | `pricing_result` + `availability_result` yok | AI riskli iddiada bulundu → handoff |
| **robotic_disclaimer_removed** | (AI prompt leak) | AI "yapay zeka" dedi → sil + handoff |

## Kritik Bağımlılık Zinciri

```
basePrice (step 3) → pricing_result (WF02 fetch) → Validate Price & Availability → AI fiyat söyleyebilir
rules (step 6) → canonical_business_info.policies → Reliability Guardrails → AI check-in/pet/smoking söyleyebilir
iban (step 8) → canonical_business_info.payment → Validate Price & Availability (HG-004) → AI kapora süreci
personaName (step 11) → ${receptionistName} → system prompt → AI kimliği
```

**Sonuç:** Onboarding'te atlanan her alan, AI'nin bir soruya cevap verememesi ve "sizi yetkili ekibe yönlendireyim" demesi demektir.