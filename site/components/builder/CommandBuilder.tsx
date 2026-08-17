'use client';

import { useEffect, useMemo, useState } from 'react';

import {
  buildCommand,
  defaultState,
  FIELDS,
  shareableParams,
  stateFromParams,
  type BuilderMode,
  type BuilderState,
  type FieldSpec,
  type Pair,
} from '@/lib/scripts';
import type { Content } from '@/content/types';
import { useCopy } from '@/hooks/useCopy';
import { CheckIcon, CopyIcon } from '@/components/ui/Copy';

type T = Content['builder'];

/**
 * The killer feature: it turns the landing page into a tool.
 *
 * Every field comes from `lib/scripts.ts`, and so does the command string —
 * there is no second list of flags anywhere. `install.sh` installs the whole
 * stand, so there is deliberately no "pick components" control: inventing one
 * would hand the visitor a command the script rejects.
 */
export function CommandBuilder({ t }: { t: T }) {
  const [mode, setMode] = useState<BuilderMode>('stand');
  const [state, setState] = useState<BuilderState>(() => defaultState('stand'));
  const [prodOk, setProdOk] = useState(false);

  // A shared link reproduces the setup. Read once on mount - after that the URL
  // follows the state, never the other way round.
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const urlMode = params.get('mode');
    if (urlMode !== 'stand' && urlMode !== 'flow') return;
    setMode(urlMode);
    setState(stateFromParams(urlMode, params));
  }, []);

  const command = useMemo(() => buildCommand(mode, state), [mode, state]);
  const isProd = mode === 'stand' && state.market === 'prod';
  const locked = isProd && !prodOk;

  const { copiedId, copy } = useCopy(1400);

  function switchMode(next: BuilderMode) {
    setMode(next);
    setState(defaultState(next));
    setProdOk(false);
  }

  function set(id: string, value: BuilderState[string]) {
    setState((prev) => ({ ...prev, [id]: value }));
    if (id === 'market' && value !== 'prod') setProdOk(false);
  }

  function share() {
    const url = `${window.location.origin}${window.location.pathname}?${shareableParams(mode, state)}`;
    copy(url, 'share');
  }

  return (
    // A <form> because the token field is a password input: outside a form the
    // browser warns, and Enter has nowhere sensible to go. Nothing is submitted —
    // the command is built locally and copied.
    <form className={`bld${isProd ? ' danger' : ''}`} aria-label={t.title} onSubmit={(e) => e.preventDefault()}>
      <div className="bld-head">
        <span className="bld-title">{t.title}</span>
        <div className="bld-tabs" role="tablist">
          {(['stand', 'flow'] as const).map((m) => (
            <button
              key={m}
              type="button"
              role="tab"
              aria-selected={mode === m}
              className={`bld-tab${mode === m ? ' on' : ''}`}
              onClick={() => switchMode(m)}
            >
              {m === 'stand' ? t.tabStand : t.tabFlow}
            </button>
          ))}
        </div>
      </div>

      <div className="bld-body">
        {FIELDS[mode].map((field) => (
          <Field key={field.id} spec={field} value={state[field.id]} onChange={set} t={t} />
        ))}
      </div>

      {isProd ? (
        <div className="bld-alert">
          <span>{t.prodWarning}</span>
          <button
            type="button"
            role="switch"
            aria-checked={prodOk}
            className={`sw-row${prodOk ? ' on' : ''}`}
            onClick={() => setProdOk((v) => !v)}
          >
            <span className="sw-box" />
            <span className="sw-txt">{t.prodConfirm}</span>
          </button>
        </div>
      ) : null}

      <div className="bld-out">
        <code className="bld-cmd">{command}</code>
        <button
          type="button"
          className={`bld-copy${isProd ? ' danger' : ''}`}
          onClick={() => copy(command, 'cmd')}
          disabled={locked}
          title={locked ? t.prodWarning : undefined}
        >
          {copiedId === 'cmd' ? <CheckIcon label={t.copied} /> : <CopyIcon />} {t.copy}
        </button>
      </div>

      <div className="bld-foot">
        <button type="button" className="bld-share" onClick={share}>
          {copiedId === 'share' ? t.shared : t.share}
        </button>
        <button type="button" className="bld-share" onClick={() => switchMode(mode)}>
          {t.reset}
        </button>
      </div>
    </form>
  );
}

function Field({
  spec,
  value,
  onChange,
  t,
}: {
  spec: FieldSpec;
  value: BuilderState[string];
  onChange: (id: string, value: BuilderState[string]) => void;
  t: T;
}) {
  const copy = t.fields[spec.id] ?? { label: spec.id };

  if (spec.kind === 'toggle') {
    const on = value === true;
    return (
      <button
        type="button"
        role="switch"
        aria-checked={on}
        className={`sw-row${on ? ' on' : ''}`}
        onClick={() => onChange(spec.id, !on)}
      >
        <span className="sw-box" />
        <span className="sw-txt">{copy.label}</span>
        {copy.hint ? <span className="sw-flag">{copy.hint}</span> : null}
      </button>
    );
  }

  if (spec.kind === 'choice') {
    return (
      <div className={`fld${spec.wide ? ' fld-wide' : ''}`}>
        <span className="fld-lbl">{copy.label}</span>
        {spec.options && spec.options.length <= 3 ? (
          <div className="seg" role="radiogroup" aria-label={copy.label}>
            {spec.options.map((opt) => (
              <button
                key={opt}
                type="button"
                role="radio"
                aria-checked={value === opt}
                className={`seg-btn${value === opt ? ' on' : ''}`}
                onClick={() => onChange(spec.id, opt)}
              >
                {opt}
              </button>
            ))}
          </div>
        ) : (
          <select className="txt" value={String(value)} onChange={(e) => onChange(spec.id, e.target.value)}>
            {spec.options?.map((opt) => (
              <option key={opt} value={opt}>
                {opt}
              </option>
            ))}
          </select>
        )}
        {copy.hint ? <span className="fld-hint">{copy.hint}</span> : null}
      </div>
    );
  }

  if (spec.kind === 'pairs') {
    const pairs = (value as Pair[]) ?? [];
    const update = (next: Pair[]) => onChange(spec.id, next);
    return (
      <div className="fld fld-wide">
        <span className="fld-lbl">{copy.label}</span>
        <div className="params">
          {pairs.map((pair, i) => (
            <div className="param-row" key={i}>
              <input
                className="txt"
                type="text"
                placeholder={t.paramKey}
                value={pair.k}
                onChange={(e) => update(pairs.map((p, j) => (j === i ? { ...p, k: e.target.value } : p)))}
              />
              <input
                className="txt"
                type="text"
                inputMode="decimal"
                placeholder={t.paramValue}
                value={pair.v}
                onChange={(e) => update(pairs.map((p, j) => (j === i ? { ...p, v: e.target.value } : p)))}
              />
              <button
                type="button"
                className="icon-btn"
                aria-label="remove"
                onClick={() => update(pairs.filter((_, j) => j !== i))}
              >
                ×
              </button>
            </div>
          ))}
          <button type="button" className="icon-btn wide" onClick={() => update([...pairs, { k: '', v: '' }])}>
            + {t.addParam}
          </button>
        </div>
      </div>
    );
  }

  // text — never `type="number"`: it hijacks the scroll wheel and adds spinners.
  return (
    <div className={`fld${spec.wide ? ' fld-wide' : ''}`}>
      <span className="fld-lbl">{copy.label}</span>
      <input
        className="txt"
        type={spec.secret ? 'password' : 'text'}
        autoComplete={spec.secret ? 'off' : undefined}
        spellCheck={false}
        value={String(value ?? '')}
        onChange={(e) => onChange(spec.id, e.target.value)}
      />
      {copy.hint ? <span className="fld-hint">{copy.hint}</span> : null}
    </div>
  );
}
