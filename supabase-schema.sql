-- ═══════════════════════════════════════════════════════════════════════════════
-- Onboarding Schema — Complete SQL
-- bungalows, onboarding_steps, RPC functions, RLS
-- ═══════════════════════════════════════════════════════════════════════════════

-- ─── 1. tenants: onboarding columns ──────────────────────────────────────────
ALTER TABLE tenants
  ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS onboarding_completed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS whatsapp_number TEXT;

-- ─── 2. bungalows: onboarding_progress JSONB ──────────────────────────────────
ALTER TABLE bungalows
  ADD COLUMN IF NOT EXISTS onboarding_progress JSONB DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN DEFAULT false;

-- ─── 3. onboarding_steps table ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS onboarding_steps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL,
  step_number INTEGER NOT NULL CHECK (step_number BETWEEN 1 AND 12),
  is_completed BOOLEAN NOT NULL DEFAULT false,
  step_data JSONB,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(business_id, step_number)
);

CREATE INDEX IF NOT EXISTS idx_onboarding_steps_business
  ON onboarding_steps(business_id);
CREATE INDEX IF NOT EXISTS idx_onboarding_steps_completed
  ON onboarding_steps(business_id, is_completed)
  WHERE is_completed = true;

-- ─── 4. RPC: init_onboarding_steps ────────────────────────────────────────────
DROP FUNCTION IF EXISTS init_onboarding_steps(UUID);
CREATE OR REPLACE FUNCTION init_onboarding_steps(p_business_id UUID)
RETURNS TABLE (step_number INTEGER, is_completed BOOLEAN, completed_at TIMESTAMPTZ)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO onboarding_steps (business_id, step_number, is_completed)
  SELECT p_business_id, gs.step, false
  FROM generate_series(1, 12) AS gs(step)
  ON CONFLICT (business_id, step_number) DO NOTHING;

  RETURN QUERY
  SELECT os.step_number, os.is_completed, os.completed_at
  FROM onboarding_steps os
  WHERE os.business_id = p_business_id
  ORDER BY os.step_number;
END;
$$;

-- ─── 5. RPC: complete_onboarding_step ─────────────────────────────────────────
DROP FUNCTION IF EXISTS complete_onboarding_step(UUID, INTEGER, JSONB);
CREATE OR REPLACE FUNCTION complete_onboarding_step(
  p_business_id UUID, p_step_number INTEGER, p_step_data JSONB
) RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_all_complete BOOLEAN;
BEGIN
  INSERT INTO onboarding_steps (business_id, step_number, is_completed, step_data, completed_at)
  VALUES (p_business_id, p_step_number, true, p_step_data, now())
  ON CONFLICT (business_id, step_number)
  DO UPDATE SET is_completed = true, step_data = EXCLUDED.step_data,
    completed_at = now(), updated_at = now();

  SELECT COUNT(*) = 12 INTO v_all_complete
  FROM onboarding_steps
  WHERE business_id = p_business_id AND is_completed = true;

  IF v_all_complete THEN
    UPDATE tenants SET onboarding_completed = true, onboarding_completed_at = now()
    WHERE id = p_business_id;
  END IF;

  RETURN v_all_complete;
END;
$$;

-- ─── 6. RPC: update_onboarding_progress ───────────────────────────────────────
DROP FUNCTION IF EXISTS update_onboarding_progress(UUID, INTEGER, JSONB);
CREATE OR REPLACE FUNCTION update_onboarding_progress(
  p_business_id UUID, p_step_number INTEGER, p_step_data JSONB
) RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  UPDATE bungalows
  SET onboarding_progress = onboarding_progress || jsonb_build_object(p_step_number::text, p_step_data)
  WHERE id = p_business_id;
  RETURN true;
END;
$$;

-- ─── 7. RPC: check_onboarding_complete ────────────────────────────────────────
DROP FUNCTION IF EXISTS check_onboarding_complete(UUID);
CREATE OR REPLACE FUNCTION check_onboarding_complete(p_business_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE v_result BOOLEAN;
BEGIN
  SELECT COALESCE(onboarding_completed, false) INTO v_result
  FROM tenants WHERE id = p_business_id;
  IF v_result IS NULL OR NOT v_result THEN
    SELECT COUNT(*) = 12 INTO v_result
    FROM onboarding_steps
    WHERE business_id = p_business_id AND is_completed = true;
  END IF;
  RETURN COALESCE(v_result, false);
END;
$$;

-- ─── 8. RPC: activate_business (Binary Gate) ──────────────────────────────────
DROP FUNCTION IF EXISTS activate_business(UUID);
CREATE OR REPLACE FUNCTION activate_business(p_business_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE v_all_steps_complete BOOLEAN;
BEGIN
  SELECT COUNT(*) = 12 INTO v_all_steps_complete
  FROM onboarding_steps
  WHERE business_id = p_business_id AND is_completed = true;
  IF NOT v_all_steps_complete THEN
    RAISE EXCEPTION 'Cannot activate: not all onboarding steps are complete';
  END IF;
  UPDATE tenants SET onboarding_completed = true, onboarding_completed_at = now()
  WHERE id = p_business_id;
  PERFORM activate_wf02(p_business_id);
  RETURN true;
END;
$$;

-- ─── 9. RPC: activate_wf02 ───────────────────────────────────────────────────
DROP FUNCTION IF EXISTS activate_wf02(UUID);
CREATE OR REPLACE FUNCTION activate_wf02(p_tenant_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  UPDATE tenant_settings SET ai_enabled = true, updated_at = now()
  WHERE tenant_id = p_tenant_id;
  IF NOT FOUND THEN
    INSERT INTO tenant_settings (tenant_id, ai_enabled) VALUES (p_tenant_id, true)
    ON CONFLICT (tenant_id) DO UPDATE SET ai_enabled = true, updated_at = now();
  END IF;
  BEGIN
    INSERT INTO workflow_events (tenant_id, workflow_id, event_type, payload, created_at)
    VALUES (p_tenant_id, 'WF02', 'activated', jsonb_build_object('activated_at', now(), 'source', 'onboarding_completion'), now())
    ON CONFLICT DO NOTHING;
  EXCEPTION WHEN undefined_table THEN NULL;
  END;
  RETURN true;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'WF02 activation partial: %', SQLERRM;
  RETURN false;
END;
$$;

-- ─── 10. RLS ──────────────────────────────────────────────────────────────────
ALTER TABLE onboarding_steps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "owners_read_own_steps" ON onboarding_steps;
CREATE POLICY "owners_read_own_steps"
  ON onboarding_steps FOR SELECT
  USING (business_id IN (SELECT id FROM tenants WHERE owner_id = auth.uid()));

DROP POLICY IF EXISTS "owners_insert_own_steps" ON onboarding_steps;
CREATE POLICY "owners_insert_own_steps"
  ON onboarding_steps FOR INSERT
  WITH CHECK (business_id IN (SELECT id FROM tenants WHERE owner_id = auth.uid()));

-- ─── 11. updated_at trigger ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_onboarding_steps_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_onboarding_steps_updated_at ON onboarding_steps;
CREATE TRIGGER tr_onboarding_steps_updated_at
  BEFORE UPDATE ON onboarding_steps
  FOR EACH ROW
  EXECUTE FUNCTION update_onboarding_steps_updated_at();