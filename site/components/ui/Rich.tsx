/**
 * Renders the `**bold**` markers the dictionaries carry.
 *
 * The alternative was JSX inside the content files, which would have made them
 * components instead of data — and killed the typed key check that catches a
 * translation gap at build time.
 */
export function Rich({ text }: { text: string }) {
  return (
    <>
      {text.split(/(\*\*[^*]+\*\*)/).map((part, i) =>
        part.startsWith('**') && part.endsWith('**') ? (
          <b key={i}>{part.slice(2, -2)}</b>
        ) : (
          part
        ),
      )}
    </>
  );
}
