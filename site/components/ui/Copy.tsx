'use client';

import type { InstallBlock } from '@/content/types';
import { useCopy } from '@/hooks/useCopy';

/**
 * Every copy surface on the page, driven by one `useCopy` instance per block:
 * a command row, a flag chip, and the copy-all button that collects its rows.
 */

export function InstallBox({ block, labels }: { block: InstallBlock; labels: { copyAll: string; copied: string } }) {
  const { copiedId, copy } = useCopy();
  const all = block.rows.map((r) => r.copy).join('\n');

  return (
    <div className="p-install">
      <span className="lbl">
        {block.title}
        <button
          type="button"
          className={`copyall${copiedId === 'all' ? ' copied' : ''}`}
          onClick={() => copy(all, 'all')}
        >
          <CopyIcon />
          {copiedId === 'all' ? labels.copied : labels.copyAll}
        </button>
      </span>

      {block.rows.map((row, i) => (
        <div
          key={i}
          className={`row${copiedId === `r${i}` ? ' copied' : ''}`}
          onClick={() => copy(row.copy, `r${i}`)}
          role="button"
          tabIndex={0}
          onKeyDown={(e) => (e.key === 'Enter' || e.key === ' ') && copy(row.copy, `r${i}`)}
        >
          <span className="ps">{row.ps}</span>
          {row.label}
          <span className="ok">{labels.copied}</span>
        </div>
      ))}

      {block.opts?.length ? (
        <div className="opts">
          <span className="cap">{block.optsTitle}</span>
          {block.opts.map((chip, i) => (
            <span
              key={i}
              className={`chipcopy${copiedId === `c${i}` ? ' copied' : ''}`}
              onClick={() => copy(chip.copy, `c${i}`)}
              role="button"
              tabIndex={0}
              onKeyDown={(e) => (e.key === 'Enter' || e.key === ' ') && copy(chip.copy, `c${i}`)}
            >
              {chip.label}
            </span>
          ))}
        </div>
      ) : null}

      {block.note ? <div className="note">{block.note}</div> : null}
    </div>
  );
}

/** Standalone clickable value — the hero's pip line and the CTA url plate. */
export function CopyPlate({
  text,
  copyText,
  className,
  prefix,
  copiedLabel,
}: {
  text: string;
  copyText: string;
  className: string;
  prefix?: string;
  copiedLabel: string;
}) {
  const { copiedId, copy } = useCopy();
  return (
    <span
      className={`${className}${copiedId ? ' copied' : ''}`}
      onClick={() => copy(copyText, 'plate')}
      role="button"
      tabIndex={0}
      onKeyDown={(e) => (e.key === 'Enter' || e.key === ' ') && copy(copyText, 'plate')}
    >
      {prefix ? <span className="ps">{prefix}</span> : null}
      {text}
      {copiedId ? <span className="ok">{copiedLabel}</span> : <CopyIcon />}
    </span>
  );
}

export function CopyIcon({ size = 15 }: { size?: number }) {
  // An <svg> with only a viewBox has no intrinsic size and inflates whatever
  // flex parent holds it — that is how the copy button ended up huge.
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} aria-hidden="true">
      <rect x="9" y="9" width="11" height="11" rx="2" fill="none" stroke="currentColor" strokeWidth="1.7" />
      <path
        d="M5 15H4a1.5 1.5 0 01-1.5-1.5v-9A1.5 1.5 0 014 3h9A1.5 1.5 0 0114.5 4.5V5"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.7"
      />
    </svg>
  );
}
