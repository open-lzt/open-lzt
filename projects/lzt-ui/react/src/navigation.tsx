import {
  Fragment,
  cloneElement,
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
  type ComponentPropsWithoutRef,
  type MouseEvent as ReactMouseEvent,
  type MouseEventHandler,
  type ReactElement,
  type ReactNode,
} from 'react';
import { cx } from './cx';

export type TopbarProps = ComponentPropsWithoutRef<'header'>;

export function Topbar({ className, children, ...props }: TopbarProps) {
  return (
    <header className={cx('lzt-topbar', className)} {...props}>
      <div className="lzt-topbar__inner">{children}</div>
    </header>
  );
}

export interface LogoProps extends ComponentPropsWithoutRef<'div'> {
  mark?: ReactNode;
}

export function Logo({ mark, className, children, ...props }: LogoProps) {
  return (
    <div className={cx('lzt-logo', className)} {...props}>
      {mark && <span className="lzt-logo__mark">{mark}</span>}
      {children}
    </div>
  );
}

export interface SidenavProps extends ComponentPropsWithoutRef<'nav'> {
  label?: ReactNode;
}

export function Sidenav({ label, className, children, ...props }: SidenavProps) {
  return (
    <nav className={cx('lzt-sidenav', className)} {...props}>
      {label && <div className="lzt-sidenav__label">{label}</div>}
      {children}
    </nav>
  );
}

export interface SidenavItemProps extends ComponentPropsWithoutRef<'a'> {
  active?: boolean;
  count?: ReactNode;
}

export function SidenavItem({ active, count, className, children, ...props }: SidenavItemProps) {
  return (
    <a className={cx('lzt-sidenav__item', active && 'is-active', className)} {...props}>
      {children}
      {count != null && <span className="lzt-sidenav__count">{count}</span>}
    </a>
  );
}

export interface TabItem {
  value: string;
  label: ReactNode;
  disabled?: boolean;
}

export interface TabsProps extends Omit<ComponentPropsWithoutRef<'div'>, 'onChange'> {
  items: TabItem[];
  value?: string;
  defaultValue?: string;
  onChange?: (value: string) => void;
}

export function Tabs({ items, value, defaultValue, onChange, className, ...props }: TabsProps) {
  const [internal, setInternal] = useState(defaultValue ?? items[0]?.value);
  const active = value ?? internal;

  const select = (next: string) => {
    if (value === undefined) setInternal(next);
    onChange?.(next);
  };

  return (
    <div role="tablist" className={cx('lzt-tabs', className)} {...props}>
      {items.map((item) => (
        <button
          key={item.value}
          type="button"
          role="tab"
          className="lzt-tab"
          aria-selected={item.value === active}
          disabled={item.disabled}
          onClick={() => select(item.value)}
        >
          {item.label}
        </button>
      ))}
    </div>
  );
}

export interface SegmentedItem {
  value: string;
  label: ReactNode;
  disabled?: boolean;
}

export interface SegmentedProps extends Omit<ComponentPropsWithoutRef<'div'>, 'onChange'> {
  items: SegmentedItem[];
  value?: string;
  defaultValue?: string;
  onChange?: (value: string) => void;
}

export function Segmented({ items, value, defaultValue, onChange, className, ...props }: SegmentedProps) {
  const [internal, setInternal] = useState(defaultValue ?? items[0]?.value);
  const active = value ?? internal;

  const select = (next: string) => {
    if (value === undefined) setInternal(next);
    onChange?.(next);
  };

  return (
    <div className={cx('lzt-segmented', className)} {...props}>
      {items.map((item) => (
        <button
          key={item.value}
          type="button"
          className="lzt-segmented__item"
          aria-selected={item.value === active}
          disabled={item.disabled}
          onClick={() => select(item.value)}
        >
          {item.label}
        </button>
      ))}
    </div>
  );
}

export interface BreadcrumbItem {
  label: ReactNode;
  href?: string;
}

export interface BreadcrumbProps extends ComponentPropsWithoutRef<'nav'> {
  items: BreadcrumbItem[];
}

export function Breadcrumb({ items, className, ...props }: BreadcrumbProps) {
  return (
    <nav aria-label="Breadcrumb" className={cx('lzt-breadcrumb', className)} {...props}>
      {items.map((item, i) => (
        <Fragment key={i}>
          {i > 0 && <span className="lzt-breadcrumb__sep">/</span>}
          {item.href ? <a href={item.href}>{item.label}</a> : <span>{item.label}</span>}
        </Fragment>
      ))}
    </nav>
  );
}

export interface PagenavProps extends Omit<ComponentPropsWithoutRef<'nav'>, 'onChange'> {
  page: number;
  count: number;
  onChange: (page: number) => void;
  siblingCount?: number;
}

function buildPageList(page: number, count: number, siblings: number): Array<number | 'gap'> {
  const windowSize = siblings * 2 + 5;
  if (count <= windowSize) return Array.from({ length: count }, (_, i) => i + 1);

  const left = Math.max(page - siblings, 2);
  const right = Math.min(page + siblings, count - 1);
  const pages: Array<number | 'gap'> = [1];
  if (left > 2) pages.push('gap');
  for (let p = left; p <= right; p += 1) pages.push(p);
  if (right < count - 1) pages.push('gap');
  pages.push(count);
  return pages;
}

export function Pagenav({ page, count, onChange, siblingCount = 1, className, ...props }: PagenavProps) {
  const pages = buildPageList(page, count, siblingCount);
  return (
    <nav aria-label="Pagination" className={cx('lzt-pagenav', className)} {...props}>
      {pages.map((p, i) =>
        p === 'gap' ? (
          <span key={`gap-${i}`} className="lzt-pagenav__gap">
            …
          </span>
        ) : (
          <button
            key={p}
            type="button"
            className={cx('lzt-pagenav__item', p === page && 'is-current')}
            aria-current={p === page ? 'page' : undefined}
            onClick={() => onChange(p)}
          >
            {p}
          </button>
        ),
      )}
    </nav>
  );
}

interface DropdownContextValue {
  close: () => void;
}

const DropdownContext = createContext<DropdownContextValue | null>(null);

export interface DropdownProps extends Omit<ComponentPropsWithoutRef<'div'>, 'onClick'> {
  trigger: ReactElement<{ onClick?: MouseEventHandler }>;
  open?: boolean;
  defaultOpen?: boolean;
  onOpenChange?: (open: boolean) => void;
}

export function Dropdown({ trigger, open, defaultOpen = false, onOpenChange, className, children, ...props }: DropdownProps) {
  const [internalOpen, setInternalOpen] = useState(defaultOpen);
  const isOpen = open ?? internalOpen;
  const rootRef = useRef<HTMLDivElement>(null);

  const setOpen = useCallback(
    (next: boolean) => {
      if (open === undefined) setInternalOpen(next);
      onOpenChange?.(next);
    },
    [open, onOpenChange],
  );

  useEffect(() => {
    if (!isOpen) return;
    const onPointerDown = (e: PointerEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) setOpen(false);
    };
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false);
    };
    document.addEventListener('pointerdown', onPointerDown);
    document.addEventListener('keydown', onKeyDown);
    return () => {
      document.removeEventListener('pointerdown', onPointerDown);
      document.removeEventListener('keydown', onKeyDown);
    };
  }, [isOpen, setOpen]);

  return (
    <div ref={rootRef} className={cx('lzt-dropdown', isOpen && 'is-open', className)} {...props}>
      {cloneElement(trigger, {
        onClick: (e: ReactMouseEvent) => {
          trigger.props.onClick?.(e);
          setOpen(!isOpen);
        },
      })}
      <DropdownContext.Provider value={{ close: () => setOpen(false) }}>{children}</DropdownContext.Provider>
    </div>
  );
}

export type MenuProps = ComponentPropsWithoutRef<'div'>;

export function Menu({ className, ...props }: MenuProps) {
  return <div role="menu" className={cx('lzt-menu', className)} {...props} />;
}

export interface MenuItemProps extends ComponentPropsWithoutRef<'button'> {
  danger?: boolean;
  /** Close the parent Dropdown after this item is clicked. Default true. */
  closeOnClick?: boolean;
}

export function MenuItem({ danger, closeOnClick = true, className, onClick, type = 'button', ...props }: MenuItemProps) {
  const ctx = useContext(DropdownContext);
  return (
    <button
      type={type}
      role="menuitem"
      className={cx('lzt-menu__item', danger && 'lzt-menu__item--danger', className)}
      onClick={(e) => {
        onClick?.(e);
        if (closeOnClick) ctx?.close();
      }}
      {...props}
    />
  );
}

export type MenuSepProps = ComponentPropsWithoutRef<'div'>;

export function MenuSep({ className, ...props }: MenuSepProps) {
  return <div className={cx('lzt-menu__sep', className)} {...props} />;
}
