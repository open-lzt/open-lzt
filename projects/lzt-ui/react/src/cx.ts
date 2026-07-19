export type ClassValue = string | number | false | null | undefined;

/** Joins truthy class fragments with a space. Local stand-in for `clsx` — no new dependency. */
export function cx(...values: ClassValue[]): string {
  return values.filter(Boolean).join(' ');
}
