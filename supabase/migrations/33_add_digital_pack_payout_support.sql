-- 33_add_digital_pack_payout_support.sql
-- Bridge organizer payout tracking from legacy sponsorship_deals to digital_visibility_packs

ALTER TABLE sponsorship_payouts
  ADD COLUMN IF NOT EXISTS digital_pack_id UUID REFERENCES digital_visibility_packs(id) ON DELETE CASCADE;

ALTER TABLE sponsorship_payouts
  ALTER COLUMN sponsorship_deal_id DROP NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uniq_sponsorship_payouts_digital_pack
  ON sponsorship_payouts(digital_pack_id)
  WHERE digital_pack_id IS NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'sponsorship_payouts_source_check'
  ) THEN
    ALTER TABLE sponsorship_payouts
      ADD CONSTRAINT sponsorship_payouts_source_check
      CHECK (
        (sponsorship_deal_id IS NOT NULL AND digital_pack_id IS NULL)
        OR (sponsorship_deal_id IS NULL AND digital_pack_id IS NOT NULL)
      );
  END IF;
END $$;

INSERT INTO sponsorship_payouts (
  digital_pack_id,
  organizer_email,
  gross_amount,
  platform_fee,
  payout_amount,
  payout_status,
  created_at
)
SELECT
  d.id,
  d.organizer_email,
  d.amount,
  d.platform_share,
  d.organizer_share,
  'pending',
  COALESCE(d.created_at, NOW())
FROM digital_visibility_packs d
LEFT JOIN sponsorship_payouts sp
  ON sp.digital_pack_id = d.id
WHERE d.payment_status = 'paid'
  AND d.organizer_share > 0
  AND d.organizer_email IS NOT NULL
  AND sp.id IS NULL;