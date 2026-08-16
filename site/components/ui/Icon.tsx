/**
 * SVG sprite. Emoji are banned in chrome and copy: they render per-OS, ignore
 * `currentColor` and cannot be animated.
 */

export type IconName =
  | 'logo'
  | 'gh'
  | 'py'
  | 'flask'
  | 'bolt'
  | 'flow'
  | 'mcp'
  | 'sdk'
  | 'box'
  | 'ui'
  | 'plug'
  | 'check'
  | 'clock'
  | 'up'
  | 'bell';

const P: Record<IconName, React.ReactNode> = {
  logo: (
    <>
      <path d="M12 3l8 5v8l-8 5-8-5V8z" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinejoin="round" />
      <circle cx="12" cy="12" r="2.6" fill="currentColor" />
    </>
  ),
  gh: (
    <path
      d="M12 2a10 10 0 00-3.16 19.49c.5.09.68-.22.68-.48v-1.7c-2.78.6-3.37-1.34-3.37-1.34-.45-1.16-1.11-1.47-1.11-1.47-.9-.62.07-.61.07-.61 1 .07 1.53 1.03 1.53 1.03.89 1.52 2.34 1.08 2.91.83.09-.65.35-1.09.63-1.34-2.22-.25-4.56-1.11-4.56-4.94 0-1.09.39-1.98 1.03-2.68-.1-.25-.45-1.27.1-2.64 0 0 .84-.27 2.75 1.02a9.56 9.56 0 015 0c1.91-1.29 2.75-1.02 2.75-1.02.55 1.37.2 2.39.1 2.64.64.7 1.03 1.59 1.03 2.68 0 3.84-2.34 4.68-4.57 4.93.36.31.68.92.68 1.85V21c0 .27.18.58.69.48A10 10 0 0012 2z"
      fill="currentColor"
    />
  ),
  py: (
    <>
      <path d="M8.5 4.5h7v3h-4v2h7v9.5h-7v-3h4v-2h-7z" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round" />
      <circle cx="10" cy="6.4" r=".9" fill="currentColor" />
      <circle cx="14" cy="17.4" r=".9" fill="currentColor" />
    </>
  ),
  flask: (
    <>
      <path d="M9.5 3h5M10.5 3v5.2L5.2 17a2.4 2.4 0 002.1 3.6h9.4a2.4 2.4 0 002.1-3.6L13.5 8.2V3" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M8 14h8" stroke="currentColor" strokeWidth="1.7" />
    </>
  ),
  bolt: <path d="M13 2L4.5 13.5H11L10 22l8.5-11.5H13z" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinejoin="round" />,
  flow: (
    <>
      <rect x="3" y="3.5" width="6.5" height="5.5" rx="1.5" fill="none" stroke="currentColor" strokeWidth="1.6" />
      <rect x="14.5" y="15" width="6.5" height="5.5" rx="1.5" fill="none" stroke="currentColor" strokeWidth="1.6" />
      <path d="M9.5 6.5h5a3 3 0 013 3V15" fill="none" stroke="currentColor" strokeWidth="1.6" />
    </>
  ),
  mcp: (
    <>
      <circle cx="12" cy="12" r="3" fill="none" stroke="currentColor" strokeWidth="1.7" />
      <path d="M12 2.5V7m0 10v4.5M2.5 12H7m10 0h4.5" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
    </>
  ),
  sdk: <path d="M8.5 7.5L4 12l4.5 4.5m7-9L20 12l-4.5 4.5" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />,
  box: (
    <>
      <path d="M12 2.5l8 4.5v10l-8 4.5-8-4.5V7z" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" />
      <path d="M4 7l8 4.5L20 7M12 11.5V21" fill="none" stroke="currentColor" strokeWidth="1.6" />
    </>
  ),
  ui: (
    <>
      <rect x="3" y="4" width="18" height="16" rx="2.5" fill="none" stroke="currentColor" strokeWidth="1.6" />
      <path d="M3 9h18M8 9v11" stroke="currentColor" strokeWidth="1.6" />
    </>
  ),
  plug: <path d="M9 3v5m6-5v5M7 8h10v3a5 5 0 01-5 5 5 5 0 01-5-5zM12 16v5" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" />,
  check: <path d="M4.5 12.5l5 5 10-11" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />,
  clock: (
    <>
      <circle cx="12" cy="12" r="8.5" fill="none" stroke="currentColor" strokeWidth="1.7" />
      <path d="M12 7.5V12l3 2" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
    </>
  ),
  up: <path d="M12 20V5m0 0l-6 6m6-6l6 6" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />,
  bell: <path d="M6 10a6 6 0 1112 0c0 4 1.5 5.5 1.5 5.5h-15S6 14 6 10zM10 19a2 2 0 004 0" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" />,
};

export function Icon({ name, size = 24 }: { name: IconName; size?: number }) {
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} aria-hidden="true">
      {P[name]}
    </svg>
  );
}
