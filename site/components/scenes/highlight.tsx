import type { ReactNode } from 'react';

/**
 * Minimal Python/shell colouring for the landing's code scenes.
 *
 * ONE pass over the source, emitting React nodes.
 *
 * The obvious version — run a `.replace()` per rule over an HTML string — is
 * broken and was shipped once here: the comment rule wraps text in
 * `<span class="c-cm">`, and the string rule then matches the quotes *inside
 * that attribute* and mangles the markup. Chaining regexes over generated HTML
 * always has this bug. Emitting nodes also removes the `dangerouslySetInnerHTML`
 * that made it possible in the first place.
 */

const TOKEN =
  /(#[^\n]*)|("(?:[^"\\]|\\.)*")|\b(from|import|async|with|as|for|in|await|return|def|class|None|True|False)\b|\b(\d+)\b/g;

const CLASS_FOR_GROUP = ['c-cm', 'c-str', 'c-kw', 'c-num'] as const;

export function highlight(source: string): ReactNode {
  const out: ReactNode[] = [];
  let last = 0;
  let key = 0;

  for (const match of source.matchAll(TOKEN)) {
    const at = match.index ?? 0;
    if (at > last) out.push(source.slice(last, at));

    // Groups are 1-based and mutually exclusive: exactly one matched.
    const group = CLASS_FOR_GROUP.findIndex((_, i) => match[i + 1] !== undefined);
    out.push(
      <span className={CLASS_FOR_GROUP[group]} key={key++}>
        {match[0]}
      </span>,
    );
    last = at + match[0].length;
  }

  if (last < source.length) out.push(source.slice(last));
  return out;
}
