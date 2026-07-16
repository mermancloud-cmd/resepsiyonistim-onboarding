# Onboarding → AI Veri Akışı

## Supabase Şeması

### `tenants` tablosu (mevcut, onboarding kolonları eklendi)

```sql
ALTER TABLE tenants
  ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS onboarding_completed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS whatsapp_number TEXT;
```

### `bungalows` tablosu (onboarding_progress JSONB)

```sql
ALTER TABLE bungalows
  ADD COLUMN IF NOT EXISTS onboarding_progress JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT false;
```

`onboarding_progress` yapısı:
```json
{
  "1": { "businessName": "...", "businessType": "bungalov", ... },
  "2": { "latitude": 41.2, "longitude": 30.1, ... },
  "3": [{ "id": "uuid", "name": "Jakuzili Bungalov", ... }],
  ...
  "11": { "greetingMessage": "...", "personaName": "Elif" }
}
```

### `onboarding_steps` tablosu (adım takibi)

```sql
CREATE TABLE onboarding_steps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL,
  step_number INTEGER NOT NULL CHECK (step_number BETWEEN 1 AND 12),
  is_completed BOOLEAN NOT NULL DEFAULT false,
  step_data JSONB,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(business_id, step_number)
);
```

## RPC Fonksiyonları

### 1. `init_onboarding_steps(p_business_id UUID)`
12 adımı oluşturur (yoksa), mevcut durumlarını döndürür.

### 2. `complete_onboarding_step(p_business_id UUID, p_step_number INTEGER, p_step_data JSONB)`
Adımı tamamlar, `step_data`'yı kaydeder. 12/12 ise `tenants.onboarding_completed = true`.

### 3. `update_onboarding_progress(p_business_id UUID, p_step_number INTEGER, p_step_data JSONB)`
`bungalows.onboarding_progress` JSONB'ye adım verisini yazar (merge).

### 4. `check_onboarding_complete(p_business_id UUID)`
Boolean döndürür — 12/12 adım tamam mı?

### 5. `activate_business(p_business_id UUID)`
Binary gate kontrolü → `onboarding_completed = true` → `activate_wf02()` → `tenant_settings.ai_enabled = true`

### 6. `activate_wf02(p_tenant_id UUID)`
`tenant_settings.ai_enabled = true` + `workflow_events` log.

## WF02 — canonical_business_info Oluşumu

```
WF02 (n8n) webhook POST /state-ai
  ↓
Load Conversation State → Supabase REST:
  GET /rest/v1/conversations?id=eq.{conv_id}
  ↓
Fetch Bungalows (n8n code node): 
  GET /rest/v1/bungalows?id=eq.{tenant_id}
  → returns: onboarding_progress, business_name, business_type, ...
  ↓
Build AI Prompt (n8n code node):
  canonical_business_info = {
    businessName: step1.businessName,
    businessType: step1.businessType,  
    receptionistName: step11.personaName || "Resepsiyonistim",
    units: step3 (array of unit types),
    pricing: { currency: step4.currency, basePrices: step3[].basePrice },
    amenities: step5 (boolean flags),
    rules: step6 (check-in/out, pet, smoking),
    policies: step7 (cancellation + refund),
    payment: { deposit: step8.depositPercentage, iban: step8.iban },
    checkin: step6.checkInTime,
    checkout: step6.checkOutTime
  }
  ↓
9Router Chat Completion:
  systemPrompt = `${receptionistName}=${bizName} Turkce resepsiyonisti...
  - Ismin: ${receptionistName}. ${bizName} adli konaklama...
  - Isletme tipi: ${bizType}...`
  ↓
Validation layers use canonical_business_info:
  - Price validation: pricing_result from step3/step4
  - Policy validation: policy_source from step6/step7/step8
  - Availability: room_result from step3
```

## Eksik Veri → AI Davranışı

| Eksik | AI Node | Sonuç |
|-------|---------|-------|
| basePrice (step 3) | `Validate Price & Availability` | `P0_UNVERIFIED_PRICE` reddi → handoff |
| Cancel policy (step 7) | `Reliability Guardrails` | `missing_policy_source` → handoff |
| IBAN (step 8) | `Validate Price & Availability` | `HG-004_IBAN_MISSING` → handoff |
| Amenities (step 5) | AI prompt | AI "yok" der veya "emin değilim" → güven kaybı |
| personaName (step 11) | `Build AI Prompt` | Default "Resepsiyonistim" kullanılır → kişiselleştirme yok |
| greetingMessage (step 11) | AI GREETING state | AI geneik karşılama yapar → marka tutarsızlığı |

## RLS Policies

```sql
-- Owners read own steps
CREATE POLICY "owners_read_own_steps"
  ON onboarding_steps FOR SELECT
  USING (business_id IN (SELECT id FROM tenants WHERE owner_id = auth.uid()));

-- Owners insert own steps
CREATE POLICY "owners_update_own_steps"
  ON onboarding_steps FOR INSERT
  WITH CHECK (business_id IN (SELECT id FROM tenants WHERE owner_id = auth.uid()));
```