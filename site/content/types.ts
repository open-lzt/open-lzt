/**
 * The shape both dictionaries satisfy. Declaring it once means a key present in
 * one locale and missing in the other is a typecheck error, not a runtime hole —
 * which is the whole reason this project has no i18n library.
 *
 * Body copy carries `**bold**` markers instead of JSX so the dictionaries stay
 * plain data; `<Rich>` renders them.
 */

/** Which animated scene a project block shows. */
export type SceneId =
  | 'pylzt'
  | 'testnet'
  | 'eventus'
  | 'flow'
  | 'sdk'
  | 'mcp'
  | 'catalog'
  | 'uikit'
  | 'mono';

export interface InstallRow {
  /** Prompt shown at the line start: `$`, `bot`, `html`. */
  ps: string;
  /** What the user sees. */
  label: string;
  /** What lands in the clipboard — the full command, even when the label is shortened. */
  copy: string;
}

export interface InstallChip {
  label: string;
  copy: string;
}

export interface InstallBlock {
  title: string;
  rows: InstallRow[];
  /** Flags and code fragments — never whole commands; those are rows. */
  optsTitle?: string;
  opts?: InstallChip[];
  note?: string;
}

export interface Project {
  /** Anchor id, also used by the stand schema to link here. */
  id: string;
  kicker: string;
  name: string;
  href: string;
  body: string;
  tags: string[];
  install: InstallBlock;
  scene: SceneId;
}

export interface StandNode {
  tag: string;
  /** Project anchor this node scrolls to. */
  goto: string;
  caption: string;
}

export interface Fact {
  value: string;
  label: string;
  accent?: boolean;
}

export interface Content {
  meta: { title: string; description: string };
  nav: { stand: string; projects: string; install: string; github: string; hosting: string };
  hero: {
    titleTop: string;
    titleAccent: string;
    sub: string;
    ctaGithub: string;
    pip: string;
    /** The one command that installs the stand and then walks through it. */
    demo: { caption: string; label: string; copy: string };
  };
  builder: {
    title: string;
    tabStand: string;
    tabFlow: string;
    output: string;
    copy: string;
    copied: string;
    share: string;
    shared: string;
    reset: string;
    prodWarning: string;
    prodConfirm: string;
    fields: Record<string, { label: string; hint?: string }>;
    addParam: string;
    paramKey: string;
    paramValue: string;
  };
  stand: { hint: string; nodes: StandNode[] };
  facts: Fact[];
  projectsHead: { title: string; titleAccent: string; sub: string };
  projects: Project[];
  install: {
    title: string;
    titleAccent: string;
    sub: string;
    /** Что нужно иметь до первой команды. Обязательное поле, а не опция: «на чистом сервере»
     *  без единого слова о том, каком и где его взять, — вопрос на главном пути. */
    req: string;
    tabs: { id: string; label: string; rows: InstallRow[] }[];
  };
  cta: { title: string; titleAccent: string; url: string; text: string; copied: string };
  footer: { note: string };
  hosting: Hosting;
}

/**
 * The hosted-service page. The engine stays free and self-hostable; what is sold is somebody
 * else running it. Saying that plainly is the point of the page — a paid page that hides the
 * free path reads as a trap the moment the reader finds the repository, and he will.
 */
export interface Hosting {
  meta: { title: string; description: string };
  titleTop: string;
  titleAccent: string;
  sub: string;
  /** Free-path block: the honest answer to "why pay if it is open". */
  free: { title: string; body: string; cta: string };
  /** `price` обязателен, а не опционален: страница, единственная задача которой продать,
   *  не имела места, куда положить цену, и человек уходил выяснять её в бота. */
  paid: {
    title: string;
    body: string;
    priceNote: string;
    points: string[];
    /** Единица периода рядом с числом: «в месяц». */
    per: string;
    /** Подписи валют. Ключи те же, что отдаёт `/pricing`. */
    currency: { stars: string; usd: string; rub: string };
    currencyLabel: string;
    cta: string;
    /** Цену узнать не удалось: зовём в бота, где её назовут точно, и НЕ показываем прочерк. */
    ctaNoPrice: string;
    noteNoPrice: string;
  };
  /** What the reader does next, in order. */
  steps: { title: string; items: string[] };
  review: { title: string; body: string; points: string[] };
  cta: { label: string; note: string };
  back: string;
}
