// Publish-time only: copies the sibling CSS package into dist so `files` in
// package.json (["dist", "lzt-ui.css"]) has something real to ship.
import { copyFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
copyFileSync(join(here, '..', '..', 'lzt-ui.css'), join(here, '..', 'lzt-ui.css'));
