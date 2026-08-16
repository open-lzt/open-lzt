import type { Content } from '@/content/types';
import { Rich } from '@/components/ui/Rich';
import { HOSTED_BOT_URL } from '@/lib/site';

/**
 * The hosted-service page.
 *
 * One rule decides its whole order: **the free path is named first**. A page that sells what
 * lies open next to it and stays quiet about that reads as a trap the second the reader finds
 * the repository — and the repository is linked from every other page of this site.
 *
 * The bot button renders only when its address is set. An invented link on a public page is
 * worse than a missing one: the missing button is visibly absent, the wrong one wastes the
 * reader's trust exactly once.
 */
export function HostingPage({ t, locale }: { t: Content; locale: 'ru' | 'en' }) {
  const h = t.hosting;
  const home = locale === 'ru' ? '/' : '/en';

  return (
    <main className="wrap host">
      <section className="host-head reveal is-in">
        <a className="host-back" href={home}>
          ← {h.back}
        </a>
        <h1>
          {h.titleTop} <span className="g">{h.titleAccent}</span>
        </h1>
        <p className="host-sub">{h.sub}</p>
        {HOSTED_BOT_URL ? (
          <p className="host-act">
            <a className="host-cta" href={HOSTED_BOT_URL}>
              {h.cta.label}
            </a>
            <span className="host-note">{h.cta.note}</span>
          </p>
        ) : null}
      </section>

      <section className="sec host-free reveal is-in">
        <h2>{h.free.title}</h2>
        <p>
          <Rich text={h.free.body} />
        </p>
        <a className="host-alt" href={`${home}#install`}>
          {h.free.cta}
        </a>
      </section>

      <div className="host-cols">
        <section className="sec reveal is-in">
          <h2>{h.paid.title}</h2>
          <p>
            <Rich text={h.paid.body} />
          </p>
          <ul className="host-list">
            {h.paid.points.map((point) => (
              <li key={point}>{point}</li>
            ))}
          </ul>
        </section>

        <section className="sec reveal is-in">
          <h2>{h.review.title}</h2>
          <p>
            <Rich text={h.review.body} />
          </p>
          <ul className="host-list">
            {h.review.points.map((point) => (
              <li key={point}>{point}</li>
            ))}
          </ul>
        </section>

        {/* Третьим столбцом, а не отдельной секцией внизу: собственной строкой шаги оставляли
            под собой пустую правую половину экрана, и страница обрывалась дырой. */}
        <section className="sec host-steps reveal is-in">
          <h2>{h.steps.title}</h2>
          <ol className="host-steps-list">
            {h.steps.items.map((item, i) => (
              <li key={item}>
                <span className="host-step-n">{String(i + 1).padStart(2, '0')}</span>
                {item}
              </li>
            ))}
          </ol>
        </section>
      </div>

      {/* Выход обязателен: экран, из которого некуда нажать, — тупик, даже когда он красивый. */}
      <footer className="host-foot">
        <a href={home}>← {h.back}</a>
        <a href={`${home}#install`}>{h.free.cta}</a>
      </footer>
    </main>
  );
}
