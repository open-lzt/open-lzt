'use client';

import { useState } from 'react';

import type { Content } from '@/content/types';
import { CopyPlate } from '@/components/ui/Copy';
import { Rich } from '@/components/ui/Rich';
import { useCopy } from '@/hooks/useCopy';
import { Icon } from '@/components/ui/Icon';
import { Qr } from '@/components/ui/Qr';

/** Tabbed install block. Every line copies in full, however it is abbreviated. */
export function InstallSection({ t }: { t: Content['install'] }) {
  const [tab, setTab] = useState(t.tabs[0].id);
  const { copiedId, copy } = useCopy();
  const active = t.tabs.find((x) => x.id === tab) ?? t.tabs[0];

  return (
    <section className="sec install" id="install">
      <div className="sec-head reveal is-in">
        <h2>
          {t.title} <span className="g">{t.titleAccent}</span>
        </h2>
        <p>{t.sub}</p>
        <p className="sec-req">{t.req}</p>
      </div>

      <div className="reveal is-in">
        <div className="tabs" role="tablist">
          {t.tabs.map((item) => (
            <button
              key={item.id}
              type="button"
              role="tab"
              aria-selected={item.id === tab}
              className={`tab${item.id === tab ? ' on' : ''}`}
              onClick={() => setTab(item.id)}
            >
              {item.label}
            </button>
          ))}
        </div>

        <div className="scene">
          <div className="term-bar">
            <i />
            <i />
            <i />
            <span className="ttl">{active.label}</span>
          </div>
          {/* key on the tab id replays the entrance: a pane that shows up already
              finished makes every state after the first read dead. */}
          <div className="term-body pane on replay" key={active.id} style={{ whiteSpace: 'normal', minHeight: 150 }}>
            {active.rows.map((row, i) => (
              <div
                className={`cmd${copiedId === `${active.id}-${i}` ? ' copied' : ''}`}
                key={i}
                role="button"
                tabIndex={0}
                onClick={() => copy(row.copy, `${active.id}-${i}`)}
                onKeyDown={(e) => (e.key === 'Enter' || e.key === ' ') && copy(row.copy, `${active.id}-${i}`)}
              >
                <span>
                  <span className="ps">{row.ps}</span> {row.label}
                </span>
                <span className="ok">✓</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

export function CtaSection({ t }: { t: Content['cta'] }) {
  return (
    <section className="cta reveal is-in">
      <div>
        <h2>
          {t.title} <span className="g">{t.titleAccent}</span>
        </h2>
        <CopyPlate
          className="url-plate"
          text={t.url}
          copyText={`https://${t.url}`}
          copiedLabel={t.copied}
        />
      </div>
      <div className="cta-text">
        <Rich text={t.text} />
      </div>
      <Qr />
    </section>
  );
}

export function Footer({ t, locale }: { t: Content; locale: 'ru' | 'en' }) {
  return (
    <footer>
      <div className="foot">
        <a className="brand" href="#top">
          <span className="brand-mark">
            <Icon name="logo" size={15} />
          </span>
          OPENLZT
        </a>
        <nav>
          <a href="#stand">{t.nav.stand}</a>
          <a href="#projects">{t.nav.projects}</a>
          <a href="#install">{t.nav.install}</a>
          {/* Второй путь на хостинг, а не дубль первого: шапка прячется целиком на ≤760px,
              а подвал виден на любой ширине, поэтому с телефона на платную страницу до сих
              пор не вела ни одна ссылка. */}
          <a href={locale === 'ru' ? '/hosting' : '/en/hosting'}>{t.nav.hosting}</a>
          <a href="https://github.com/open-lzt" target="_blank" rel="noopener noreferrer">
            {t.nav.github}
          </a>
          <a href={locale === 'ru' ? '/en' : '/'}>{locale === 'ru' ? 'English' : 'Русский'}</a>
        </nav>
        <span>{t.footer.note}</span>
      </div>
    </footer>
  );
}
