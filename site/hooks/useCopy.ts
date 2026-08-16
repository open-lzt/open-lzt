'use client';

import { useCallback, useRef, useState } from 'react';

/**
 * One copy mechanism for the whole page.
 *
 * The prototype grew three of these — one for command rows, one for flag chips,
 * one for the copy-all button — and they drifted. Here a single hook owns both
 * the clipboard call and the "which element just confirmed" state; every copy
 * surface passes its own id and compares against `copiedId`.
 */
export function useCopy(resetAfterMs = 900) {
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const copy = useCallback(
    (text: string, id: string) => {
      // Older Safari and any non-secure origin have no clipboard API; the fallback
      // keeps the button honest instead of silently doing nothing.
      const write = navigator.clipboard?.writeText(text) ?? legacyCopy(text);

      Promise.resolve(write)
        .then(() => {
          setCopiedId(id);
          if (timer.current) clearTimeout(timer.current);
          timer.current = setTimeout(() => setCopiedId(null), resetAfterMs);
        })
        .catch(() => setCopiedId(null));
    },
    [resetAfterMs],
  );

  return { copiedId, copy };
}

function legacyCopy(text: string): Promise<void> {
  const area = document.createElement('textarea');
  area.value = text;
  area.setAttribute('readonly', '');
  area.style.position = 'fixed';
  area.style.opacity = '0';
  document.body.appendChild(area);
  area.select();
  const ok = document.execCommand('copy');
  document.body.removeChild(area);
  return ok ? Promise.resolve() : Promise.reject(new Error('copy failed'));
}
