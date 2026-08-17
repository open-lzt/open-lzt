'use client';

import { useEffect, useState } from 'react';

import type { Content } from '@/content/types';
import { HOSTED_BOT_URL, PRICING_URL } from '@/lib/site';

type Pricing = { stars: number; days: number; usd: string | null; rub: string | null };
type Currency = 'stars' | 'usd' | 'rub';

/**
 * Цена, которую называет сам сервис.
 *
 * **Ловушка названа до объяснения: без ответа здесь НЕ появляется ноль, прочерк или «уточняйте».**
 * Цена, которую страница не смогла узнать, не показывается вовсе — остаётся кнопка в бота, где
 * человеку назовут точную сумму до того, как он что-то нажмёт. Число на публичной странице — это
 * обещание, и обещание, собранное из неизвестности, дороже отсутствующего.
 *
 * Валюты приезжают из того же ответа. Курса здесь нет и быть не должно: платят звёздами, а любая
 * посчитанная нами сумма рядом с ними разъедется с реальностью при первом движении курса.
 */
export function Price({ t }: { t: Content['hosting']['paid'] }) {
  const [state, setState] = useState<'loading' | 'ok' | 'off'>('loading');
  const [data, setData] = useState<Pricing | null>(null);
  const [cur, setCur] = useState<Currency>('stars');

  useEffect(() => {
    // Отмена обязательна: без неё ответ, пришедший после ухода со страницы, зовёт `setState`
    // у снятого компонента — в разработке это предупреждение, в бою утечка обработчика.
    const stop = new AbortController();
    const timer = setTimeout(() => stop.abort(), 4000);

    fetch(PRICING_URL, { signal: stop.signal, headers: { accept: 'application/json' } })
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(String(r.status)))))
      .then((body: Pricing) => {
        setData(body);
        setState('ok');
      })
      // Причина отказа сюда НЕ попадает намеренно: показывать её человеку нечего, а разных
      // действий у него от этого не появляется. Сеть, пятисотка, таймаут — один исход.
      .catch(() => setState('off'))
      .finally(() => clearTimeout(timer));

    return () => {
      clearTimeout(timer);
      stop.abort();
    };
  }, []);

  const money =
    data && cur === 'usd' ? data.usd : data && cur === 'rub' ? data.rub : null;
  const has = (c: Currency) => c === 'stars' || (c === 'usd' ? !!data?.usd : !!data?.rub);
  const shown: Currency[] = (['stars', 'usd', 'rub'] as const).filter(has);

  return (
    <div className="price">
      {state === 'loading' ? (
        // Скелет ФОРМЫ будущего числа, а не строка «загрузка»: когда цена приедет, ничего не
        // сдвинется. Пустое место на её месте читается как «цены нет».
        <p className="price-row" aria-hidden="true">
          <span className="price-skel" />
        </p>
      ) : null}

      {state === 'ok' && data ? (
        <>
          <p className="price-row">
            <b className="price-num">
              {cur === 'stars' ? data.stars : money}
              <span className="price-cur">{t.currency[cur]}</span>
            </b>
            <span className="price-per">{t.per}</span>
          </p>

          {shown.length > 1 ? (
            <div className="price-switch" role="group" aria-label={t.currencyLabel}>
              {shown.map((c) => (
                <button
                  key={c}
                  type="button"
                  className={`price-cur-btn${cur === c ? ' on' : ''}`}
                  aria-pressed={cur === c}
                  onClick={() => setCur(c)}
                >
                  {t.currency[c]}
                </button>
              ))}
            </div>
          ) : null}
        </>
      ) : null}

      {/* Кнопка стоит здесь ВСЕГДА, а не только в ветке отказа: она и есть следующий шаг, и
          человек, увидевший цену, не должен искать, где платить. */}
      {HOSTED_BOT_URL ? (
        <a className="price-cta" href={HOSTED_BOT_URL}>
          {state === 'off' ? t.ctaNoPrice : t.cta}
        </a>
      ) : null}

      <span className="price-note">{state === 'off' ? t.noteNoPrice : t.priceNote}</span>
    </div>
  );
}
