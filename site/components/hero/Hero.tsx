'use client';

import { useEffect } from 'react';

import type { Content } from '@/content/types';
import { CommandBuilder } from '@/components/builder/CommandBuilder';
import { CopyPlate } from '@/components/ui/Copy';
import { Icon } from '@/components/ui/Icon';
import { StandSchema } from './StandSchema';

/**
 * The first screen: atmosphere, the brand wordmark behind the headline, the
 * command builder, and the stand schema underneath. Tool first, explanation
 * second — the builder is what makes this page worth returning to.
 */
export function Hero({ t, locale }: { t: Content; locale: 'ru' | 'en' }) {
  // The cascade is driven by `body.is-loaded` — the class has to land on <body>,
  // not on this element, or every `.rise` child stays at opacity 0 forever and
  // the page never leaves its splash.
  useEffect(() => {
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const id = setTimeout(() => document.body.classList.add('is-loaded'), reduced ? 0 : 700);
    return () => {
      clearTimeout(id);
      document.body.classList.remove('is-loaded');
    };
  }, []);

  const other = locale === 'ru' ? '/en' : '/';

  return (
    <div className="hero">
      <div className="hero-grid" />
      <div className="orb orb-1" />
      <div className="orb orb-2" />
      <div className="orb orb-3" />
      <div className="hero-backdrop">OPENLZT</div>
      <div className="hero-loading">
        <i />
        <i />
        <i />
      </div>

      <div className="wrap">
        <header className="rise rise-1">
          <nav className="nav">
            <a className="brand" href="#top">
              <span className="brand-mark">
                <Icon name="logo" size={15} />
              </span>
              OPENLZT
            </a>
            <div className="nav-links">
              <a href="#stand">{t.nav.stand}</a>
              <a href="#projects">{t.nav.projects}</a>
              <a href="#install">{t.nav.install}</a>
              {/* Страница, на которую не ведёт ни одна ссылка, для читателя не существует —
                  сколько бы её ни собрали. Ведёт из шапки, рядом с установкой: это и есть
                  развилка «поставить самому или взять готовое». */}
              <a href={locale === 'ru' ? '/hosting' : '/en/hosting'}>{t.nav.hosting}</a>
              <a href={other} className="lang">
                {locale === 'ru' ? 'EN' : 'RU'}
              </a>
            </div>
            <a
              className="btn btn-primary"
              href="https://github.com/open-lzt"
              target="_blank"
              rel="noopener noreferrer"
            >
              <span className="lbl">
                <Icon name="gh" size={16} /> {t.nav.github}
              </span>
            </a>
          </nav>
        </header>

        <div className="hero-body">
          <h1 className="h1 rise rise-2">
            {t.hero.titleTop}
            <br />
            <span className="g">{t.hero.titleAccent}</span>
          </h1>
          <p className="sub rise rise-3">{t.hero.sub}</p>

          {/* Above the CTAs on purpose: the fastest way to judge this project is to run it,
              and a visitor who has to reach the install section to discover that has already
              decided something else. */}
          <div className="hero-demo rise rise-3">
            <CopyPlate
              className="pip demo"
              prefix="$"
              text={t.hero.demo.label}
              copyText={t.hero.demo.copy}
              copiedLabel={t.builder.copied}
            />
            <p className="hero-demo-cap">{t.hero.demo.caption}</p>
          </div>

          <div className="hero-ctas rise rise-4">
            <a
              className="btn btn-primary"
              href="https://github.com/open-lzt"
              target="_blank"
              rel="noopener noreferrer"
            >
              <span className="lbl">
                <Icon name="gh" size={17} /> {t.hero.ctaGithub}
              </span>
            </a>
            <CopyPlate
              className="pip"
              prefix="$"
              text={t.hero.pip}
              copyText={t.hero.pip}
              copiedLabel={t.builder.copied}
            />
          </div>

          <div className="rise rise-5">
            <CommandBuilder t={t.builder} />
          </div>

          <div className="rise rise-5">
            <StandSchema t={t.stand} />
          </div>

          <div className="repo-band rise rise-5" aria-hidden="true">
            <div className="repo-track">
              {[...REPOS, ...REPOS].map((name, i) => (
                <span key={`${name}-${i}`}>{name}</span>
              ))}
            </div>
          </div>

          <div className="facts rise rise-5">
            {t.facts.map((fact) => (
              <span className="fact" key={fact.label}>
                <b className={fact.accent ? 'g' : undefined}>{fact.value}</b>
                <span>{fact.label}</span>
              </span>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

const REPOS = [
  'pylzt',
  'lzt-testnet',
  'lzt-eventus',
  'lzt-eventus-sdk',
  'auto-lzt',
  'lzt-mcp',
  'lzt-flows',
  'lzt-plugins',
  'lzt-ui',
  'open-lzt',
];
