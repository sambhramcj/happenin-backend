# Student Home Page Migrations Runner (PowerShell)
# Run this script to apply all 6 migrations for the student home page

Write-Host "🚀 Running Student Home Page Migrations..." -ForegroundColor Cyan
Write-Host ""

# Check if we're in the backend directory
if (-not (Test-Path "supabase\migrations")) {
  Write-Host "❌ Error: supabase\migrations directory not found" -ForegroundColor Red
  Write-Host "Please run this script from the backend directory" -ForegroundColor Yellow
  exit 1
}

# Array of migrations to run
$migrations = @(
  "28_home_banners_and_event_boosts.sql",
  "29_event_fields_alignment.sql",
  "30_event_registration_rankings.sql",
  "31_sponsor_analytics.sql",
  "32_sponsor_profile_banner.sql",
  "33_event_primary_category.sql"
)

# Check if migrations exist
foreach ($migration in $migrations) {
  if (-not (Test-Path "supabase\migrations\$migration")) {
    Write-Host "❌ Error: Migration $migration not found" -ForegroundColor Red
    exit 1
  }
}

Write-Host "✅ All migration files found" -ForegroundColor Green
Write-Host ""

# Run migrations
Write-Host "Applying migrations to database..." -ForegroundColor Cyan
Write-Host ""

# Check if supabase CLI is available
$supabaseCli = Get-Command supabase -ErrorAction SilentlyContinue

if ($supabaseCli) {
  Write-Host "Using Supabase CLI..." -ForegroundColor Yellow
  supabase db push
  
  if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Migrations applied successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 Next steps:" -ForegroundColor Cyan
    Write-Host "1. Verify migrations in Supabase dashboard" -ForegroundColor White
    Write-Host "2. Seed test data (banners, boosted events, sponsors)" -ForegroundColor White
    Write-Host "3. Test the student home page at /dashboard/student" -ForegroundColor White
    Write-Host ""
  } else {
    Write-Host "❌ Migration failed. Check error messages above." -ForegroundColor Red
    exit 1
  }
} else {
  Write-Host "⚠️  Supabase CLI not found" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "Please run migrations manually:" -ForegroundColor Cyan
  Write-Host "1. Go to your Supabase dashboard" -ForegroundColor White
  Write-Host "2. Navigate to SQL Editor" -ForegroundColor White
  Write-Host "3. Run each migration file in order (28-33)" -ForegroundColor White
  Write-Host ""
  Write-Host "Migration files:" -ForegroundColor Cyan
  foreach ($migration in $migrations) {
    Write-Host "   - supabase\migrations\$migration" -ForegroundColor White
  }
}
