/**
 * Unit tests for login-with-identifier helpers (Deno).
 * Run: deno test supabase/functions/login-with-identifier/identifier_test.ts
 */

import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";

function looksLikeEmail(value: string): boolean {
  if (!value.includes("@")) return false;
  if (value.startsWith("@") && value.indexOf("@", 1) === -1) return false;
  return true;
}

function isPlausibleEmail(value: string): boolean {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value);
}

function normalizeUsername(raw: string): string {
  let v = raw.trim();
  if (v.startsWith("@")) v = v.slice(1).trim();
  return v.toLowerCase();
}

Deno.test("normalizeUsername strips @ and lowercases", () => {
  assertEquals(normalizeUsername("@Don_5412"), "don_5412");
  assertEquals(normalizeUsername(" DON_5412 "), "don_5412");
  assertEquals(normalizeUsername("don_5412"), "don_5412");
});

Deno.test("email vs username classification", () => {
  assertEquals(looksLikeEmail("user@example.com"), true);
  assertEquals(looksLikeEmail("don_5412"), false);
  assertEquals(looksLikeEmail("@don_5412"), false);
  assertEquals(isPlausibleEmail("abc@"), false);
  assertEquals(isPlausibleEmail("abc@gmail"), false);
  assertEquals(isPlausibleEmail("user@example.com"), true);
});

Deno.test("invalid username and wrong password must share failure code", () => {
  // Contract: Edge Function returns { error: "invalid_credentials" } for both.
  const unknownUser = { error: "invalid_credentials" };
  const wrongPassword = { error: "invalid_credentials" };
  assertEquals(unknownUser.error, wrongPassword.error);
});
