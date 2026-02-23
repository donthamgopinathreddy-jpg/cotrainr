#!/usr/bin/env node
/**
 * Seed food catalog from foods_catalog_250.csv + food_portions.csv
 * Uses admin_upsert_food and admin_upsert_portion RPCs (service_role only).
 *
 * Usage:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node scripts/seed_food_catalog.js
 *
 * Reads from data/foods_catalog_250.csv and data/food_portions.csv by default.
 * Optional: node scripts/seed_food_catalog.js [foods-csv] [portions-csv]
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(__dirname, '..');
const DEFAULT_FOODS_CSV = path.join(PROJECT_ROOT, 'data', 'foods_catalog_250.csv');
const DEFAULT_PORTIONS_CSV = path.join(PROJECT_ROOT, 'data', 'food_portions.csv');

const foodsPath = process.argv[2] || DEFAULT_FOODS_CSV;
const portionsPath = process.argv[3] || DEFAULT_PORTIONS_CSV;

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

if (!fs.existsSync(foodsPath)) {
  console.error('Foods CSV not found:', foodsPath);
  process.exit(1);
}

if (!fs.existsSync(portionsPath)) {
  console.error('Portions CSV not found:', portionsPath);
  process.exit(1);
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

function parseCsv(filePath) {
  const csv = fs.readFileSync(filePath, 'utf8');
  const lines = csv.trim().split(/\r?\n/);
  if (lines.length < 2) return { headers: [], rows: [] };
  const headers = parseCsvLine(lines[0]);
  const rows = [];
  for (let i = 1; i < lines.length; i++) {
    const vals = parseCsvLine(lines[i]);
    const row = {};
    headers.forEach((h, idx) => { row[h] = vals[idx] !== undefined ? vals[idx].trim() : ''; });
    rows.push(row);
  }
  return { headers, rows };
}

function validateMacros(row, lineNum) {
  const kcal = parseFloat(row.kcal_100g) || 0;
  const protein = parseFloat(row.protein_100g) || 0;
  const carbs = parseFloat(row.carbs_100g) || 0;
  const fat = parseFloat(row.fat_100g) || 0;
  const fiber = parseFloat(row.fiber_100g) || 0;

  if (kcal < 0 || protein < 0 || carbs < 0 || fat < 0 || fiber < 0) {
    throw new Error(`Row ${lineNum}: negative macro value`);
  }
  if (fiber > carbs) {
    throw new Error(`Row ${lineNum}: fiber (${fiber}) > carbs (${carbs})`);
  }
  const expectedKcal = 4 * (protein + carbs) + 9 * fat;
  const tolerance = 0.15 * expectedKcal;
  if (Math.abs(kcal - expectedKcal) > tolerance && expectedKcal > 10) {
    console.warn(`Row ${lineNum} (${row.name}): kcal ${kcal} vs expected ~${expectedKcal.toFixed(0)} (±15%)`);
  }
}

async function main() {
  const { createClient } = await import('@supabase/supabase-js');
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const { rows: foodRows } = parseCsv(foodsPath);
  const { rows: portionRows } = parseCsv(portionsPath);

  const seenNames = new Set();
  for (const row of foodRows) {
    const name = (row.name || '').trim();
    if (!name) continue;
    const key = name.toLowerCase();
    if (seenNames.has(key)) {
      throw new Error(`Duplicate food name (after normalization): ${name}`);
    }
    seenNames.add(key);
  }

  const nameToId = {};

  console.log(`Upserting ${foodRows.length} foods...`);
  let foodCount = 0;
  for (let i = 0; i < foodRows.length; i++) {
    const row = foodRows[i];
    const name = row.name;
    if (!name) continue;

    validateMacros(row, i + 2);

    const aliasesStr = row.aliases_pipe || row.aliases || '';
    const aliases = aliasesStr ? aliasesStr.split('|').map((s) => s.trim()).filter(Boolean) : null;

    let micros = null;
    const microsStr = (row.micros_json || '{}').trim();
    if (microsStr && microsStr !== '{}') {
      try {
        micros = JSON.parse(microsStr);
      } catch {
        micros = {};
      }
    } else {
      micros = {};
    }

    const { data: id, error } = await supabase.rpc('admin_upsert_food', {
      p_name: name.trim(),
      p_aliases: aliases,
      p_cuisine: row.cuisine || null,
      p_category: row.category || null,
      p_is_prepared: /^(true|1|yes)$/i.test(row.is_prepared || ''),
      p_source: row.source || null,
      p_source_ref: row.source_ref || null,
      p_kcal_100g: parseFloat(row.kcal_100g) || 0,
      p_protein_100g: parseFloat(row.protein_100g) || 0,
      p_carbs_100g: parseFloat(row.carbs_100g) || 0,
      p_fat_100g: parseFloat(row.fat_100g) || 0,
      p_fiber_100g: parseFloat(row.fiber_100g) || 0,
      p_micros: micros,
      p_verified: /^(true|1|yes)$/i.test(row.verified || ''),
    });

    if (error) {
      throw new Error(`Food ${name}: ${error.message}`);
    } else {
      nameToId[name] = id;
      foodCount++;
      if (foodCount % 50 === 0) {
        console.log(`  ... ${foodCount} foods`);
      }
    }
  }
  console.log(`Upserted ${foodCount} foods.`);

  let portionCount = 0;

  console.log(`Upserting portions...`);
  for (let i = 0; i < portionRows.length; i++) {
    const row = portionRows[i];
    const foodName = row.food_name;
    const label = row.label;
    const grams = parseFloat(row.grams);
    const isDefault = /^(true|1|yes)$/i.test(row.is_default || '');

    if (!foodName || !label || !grams || grams <= 0) {
      throw new Error(`Invalid portion row ${i + 2}: food_name, label, grams>0 required`);
    }

    const foodId = nameToId[foodName];
    if (!foodId) {
      throw new Error(`Portion references unknown food: ${foodName}`);
    }

    const { error } = await supabase.rpc('admin_upsert_portion', {
      p_food_id: foodId,
      p_label: label,
      p_grams: grams,
      p_is_default: isDefault,
    });

    if (error) {
      throw new Error(`Portion ${foodName} / ${label}: ${error.message}`);
    } else {
      portionCount++;
      if (portionCount % 50 === 0) {
        console.log(`  ... ${portionCount} portions`);
      }
    }
  }
  console.log(`Upserted ${portionCount} portions.`);
  console.log('Done.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
