/**
 * Single source of truth for what the installer scripts accept.
 *
 * `tests/flags.contract.test.ts` parses the `case` branch out of the real
 * install.sh / install-flow.sh on disk and asserts an exact match with the
 * lists below, in both directions. A flag invented here, or one added to a
 * script and not mirrored here, turns the build red.
 */

import { runCommand, scriptUrl } from '@/lib/site';

/** Every token the install.sh argument parser matches, verbatim. */
export const INSTALL_FLAGS = [
  '--dry-run',
  '--yes',
  '-y',
  '--non-interactive',
  '--bot-token',
  '--bot-admins',
  '--domain',
  '--email',
  '--tls',
  '--market-mode',
  '-h',
  '--help',
] as const;

/** Every token the install-flow.sh argument parser matches, verbatim. */
export const INSTALL_FLOW_FLAGS = [
  '--module',
  '--param',
  '--run',
  '--account',
  '--cron',
  '--no-run',
  // Принимается скриптом (`install-flow.sh`, арм `--prod) ALLOW_PROD=1`) и не был объявлен здесь.
  // Нашлось, когда контракт впервые запустился: до этого весь файл тестов падал на сборе.
  '--prod',
  '--dir',
  '-h',
  '--help',
] as const;

export type InstallFlag = (typeof INSTALL_FLAGS)[number];
export type InstallFlowFlag = (typeof INSTALL_FLOW_FLAGS)[number];

/** Catalogue modules, from lzt-flows/modules/. */
export const FLOW_MODULES = [
  'bump-daily',
  'steam-autobuy',
  'riot-autobuy',
  'supercell-autobuy',
  'fortnite-autobuy',
  'telegram-autobuy',
  'sniper-autobuy',
  'notify-pack',
  'pricing-pack',
] as const;

export const MARKET_MODES = ['testnet', 'prod'] as const;
export const TLS_MODES = ['selfsigned', 'none'] as const;

export type MarketMode = (typeof MARKET_MODES)[number];

export const GET_URL = {
  stand: scriptUrl('all'),
  flow: scriptUrl('flow'),
} as const;

export type BuilderMode = keyof typeof GET_URL;

/* ── declarative field model ──────────────────────────────────────────────
   Fields are described once. The form renders from this list and the command
   string is emitted from the same list — there is no second place that knows
   which flag a field carries. */

export type FieldKind = 'choice' | 'text' | 'toggle' | 'pairs';

export interface Pair {
  k: string;
  v: string;
}

export type FieldValue = string | boolean | Pair[];

export interface FieldSpec {
  /** State key. */
  id: string;
  /** Flag emitted for this field. Typed against the parsed script contract. */
  flag: InstallFlag | InstallFlowFlag;
  kind: FieldKind;
  /** Full-width in the two-column grid. */
  wide?: boolean;
  /** Choice options; for `toggle` the flag is emitted when the value is true. */
  options?: readonly string[];
  /** `--flag <value>` when false, bare `--flag` when true. */
  bare?: boolean;
  /** A value equal to this emits nothing (the script's own default). */
  omitWhen?: string | boolean;
  /** Companion field that must be filled for either to be emitted. */
  requires?: string;
  /** Never written to the URL — a secret would leak via history and referrer. */
  secret?: boolean;
  defaultValue: FieldValue;
}

export const STAND_FIELDS: readonly FieldSpec[] = [
  {
    id: 'market',
    flag: '--market-mode',
    kind: 'choice',
    options: MARKET_MODES,
    defaultValue: 'testnet',
  },
  // selfsigned is what install.sh does on a bare IP anyway — emitting it would
  // add noise to the command without changing what happens.
  {
    id: 'tls',
    flag: '--tls',
    kind: 'choice',
    options: TLS_MODES,
    omitWhen: 'selfsigned',
    defaultValue: 'selfsigned',
  },
  { id: 'domain', flag: '--domain', kind: 'text', requires: 'email', defaultValue: '' },
  { id: 'email', flag: '--email', kind: 'text', requires: 'domain', defaultValue: '' },
  { id: 'botToken', flag: '--bot-token', kind: 'text', secret: true, defaultValue: '' },
  { id: 'botAdmins', flag: '--bot-admins', kind: 'text', defaultValue: '' },
  // Выключен по умолчанию, и это не осторожность, а исправление. Включённым он давал первой
  // же команде, которую человек копирует не тронув ни одного поля, вид рабочей: скрипт
  // молчит, ставит стенд и не спрашивает токен бота с админами, которых в команде нет.
  // Установка зелёная, бот не стартует, причины на экране никакой.
  { id: 'yes', flag: '--yes', kind: 'toggle', bare: true, defaultValue: false },
  { id: 'dryRun', flag: '--dry-run', kind: 'toggle', bare: true, defaultValue: false },
];

export const FLOW_FIELDS: readonly FieldSpec[] = [
  {
    id: 'module',
    flag: '--module',
    kind: 'choice',
    options: FLOW_MODULES,
    wide: true,
    defaultValue: 'bump-daily',
  },
  { id: 'params', flag: '--param', kind: 'pairs', wide: true, defaultValue: [] },
  { id: 'account', flag: '--account', kind: 'text', defaultValue: '' },
  { id: 'cron', flag: '--cron', kind: 'text', defaultValue: '' },
  { id: 'run', flag: '--run', kind: 'toggle', bare: true, defaultValue: true },
  { id: 'noRun', flag: '--no-run', kind: 'toggle', bare: true, defaultValue: false },
];

export const FIELDS: Record<BuilderMode, readonly FieldSpec[]> = {
  stand: STAND_FIELDS,
  flow: FLOW_FIELDS,
};

export type BuilderState = Record<string, FieldValue>;

export function defaultState(mode: BuilderMode): BuilderState {
  const state: BuilderState = {};
  for (const f of FIELDS[mode]) state[f.id] = f.defaultValue;
  return state;
}

/** Shell-quote a value only when it needs it — a quoted domain reads as noise. */
function q(value: string): string {
  return /^[A-Za-z0-9._@:/,+=-]+$/.test(value) ? value : `'${value.replace(/'/g, `'\\''`)}'`;
}

/** The argv the command carries, derived from the field list alone. */
export function buildArgs(mode: BuilderMode, state: BuilderState): string[] {
  const args: string[] = [];
  for (const f of FIELDS[mode]) {
    const value = state[f.id];

    if (f.kind === 'toggle') {
      if (value === true) args.push(f.flag);
      continue;
    }
    if (f.kind === 'pairs') {
      for (const p of (value as Pair[]) ?? []) {
        if (p.k.trim() && p.v.trim()) args.push(f.flag, q(`${p.k.trim()}=${p.v.trim()}`));
      }
      continue;
    }
    const text = String(value ?? '').trim();
    if (!text) continue;
    if (f.omitWhen !== undefined && text === f.omitWhen) continue;
    if (f.requires && !String(state[f.requires] ?? '').trim()) continue;
    args.push(f.flag, q(text));
  }
  return args;
}

/** One paste-ready line. Piped, never `sudo bash <(…)` — see `runCommand`. */
export function buildCommand(mode: BuilderMode, state: BuilderState): string {
  return runCommand(mode === 'stand' ? 'all' : 'flow', buildArgs(mode, state).join(' '));
}

/** Fields that are safe to put in a shareable link — secrets never are. */
export function shareableParams(mode: BuilderMode, state: BuilderState): URLSearchParams {
  const params = new URLSearchParams();
  params.set('mode', mode);
  for (const f of FIELDS[mode]) {
    if (f.secret) continue;
    const value = state[f.id];
    if (f.kind === 'pairs') {
      const pairs = (value as Pair[]).filter((p) => p.k.trim() && p.v.trim());
      if (pairs.length) params.set(f.id, pairs.map((p) => `${p.k}=${p.v}`).join(','));
      continue;
    }
    if (value === f.defaultValue) continue;
    if (typeof value === 'boolean') params.set(f.id, value ? '1' : '0');
    else if (String(value).trim()) params.set(f.id, String(value));
  }
  return params;
}

export function stateFromParams(mode: BuilderMode, params: URLSearchParams): BuilderState {
  const state = defaultState(mode);
  for (const f of FIELDS[mode]) {
    if (f.secret) continue;
    const raw = params.get(f.id);
    if (raw === null) continue;
    if (f.kind === 'toggle') state[f.id] = raw === '1';
    else if (f.kind === 'pairs') {
      state[f.id] = raw
        .split(',')
        .filter((chunk) => chunk.includes('='))
        .map((chunk) => ({ k: chunk.slice(0, chunk.indexOf('=')), v: chunk.slice(chunk.indexOf('=') + 1) }));
    } else if (f.options && !f.options.includes(raw)) continue;
    else state[f.id] = raw;
  }
  return state;
}
