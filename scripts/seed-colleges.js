/**
 * Seed colleges data into Supabase
 * Run: node backend/scripts/seed-colleges.js
 */

const fs = require('fs');
const path = require('path');

// You'll need to set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  console.error('Set them in .env file');
  process.exit(1);
}

async function seedColleges() {
  try {
    // Read colleges data
    const collegesPath = path.join(__dirname, '../data/colleges-seed.json');
    const collegesData = JSON.parse(fs.readFileSync(collegesPath, 'utf8'));

    console.log(`📚 Found ${collegesData.length} colleges to seed`);

    // Import Supabase (you may need to install @supabase/supabase-js)
    const { createClient } = require('@supabase/supabase-js');
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Batch insert
    const BATCH_SIZE = 100;
    let inserted = 0;

    for (let i = 0; i < collegesData.length; i += BATCH_SIZE) {
      const batch = collegesData.slice(i, i + BATCH_SIZE);
      
      // Add country field (default India)
      const batchWithCountry = batch.map(college => ({
        ...college,
        country: college.country || 'India'
      }));

      const { data, error } = await supabase
        .from('colleges')
        .upsert(batchWithCountry, { 
          onConflict: 'name',
          ignoreDuplicates: false 
        });

      if (error) {
        console.error(`❌ Error inserting batch ${i / BATCH_SIZE + 1}:`, error);
        continue;
      }

      inserted += batch.length;
      console.log(`✅ Inserted batch ${i / BATCH_SIZE + 1} (${inserted}/${collegesData.length})`);
    }

    console.log(`\n🎉 Successfully seeded ${inserted} colleges!`);
    
    // Verify
    const { count } = await supabase
      .from('colleges')
      .select('*', { count: 'exact', head: true });
    
    console.log(`📊 Total colleges in database: ${count}`);

  } catch (error) {
    console.error('❌ Seed failed:', error);
    process.exit(1);
  }
}

seedColleges();
