#!/usr/bin/env node
/**
 * Seed foods catalog from CSV.
 * Usage: SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node scripts/seed_foods.js <path-to-csv>
 *
 * CSV columns: name,aliases,cuisine,category,is_prepared,source,source_ref,kcal_100g,protein_100g,carbs_100g,fat_100g,fiber_100g,verified
 * - aliases: semicolon-separated
 * - verified: true/false or 1/0
 */

const fs = require('fs');
const path = require('path');

const csvPath = process.argv[2];
if (!csvPath || !fs.existsSync(csvPath)) {
  console.error('Usage: node scripts/seed_foods.js <path-to-csv>');
  process.exit(1);
}

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

async function main() {
  const { createClient } = await import('@supabase/supabase-js');
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const csv = fs.readFileSync(csvPath, 'utf8');
  const lines = csv.trim().split(/\r?\n/);
  if (lines.length < 2) {
    console.error('CSV must have header + at least one row');
    process.exit(1);
  }

  const headers = parseCsvLine(lines[0]);
  const nameIdx = headers.indexOf('name');
  const kcalIdx = headers.indexOf('kcal_100g');
  if (nameIdx < 0 || kcalIdx < 0) {
    console.error('CSV must have "name" and "kcal_100g" columns');
    process.exit(1);
  }

  let count = 0;
  for (let i = 1; i < lines.length; i++) {
    const vals = parseCsvLine(lines[i]);
    const get = (col) => {
      const idx = headers.indexOf(col);
      return idx >= 0 ? (vals[idx] || '').trim() : '';
    };

    const name = get('name');
    if (!name) continue;

    const aliasesStr = get('aliases');
    const aliases = aliasesStr ? aliasesStr.split(';').map((s) => s.trim()).filter(Boolean) : null;

    const { error } = await supabase.rpc('admin_upsert_food', {
      p_name: name,
      p_aliases: aliases,
      p_cuisine: get('cuisine') || null,
      p_category: get('category') || null,
      p_is_prepared: /^(true|1|yes)$/i.test(get('is_prepared')),
      p_source: get('source') || null,
      p_source_ref: get('source_ref') || null,
      p_kcal_100g: parseFloat(get('kcal_100g')) || 0,
      p_protein_100g: parseFloat(get('protein_100g')) || 0,
      p_carbs_100g: parseFloat(get('carbs_100g')) || 0,
      p_fat_100g: parseFloat(get('fat_100g')) || 0,
      p_fiber_100g: parseFloat(get('fiber_100g')) || 0,
      p_verified: /^(true|1|yes)$/i.test(get('verified')),
    });

    if (error) {
      console.error(`Row ${i + 1} (${name}):`, error.message);
    } else {
      count++;
    }
  }

  console.log(`Imported ${count} foods`);
}

function parseCsvLine(line) {
  const out = [];
  let cur = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (c === '"') {
      inQuotes = !inQuotes;
    } else if (c === ',' && !inQuotes) {
      out.push(cur.replace(/^"|"$/g, '').trim());
      cur = '';
    } else {
      cur += c;
    }
  }
  out.push(cur.replace(/^"|"$/g, '').trim());
  return out;
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
