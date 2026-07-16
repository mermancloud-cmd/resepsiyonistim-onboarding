# Onboarding İyileştirmeleri — "Hatasız, İnsansı, Güvenilir" AI İçin

## 1. Smart Defaults (İşletme Tipine Göre Otomatik Doldurma)

İşletme türü seçildiğinde (step 1), sonraki adımlarda akıllı varsayılanlar doldurulmalı:

| businessType | checkIn | checkOut | deposit % | petPolicy | smokingPolicy | minimumStay |
|-------------|---------|----------|-----------|-----------|---------------|-------------|
| bungalov | 14:00 | 11:00 | 30 | on_request | outdoor_only | 1 |
| tiny_house | 15:00 | 10:00 | 30 | not_allowed | outdoor_only | 1 |
| villa | 16:00 | 10:00 | 50 | on_request | outdoor_only | 2 |
| hotel | 14:00 | 12:00 | 0 (card) | not_allowed | not_allowed | 1 |
| pension | 13:00 | 10:00 | 30 | allowed | outdoor_only | 1 |
| apartment | 15:00 | 11:00 | 30 | not_allowed | not_allowed | 2 |

```typescript
const SMART_DEFAULTS: Record<BusinessType, Partial<RulesData & DepositPaymentData & PricingData>> = {
  bungalov: { checkInTime: "14:00", checkOutTime: "11:00", depositPercentage: 30, petPolicy: "on_request", smokingPolicy: "outdoor_only", minimumStayNights: 1 },
  tiny_house: { checkInTime: "15:00", checkOutTime: "10:00", depositPercentage: 30, petPolicy: "not_allowed", smokingPolicy: "outdoor_only", minimumStayNights: 1 },
  villa: { checkInTime: "16:00", checkOutTime: "10:00", depositPercentage: 50, petPolicy: "on_request", smokingPolicy: "outdoor_only", minimumStayNights: 2 },
  // ...
};
```

## 2. Conditional Fields (Dinamik Gösterim)

| Koşul | Davranış |
|-------|----------|
| petPolicy = "not_allowed" | petDetails alanı gizlenir |
| petPolicy = "allowed" \|\| "on_request" | petDetails alanı gösterilir (opsiyonel) |
| policyType ≠ "custom" | customPolicy gizlenir |
| policyType = "custom" | customPolicy gösterilir (zorunlu) |
| businessType NOT in [bungalov, villa] | seasonalAdjustments gizlenir (otel/pansiyon sezonluk fiyat kullanmaz) |
| parkingAvailable = false | parkingInfo gizlenir |
| depositType = "percentage" | depositFixedAmount gizlenir |
| depositType = "fixed" | depositPercentage gizlenir |

## 3. Validation İyileştirmeleri

### 3.1 IBAN Checksum Validation
```typescript
ibanSchema = z.string().refine(iban => {
  // TR + 24 hane = 26 karakter
  if (!/^TR\d{24}$/.test(iban.replace(/\s/g, '').toUpperCase())) return false;
  // ISO 13616 check
  const rearranged = iban.slice(4) + iban.slice(0, 4);
  const numeric = rearranged.replace(/[A-Z]/g, c => String(c.charCodeAt(0) - 55));
  let remainder = BigInt(numeric);
  return remainder % 97n === 1n;
}, "Geçersiz IBAN — checksum doğrulanamadı")
```

### 3.2 Turkish Phone Format
```typescript
phoneSchema = z.string().refine(phone => {
  const digits = phone.replace(/\D/g, '');
  // 0XXXXXXXXXX format
  return /^0\d{10}$/.test(digits) || /^\d{10}$/.test(digits);
}, "Telefon 0XXX XXX XX XX formatında olmalıdır")
```

### 3.3 Price Range Sanity
```typescript
basePriceSchema = z.number().min(100, "Gece ücreti çok düşük — kontrol edin").max(50000, "Gece ücreti çok yüksek — kontrol edin")
```

### 3.4 GPS Turkey Bounds
```typescript
latitudeSchema = z.number().min(35.5, "Enlem Türkiye sınırları dışında").max(42.5, "Enlem Türkiye sınırları dışında")
longitudeSchema = z.number().min(25.5, "Boylam Türkiye sınırları dışında").max(45.0, "Boylam Türkiye sınırları dışında")
```

### 3.5 Check-in / Check-out Logic
```typescript
.refine(data => {
  const cin = parseInt(data.checkInTime.replace(':', ''));
  const cout = parseInt(data.checkOutTime.replace(':', ''));
  return cin !== cout;
}, "Giriş ve çıkış saatleri aynı olamaz")
```

## 4. AI Preview (Canlı Önizleme)

Step 11 sonunda, girilen verilerle AI'nin bir misafiri nasıl karşılayacağını canlı göster:

```typescript
// After step 11 completes, call 9Router API with the onboarding data
const previewMessages = [
  { role: "user", content: "Merhaba, 2 kişiyiz hafta sonu için bungalov arıyorum" }
];
// System prompt built from onboarding data
// Show 3-message conversation preview
```

**Fayda:** İşletme sahibi AI'nin tonunu, bilgi seviyesini ve tutarlılığı görür. "Jakuzi var mı?" sorusuna AI doğru mu yanıt veriyor? Hatalıysa onboarding'e geri dönülür.

```typescript
const AIPreview = () => {
  const [preview, setPreview] = useState<PreviewMessage[]>([]);
  const runPreview = async () => {
    // POST /api/onboarding/preview with onboarding data
    // Server: 9Router API call with canonical_business_info
    // Returns: 3-message conversation
  };
  return <ChatPreview messages={preview} onRun={runPreview} />;
};
```

## 5. Completeness Score

12 adım tamamlandıktan sonra, veri kalitesine göre % hesapla:

```typescript
function calculateCompletenessScore(data: OnboardingData): number {
  let score = 0;
  const maxScore = 100;
  
  // Business info (15%)
  if (data.business.businessName) score += 5;
  if (data.business.address && data.business.address.length > 10) score += 5;
  if (data.business.email && data.business.phone) score += 5;
  
  // Units (20%)
  const totalUnits = data.units.reduce((sum, u) => sum + u.count, 0);
  if (data.units.length > 0 && totalUnits > 0) score += 10;
  if (data.units.every(u => u.description && u.description.length > 20)) score += 5;
  if (data.units.every(u => u.amenities.length > 0)) score += 5;
  
  // Pricing (10%)
  if (data.units.every(u => u.basePrice >= 100)) score += 5;
  if (data.pricing.minimumStayNights >= 1) score += 5;
  
  // Amenities (10%)
  const amenityCount = Object.values(data.amenities).filter(Boolean).length;
  score += Math.min(10, amenityCount * 2);
  
  // Rules (15%)
  score += data.rules.checkInTime ? 5 : 0;
  score += data.rules.checkOutTime ? 5 : 0;
  score += data.rules.additionalRules.length > 10 ? 5 : 0;
  
  // Cancellation (10%)
  if (data.cancellation.policyType !== 'custom') score += 5;
  if (data.cancellation.freeCancellationDays >= 1) score += 5;
  
  // Deposit/Payment (10%)
  if (data.depositPayment.iban.length >= 26) score += 5;
  if (data.depositPayment.paymentMethods.length > 0) score += 5;
  
  // Greeting (10%)
  if (data.greeting.greetingMessage.length > 20) score += 5;
  if (data.greeting.personaName) score += 5;
  
  return Math.min(maxScore, score);
}
// < 80% → uyarı: "Eksik bilgiler AI'nin yanıt kalitesini düşürecektir"
```

## 6. Test Conversation (Onboarding Sonrası Doğrulama)

12/12 adım tamamlandıktan sonra, otomatik 5 mesajlık test konuşması çalıştır:

```typescript
const TEST_SCENARIOS = [
  "Merhaba, bungalov hakkında bilgi alabilir miyim?",
  "Jakuzi var mı?", // amenities test
  "Hafta sonu için müsait mi?", // availability test
  "Fiyat ne kadar?", // pricing test
  "İptal edersem para iadesi olur mu?", // policy test
];
// Run through actual 9Router API
// Score: 5/5 correct → activate
// < 5/5 → "bazı yanıtlar eksik — lütfen şu adımları kontrol edin"
```

## 7. Data Quality Checks

| Kontrol | Tetik | Mesaj |
|---------|-------|-------|
| Unit name uniqueness | Aynı isimde 2+ birim | "Aynı isimde birden fazla birim var — karışıklık olabilir" |
| Amenity-price consistency | jacuzzi + basePrice < 500 TL | "Jakuzili birim için fiyat düşük görünüyor — kontrol edin" |
| Check-in > check-out | checkInTime = checkOutTime | "Giriş ve çıkış saatleri aynı" |
| Exotic deposit % | depositPercentage > 50 | "Yüksek kapora oranı misafir caydırabilir" |
| Missing emergency phone | emergencyContactPhone < 10 | "Acil durum telefonu eksik" |
| Policy-refund mismatch | strict + freeCancellationDays > 14 | "Katı iptal politikası ama 14 gün ücretsiz iptal — çelişki" |

## 8. Progressive Disclosure

Görsel olarak 12 adımı 4 gruba böl:

| Grup | Adımlar | Başlık |
|------|---------|--------|
| 1 | 1, 2, 3 | "Temel Bilgiler" |
| 2 | 4, 5, 6, 7 | "Fiyat ve Kurallar" |
| 3 | 8, 9, 10 | "Ödeme ve Güvenlik" |
| 4 | 11, 12 | "Karşılama ve Yayın" |

Her grup tamamlandıktan sonra sonraki grup açılır. Toast mesajı: "Temel bilgiler tamam! Fiyat ve kurallara geçebilirsiniz."

## 9. Multi-language Onboarding

Onboarding formu TR/EN/AR desteği (AI'nin desteklediği diller). Form etiketleri ve hata mesajları lokalize. AI Preview de seçili dilde çalışır.