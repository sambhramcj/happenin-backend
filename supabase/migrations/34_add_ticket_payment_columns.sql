-- 34_add_ticket_payment_columns.sql
-- Align registrations schema with final ticket payment flow

ALTER TABLE registrations
  ADD COLUMN IF NOT EXISTS final_price NUMERIC(12,2),
  ADD COLUMN IF NOT EXISTS razorpay_order_id TEXT,
  ADD COLUMN IF NOT EXISTS razorpay_payment_id TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_registrations_razorpay_order_id
  ON registrations(razorpay_order_id)
  WHERE razorpay_order_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_registrations_razorpay_payment_id
  ON registrations(razorpay_payment_id)
  WHERE razorpay_payment_id IS NOT NULL;