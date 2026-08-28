/**
 * Unit tests for the shared-secret comparison helper (Deno).
 * Run: deno test supabase/functions/_shared/secret_compare_test.ts
 */

import {
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { secretsMatch } from "./secret_compare.ts";

Deno.test("matching secrets compare equal", () => {
  assertEquals(secretsMatch("s3cret-value", "s3cret-value"), true);
});

Deno.test("mismatched secrets are rejected", () => {
  assertEquals(secretsMatch("s3cret-value", "s3cret-valuf"), false);
  assertEquals(secretsMatch("s3cret-value", "s3cret"), false);
  assertEquals(secretsMatch("s3cret", "s3cret-value"), false);
});

Deno.test("absent secrets fail closed", () => {
  assertEquals(secretsMatch(undefined, "anything"), false);
  assertEquals(secretsMatch(null, "anything"), false);
  assertEquals(secretsMatch("", "anything"), false);
  assertEquals(secretsMatch("expected", undefined), false);
  assertEquals(secretsMatch("expected", null), false);
  assertEquals(secretsMatch("expected", ""), false);
  assertEquals(secretsMatch("", ""), false);
});
