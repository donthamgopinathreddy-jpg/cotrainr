// Constant-time secret comparison for Edge Function shared secrets.
// Never log the values passed in here.

/// Compares two secrets without leaking length or position via timing.
/// Returns false for empty/undefined inputs so callers fail closed.
export function secretsMatch(
  expected: string | null | undefined,
  provided: string | null | undefined,
): boolean {
  if (!expected || !provided) return false;

  const encoder = new TextEncoder();
  const a = encoder.encode(expected);
  const b = encoder.encode(provided);

  // Compare a fixed number of bytes so mismatched lengths cost the same time.
  const length = Math.max(a.length, b.length);
  let diff = a.length ^ b.length;
  for (let i = 0; i < length; i++) {
    diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  return diff === 0;
}
