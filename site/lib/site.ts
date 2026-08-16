/** The site's own host, in one place.
 *
 * It was written out by hand in four files and sixteen places, so when the live domain
 * turned out to be different from the one in the copy, every install command on the page
 * pointed at a host that does not resolve — the page looked finished and nothing on it ran.
 */
export const SITE_HOST = 'open-lzt.chqcode.com';

/** Full origin, for metadata and clipboard commands. */
export const SITE_URL = `https://${SITE_HOST}`;

/**
 * Where the hosted service lives.
 *
 * This site is built without any bot token, so the name cannot be resolved here — the panel
 * asks Telegram for its own username at startup and falls back to this same handle. Keeping the
 * two in step is the whole reason the fallback is spelled out in both places rather than left
 * implicit on one side.
 *
 * The page still renders without the button if this is ever emptied: a wrong link on a public
 * page costs the reader's trust once and silently — he taps, lands nowhere, and does not come
 * back to report it.
 */
export const HOSTED_BOT_HANDLE = 'OpenLztBot';
export const HOSTED_BOT_URL = `https://t.me/${HOSTED_BOT_HANDLE}`;

export type ScriptName = 'all' | 'update' | 'flow' | 'demo' | 'eventus';

/** A published script's URL: `scriptUrl('demo')` → `https://<host>/get/demo.sh`. */
export function scriptUrl(name: ScriptName): string {
  return `${SITE_URL}/get/${name}.sh`;
}

/** The command to run a published script, as a pipe.
 *
 * NOT `sudo bash <(curl …)`: sudo closes inherited descriptors, so the process
 * substitution's `/dev/fd/63` is gone by the time bash opens it and the whole thing
 * dies with "No such file or directory" plus a curl write failure. The pipe has no
 * descriptor to lose. Arguments ride after `-s --`, which is what lets a piped
 * script receive them at all.
 */
export function runCommand(name: ScriptName, args = '', { short = false } = {}): string {
  const url = short ? `${SITE_HOST}/get/${name}.sh` : scriptUrl(name);
  return `curl -sSL ${url} | sudo bash${args ? ` -s -- ${args}` : ''}`;
}
