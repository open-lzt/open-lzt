import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';

import { FIELDS, INSTALL_FLAGS, INSTALL_FLOW_FLAGS, FLOW_MODULES } from '../lib/scripts';

const REPO = join(__dirname, '..', '..');

/**
 * Pull every token the script's argument parser matches out of its `case` branch.
 * Matching on the `case` block itself, not on a grep for `--`, is what makes this
 * a contract check rather than a coincidence: a flag mentioned only in a comment
 * or a help text does not count as accepted.
 */
function parseCaseFlags(scriptPath: string): string[] {
  // Переводы строк нормализуются ДО разбора. В репозитории они LF (`.gitattributes: eol=lf`),
  // но выгрузка на Windows отдаёт CRLF, и тогда `in\r\n` не совпадает с `in\n` — блок «не
  // найден», весь файл тестов падает на сборе, и выглядит это как сломанный контракт флагов, а
  // не как окончания строк. Замерено 16.08: `install.sh` в рабочей копии был CRLF, в HEAD — LF.
  const source = readFileSync(join(REPO, scriptPath), 'utf8').replace(/\r\n/g, '\n');
  // Якорь `^while` обязателен. Без него первым совпадал разбор ВНУТРИ вспомогательной функции
  // (`has_flag` в install.sh, с отступом), и проверка мерила чужой список: шесть флагов,
  // объявленных в коде и принимаемых скриптом, числились «не принимаемыми». Зелёного при этом
  // не было — был красный по неверной причине, что хуже: чинят не то.
  const block = /^while\s+\[\[\s*\$#[^\n]*\n\s*case\s+"\$1"\s+in\n([\s\S]*?)\n\s*esac/m.exec(
    source,
  );
  if (!block) throw new Error(`no top-level argument-parsing case block found in ${scriptPath}`);

  const flags = new Set<string>();
  for (const line of block[1].split('\n')) {
    // A case arm looks like:  --flag|-f)  … ;;   — the pattern list ends at the first ')'.
    const arm = /^\s*([^)\s][^)]*)\)/.exec(line);
    if (!arm) continue;
    for (const pattern of arm[1].split('|')) {
      const token = pattern.trim();
      if (token.startsWith('-')) flags.add(token);
    }
  }
  return [...flags].sort();
}

const CASES = [
  { name: 'install.sh', script: 'install.sh', declared: INSTALL_FLAGS },
  { name: 'install-flow.sh', script: 'install-flow.sh', declared: INSTALL_FLOW_FLAGS },
] as const;

describe.each(CASES)('$name flag contract', ({ script, declared }) => {
  const onDisk = parseCaseFlags(script);
  const inCode = [...declared].sort();

  it('parses a non-empty flag set out of the script', () => {
    expect(onDisk.length).toBeGreaterThan(0);
  });

  it('declares no flag the script does not accept', () => {
    expect(inCode.filter((f) => !onDisk.includes(f))).toEqual([]);
  });

  it('declares every flag the script accepts', () => {
    expect(onDisk.filter((f) => !inCode.includes(f))).toEqual([]);
  });
});

describe('builder fields', () => {
  it('only emit flags that exist in the matching contract', () => {
    const allowed = { stand: [...INSTALL_FLAGS], flow: [...INSTALL_FLOW_FLAGS] } as const;
    for (const mode of ['stand', 'flow'] as const) {
      for (const field of FIELDS[mode]) {
        expect(allowed[mode], `${mode}.${field.id}`).toContain(field.flag);
      }
    }
  });

  it('offers exactly the catalogue modules', () => {
    const module = FIELDS.flow.find((f) => f.id === 'module');
    expect(module?.options).toEqual([...FLOW_MODULES]);
  });
});

describe('flow catalogue', () => {
  const dir = join(REPO, 'lzt-flows', 'modules');
  const present = existsSync(dir);

  // The catalogue lives in a git submodule; a shallow checkout without it has
  // nothing to compare against, and an empty run must not score as a pass.
  it.skipIf(!present)('matches lzt-flows/modules on disk', () => {
    const onDisk = readdirSync(dir, { withFileTypes: true })
      .filter((e) => e.isDirectory())
      .map((e) => e.name)
      .sort();
    expect(onDisk).toEqual([...FLOW_MODULES].sort());
  });
});
