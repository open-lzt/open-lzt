'use client';

import { Fragment, useEffect, useState } from 'react';

import { runCommand } from '@/lib/site';

import type { SceneId } from '@/content/types';
import { Icon } from '@/components/ui/Icon';
import { highlight } from './highlight';
import { Scene } from './Scene';

/**
 * One animated scene per project. Each one owns only its content — the frame,
 * the terminal bar and the visibility signal come from `Scene`.
 *
 * No number ever animates: figures are data, not a show.
 */
export function ProjectScene({ id }: { id: SceneId }) {
  const S = SCENES[id];
  return <S />;
}

/* ── pylzt: code types itself, then starts over ─────────────────────────── */

const PYLZT_CODE = `from pylzt import Client, ClientConfig
from pylzt.types import Category

async with Client.from_token(
    "<market-token>",
    config=ClientConfig.for_testnet(),
) as client:
    lot = await client.market.get_lot(item_id=42)

    async for lot in client.market.list_lots(
        category=Category.STEAM
    ):
        print(lot.price)  # Decimal, not float`;

function PylztScene() {
  return (
    <Scene title="python — pylzt">
      {(inView) => <Typewriter text={PYLZT_CODE} active={inView} />}
    </Scene>
  );
}

function Typewriter({ text, active }: { text: string; active: boolean }) {
  const [shown, setShown] = useState(0);

  useEffect(() => {
    if (!active) return;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      setShown(text.length);
      return;
    }
    let n = 0;
    const step = setInterval(() => {
      n = n + 2;
      if (n >= text.length) {
        setShown(text.length);
        clearInterval(step);
        // Loop: the block is a scene, and a scene that plays once reads dead
        // to anyone who scrolled past it and came back.
        setTimeout(() => setShown(0), 7000);
      } else setShown(n);
    }, 18);
    return () => clearInterval(step);
  }, [active, shown === 0, text]);

  return (
    <div className="term-body">
      {highlight(text.slice(0, shown))}
      {shown < text.length ? <span className="caret" /> : null}
    </div>
  );
}

/* ── testnet: the switch re-themes the whole scene ──────────────────────── */

function TestnetScene() {
  const [prod, setProd] = useState(false);
  // 8765 — порт тестнета (`deploy/systemd/open-lzt-testnet.service`), а не 8000: на 8000 живёт
  // API движка. Число уехало неверным при переезде сайта в монорепо, и на публичной странице
  // это выглядело как рабочий адрес, по которому ничего нет.
  const host = prod ? 'api.lzt.market' : '127.0.0.1:8765';

  return (
    <div className={`scene tn-scene${prod ? ' prod' : ''}`}>
      <div className="tn-head">
        <span className="tn-mode">{prod ? 'prod · реальные деньги' : 'testnet · безопасно'}</span>
        <button
          type="button"
          role="switch"
          aria-checked={prod}
          aria-label="testnet / prod"
          className={`toggle${prod ? ' on' : ''}`}
          onClick={() => setProd((v) => !v)}
        />
      </div>
      <div className="tn-rows">
        {[
          ['GET ', '/market/me'],
          ['POST', '/market/bump'],
          ['GET ', '/market/payments'],
        ].map(([verb, path]) => (
          <div key={path}>
            <span className="m">{verb}</span> <span className="host">{host}</span>
            {path} <span className="ok">200</span>
          </div>
        ))}
      </div>
      <div className="tn-warn">
        {prod ? 'Внимание: запросы бьют в реальный маркет.' : 'Деньги не тратятся: все запросы идут в мок.'}
      </div>
    </div>
  );
}

/* ── eventus: live log ──────────────────────────────────────────────────── */

const FEED = [
  ['12:04:01', 'order.paid', '#8412 · аккаунт продан за 1,250.00 ₽'],
  ['12:04:07', 'item.bumped', 'лот #5531 поднят'],
  ['12:04:16', 'message.new', 'покупатель: «Данные пришли, спасибо»'],
  ['12:04:22', 'item.viewed', 'лот #5531 · 12 просмотров/мин'],
  ['12:04:30', 'payment.out', 'вывод 3,000.00 ₽ подтверждён'],
  ['12:04:41', 'order.paid', '#8413 · ключ продан за 199.00 ₽'],
];

function EventusScene() {
  const [head, setHead] = useState(0);

  return (
    <Scene title="eventus — live" >
      {(inView) => {
        return (
          <>
            <Ticker active={inView} onTick={() => setHead((h) => h + 1)} />
            <div className="ev-log">
              {Array.from({ length: 5 }, (_, i) => FEED[(head + i) % FEED.length]).map((row, i) => (
                <div className="ev-row" key={`${head}-${i}`}>
                  <span className="t">{row[0]}</span>
                  <span className="ev">{row[1]}</span>
                  <span className="pl">{row[2]}</span>
                </div>
              ))}
            </div>
            <div className="ev-badges">
              <b>REST</b>
              <b>WEBHOOK</b>
              <b>SSE</b>
              <b>WS</b>
            </div>
          </>
        );
      }}
    </Scene>
  );
}

/** Shared "do something every N ms while visible" helper. */
function Ticker({ active, onTick, every = 2600 }: { active: boolean; onTick: () => void; every?: number }) {
  useEffect(() => {
    if (!active) return;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    const id = setInterval(onTick, every);
    return () => clearInterval(id);
  }, [active, every, onTick]);
  return null;
}

/* ── auto-lzt: the flow graph lights up node by node ────────────────────── */

const FLOW_NODES = [
  { icon: 'clock', label: 'каждый день', style: { left: '4%', top: 56 } },
  { icon: 'up', label: 'поднять лоты', style: { left: '38%', top: 112 } },
  { icon: 'check', label: 'проверить статус', style: { left: '55%', top: 192 } },
  { icon: 'bell', label: 'уведомить', style: { left: '10%', top: 230 } },
] as const;

function FlowScene() {
  const [hot, setHot] = useState(0);

  return (
    <Scene title="auto-lzt — flow">
      {(inView) => (
        <div className="flow">
          <Ticker active={inView} every={1400} onTick={() => setHot((h) => h + 1)} />
          <svg className="wires" viewBox="0 0 520 300" preserveAspectRatio="none" aria-hidden="true">
            <path d="M120 78 C190 78 200 120 240 128" />
            <path d="M330 140 C400 150 400 190 380 208" />
            <path d="M270 152 C220 190 190 200 160 214" />
          </svg>
          {FLOW_NODES.map((node, i) => (
            <span key={node.label} className={`fnode${hot % FLOW_NODES.length === i ? ' hot' : ''}`} style={node.style}>
              <Icon name={node.icon} size={16} />
              {node.label}
            </span>
          ))}
          <span className="flow-note">
            flow: <b>bump-daily</b> · исполняется по расписанию
          </span>
        </div>
      )}
    </Scene>
  );
}

/* ── eventus-sdk: subscription code + the verified flash ────────────────── */

const SDK_CODE = `from lzt_eventus_sdk import ManagementClient
from lzt_eventus_sdk.types import SubscriptionTransport

async with ManagementClient("http://127.0.0.1:8080") as mc:
    await mc.create_subscription(
        transport=SubscriptionTransport.WEBHOOK,
        url="https://my.app/hook",
    )`;

function SdkScene() {
  const [on, setOn] = useState(false);
  return (
    <Scene title="python — eventus-sdk">
      {(inView) => (
        <>
          <div className="term-body" style={{ minHeight: 180 }}>
            {highlight(SDK_CODE)}
          </div>
          <Ticker active={inView} every={2400} onTick={() => setOn((v) => !v)} />
          <div className={`ver-flash${on ? ' on' : ''}`}>
            <Icon name="check" size={17} /> webhook signature — verified
          </div>
        </>
      )}
    </Scene>
  );
}

/* ── mcp: the agent chat streams word by word ───────────────────────────── */

const CHAT = [
  { role: 'user', text: 'Подними мои лоты и покажи баланс.' },
  { role: 'tool', text: '→ tool: auto_lzt.run_flow("bump") · testnet' },
  { role: 'bot', text: 'Готово: 14 лотов подняты. Баланс — 2,410.00 ₽ (testnet).' },
] as const;

function McpScene() {
  const [run, setRun] = useState(0);
  return (
    <Scene title="agent — lzt-dev-mcp">
      {(inView) => (
        <>
          <button type="button" className="chat-replay" onClick={() => setRun((r) => r + 1)}>
            повторить
          </button>
          <div className="chat">
            {CHAT.map((msg, i) => (
              <StreamedMessage key={`${run}-${i}`} role={msg.role} text={msg.text} active={inView} order={i} />
            ))}
          </div>
        </>
      )}
    </Scene>
  );
}

function StreamedMessage({
  role,
  text,
  active,
  order,
}: {
  role: string;
  text: string;
  active: boolean;
  order: number;
}) {
  const words = text.split(' ');
  const [shown, setShown] = useState(0);

  useEffect(() => {
    if (!active) return;
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      setShown(words.length);
      return;
    }
    setShown(0);
    const start = setTimeout(() => {
      const id = setInterval(() => {
        setShown((n) => {
          if (n >= words.length) {
            clearInterval(id);
            return n;
          }
          return n + 1;
        });
      }, 70);
    }, 300 + order * 700);
    return () => clearTimeout(start);
  }, [active, order, words.length]);

  return (
    <div className={`msg ${role}`}>
      {words.map((word, i) => (
        // Разделитель стоит СНАРУЖИ span: `.w` — inline-block, а inline-block съедает
        // хвостовой пробел внутри себя, и слова слипались. Правка существовала и потерялась
        // при переезде сайта в монорепо; вернулась 17.08 вместе с этим комментарием.
        <Fragment key={i}>
          <span className={`w${i < shown ? ' in' : ''}`}>{word}</span>
          {i < words.length - 1 ? ' ' : ''}
        </Fragment>
      ))}
    </div>
  );
}

/* ── flows + plugins: the catalogue ─────────────────────────────────────── */

const CATALOG = [
  { icon: 'box', name: 'steam-autobuy', note: 'Автовыкуп аккаунтов Steam' },
  { icon: 'bolt', name: 'riot-autobuy', note: 'Valorant и League of Legends' },
  { icon: 'check', name: 'sniper-autobuy', note: 'Снайпер по любой из 21 категории' },
  { icon: 'up', name: 'bump-daily', note: 'Ежедневный подъём своих лотов' },
] as const;

function CatalogScene() {
  return (
    <Scene title="каталог модулей">
      <div className="cat">
        {CATALOG.map((item) => (
          <div className="cat-card" key={item.name}>
            <b>
              <Icon name={item.icon} size={15} /> {item.name}
            </b>
            <span>{item.note}</span>
          </div>
        ))}
      </div>
    </Scene>
  );
}

/* ── lzt-ui: tokens and a theme switch ──────────────────────────────────── */

const SWATCHES = [
  ['#3ddc55', '500'],
  ['#2cb244', '600'],
  ['#1a8a31', '700'],
  ['#1a1a1e', 's-3'],
  ['#151518', 's-2'],
  ['#111113', 's-1'],
] as const;

function UiKitScene() {
  const [lite, setLite] = useState(false);
  return (
    <Scene title="lzt-ui — tokens">
      <div className="uikit">
        <div className="swatches">
          {SWATCHES.map(([color, name]) => (
            <span key={name} className="sw" style={{ background: color }} data-n={name} />
          ))}
        </div>
        <div className={`ui-demo${lite ? ' lite' : ''}`}>
          <span className="d-btn">Кнопка</span>
          <span className="d-chip">чип</span>
          <span className="d-chip">статус</span>
          <button
            type="button"
            role="switch"
            aria-checked={lite}
            aria-label="тема"
            className={`toggle d-sw${lite ? ' on' : ''}`}
            onClick={() => setLite((v) => !v)}
          />
        </div>
      </div>
    </Scene>
  );
}

/* ── monorepo: submodules light up in sequence ──────────────────────────── */

const SUBMODULES = [
  'projects/pylzt',
  'projects/testnet',
  'projects/eventus',
  'projects/eventus-sdk',
  'projects/flow',
  'projects/mcp',
  'projects/lzt-ui',
  'lzt-flows',
];

function MonoScene() {
  const [lit, setLit] = useState(0);
  return (
    <Scene title="shell" className="mono-scene">
      {(inView) => (
        <>
          <div className="term-body">
            {/* Команда берётся у того же генератора, что и весь остальной сайт: подпись обещает
                «одной командой», а импорт принёс сюда голый `git clone` — то есть сцена учила
                не тому, чему учит соседний блок установки. */}
            {highlight(
              `# весь стенд одной командой\n$ ${runCommand('all')}\n# скрипт сам клонирует репозиторий в /opt/open-lzt`
            )}
          </div>
          <Ticker active={inView} every={220} onTick={() => setLit((n) => Math.min(n + 1, SUBMODULES.length))} />
          <div className="submods">
            {SUBMODULES.map((name, i) => (
              <b key={name} className={i < lit ? 'on' : ''}>
                {name}
              </b>
            ))}
          </div>
        </>
      )}
    </Scene>
  );
}

const SCENES: Record<SceneId, () => React.JSX.Element> = {
  pylzt: PylztScene,
  testnet: TestnetScene,
  eventus: EventusScene,
  flow: FlowScene,
  sdk: SdkScene,
  mcp: McpScene,
  catalog: CatalogScene,
  uikit: UiKitScene,
  mono: MonoScene,
};
