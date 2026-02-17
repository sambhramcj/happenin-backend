#!/bin/bash

# Student Home Page Migrations Runner
# Run this script to apply all 6 migrations for the student home page

echo "🚀 Running Student Home Page Migrations..."
echo ""

# Check if we're in the backend directory
if [ ! -d "supabase/migrations" ]; then
  echo "❌ Error: supabase/migrations directory not found"
  echo "Please run this script from the backend directory"
  exit 1
fi

# Array of migrations to run
migrations=(
  "28_home_banners_and_event_boosts.sql"
  "29_event_fields_alignment.sql"
  "30_event_registration_rankings.sql"
  "31_sponsor_analytics.sql"
  "32_sponsor_profile_banner.sql"
  "33_event_primary_category.sql"
)

# Check if migrations exist
for migration in "${migrations[@]}"; do
  if [ ! -f "supabase/migrations/$migration" ]; then
    echo "❌ Error: Migration $migration not found"
    exit 1
  fi
done

echo "✅ All migration files found"
echo ""

# Run migrations
echo "Applying migrations to database..."
echo ""

# Check if supabase CLI is available
if command -v supabase &> /dev/null; then
  echo "Using Supabase CLI..."
  supabase db push
  
  if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Migrations applied successfully!"
    echo ""
    echo "📝 Next steps:"
    echo "1. Verify migrations in Supabase dashboard"
    echo "2. Seed test data (banners, boosted events, sponsors)"
    echo "3. Test the student home page at /dashboard/student"
    echo ""
  else
    echo "❌ Migration failed. Check error messages above."
    exit 1
  fi
else
  echo "⚠️  Supabase CLI not found"
  echo ""
  echo "Please run migrations manually:"
  echo "1. Go to your Supabase dashboard"
  echo "2. Navigate to SQL Editor"
  echo "3. Run each migration file in order (28-33)"
  echo ""
  echo "Migration files:"
  for migration in "${migrations[@]}"; do
    echo "   - supabase/migrations/$migration"
  done
fi
