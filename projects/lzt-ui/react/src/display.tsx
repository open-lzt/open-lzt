import type { ComponentPropsWithoutRef, ReactNode } from 'react';
import { cx } from './cx';
import { Icon } from './Icon';

export interface BlockProps extends ComponentPropsWithoutRef<'div'> {
  accent?: boolean;
}

export function Block({ accent, className, ...props }: BlockProps) {
  return <div className={cx('lzt-block', accent && 'lzt-block--accent', className)} {...props} />;
}

export type BlockHeaderProps = ComponentPropsWithoutRef<'div'>;

export function BlockHeader({ className, ...props }: BlockHeaderProps) {
  return <div className={cx('lzt-block__header', className)} {...props} />;
}

export type BlockBodyProps = ComponentPropsWithoutRef<'div'>;

export function BlockBody({ className, ...props }: BlockBodyProps) {
  return <div className={cx('lzt-block__body', className)} {...props} />;
}

export type BlockFooterProps = ComponentPropsWithoutRef<'div'>;

export function BlockFooter({ className, ...props }: BlockFooterProps) {
  return <div className={cx('lzt-block__footer', className)} {...props} />;
}

export interface CardProps extends ComponentPropsWithoutRef<'div'> {
  hover?: boolean;
}

export function Card({ hover, className, ...props }: CardProps) {
  return <div className={cx('lzt-card', hover && 'lzt-card--hover', className)} {...props} />;
}

export interface StatProps extends ComponentPropsWithoutRef<'div'> {
  label: ReactNode;
  value: ReactNode;
  delta?: ReactNode;
  trend?: 'up' | 'down';
}

export function Stat({ label, value, delta, trend, className, ...props }: StatProps) {
  return (
    <div className={cx('lzt-stat', className)} {...props}>
      <span className="lzt-stat__label">{label}</span>
      <span className="lzt-stat__value">{value}</span>
      {delta != null && (
        <span
          className={cx(
            'lzt-stat__delta',
            trend === 'up' && 'lzt-stat__delta--up',
            trend === 'down' && 'lzt-stat__delta--down',
          )}
        >
          {delta}
        </span>
      )}
    </div>
  );
}

export type BadgeTone = 'default' | 'brand' | 'danger' | 'warning' | 'info' | 'premium';

export interface BadgeProps extends ComponentPropsWithoutRef<'span'> {
  tone?: BadgeTone;
  pill?: boolean;
}

export function Badge({ tone = 'default', pill, className, ...props }: BadgeProps) {
  return (
    <span
      className={cx('lzt-badge', tone !== 'default' && `lzt-badge--${tone}`, pill && 'lzt-badge--pill', className)}
      {...props}
    />
  );
}

export interface TagProps extends ComponentPropsWithoutRef<'button'> {
  active?: boolean;
}

export function Tag({ active, className, type = 'button', ...props }: TagProps) {
  return <button type={type} className={cx('lzt-tag', active && 'is-active', className)} {...props} />;
}

export interface ChipProps extends ComponentPropsWithoutRef<'span'> {
  onRemove?: () => void;
}

export function Chip({ onRemove, className, children, ...props }: ChipProps) {
  return (
    <span className={cx('lzt-chip', className)} {...props}>
      {children}
      {onRemove && (
        <span
          className="lzt-chip__x"
          role="button"
          tabIndex={0}
          aria-label="Remove"
          onClick={onRemove}
          onKeyDown={(e) => {
            if (e.key === 'Enter' || e.key === ' ') onRemove();
          }}
        >
          <Icon name="x" size={12} />
        </span>
      )}
    </span>
  );
}

export type AvatarSize = 'sm' | 'md' | 'lg';
export type AvatarStatus = 'online' | 'busy';

export interface AvatarProps extends ComponentPropsWithoutRef<'div'> {
  src?: string;
  alt?: string;
  size?: AvatarSize;
  round?: boolean;
  ring?: boolean;
  status?: AvatarStatus;
}

export function Avatar({ src, alt = '', size = 'md', round, ring, status, className, children, ...props }: AvatarProps) {
  return (
    <div
      className={cx(
        'lzt-avatar',
        size === 'sm' && 'lzt-avatar--sm',
        size === 'lg' && 'lzt-avatar--lg',
        round && 'lzt-avatar--round',
        ring && 'lzt-avatar--ring',
        className,
      )}
      {...props}
    >
      {src ? <img src={src} alt={alt} /> : children}
      {status && <span className={cx('lzt-avatar__dot', `lzt-avatar__dot--${status}`)} />}
    </div>
  );
}

export type AlertTone = 'default' | 'success' | 'danger' | 'warning' | 'info';

export interface AlertProps extends Omit<ComponentPropsWithoutRef<'div'>, 'title'> {
  tone?: AlertTone;
  title?: ReactNode;
}

export function Alert({ tone = 'default', title, className, children, ...props }: AlertProps) {
  return (
    <div role="alert" className={cx('lzt-alert', tone !== 'default' && `lzt-alert--${tone}`, className)} {...props}>
      <div>
        {title && <span className="lzt-alert__title">{title}</span>}
        {children}
      </div>
    </div>
  );
}

export interface EmptyProps extends Omit<ComponentPropsWithoutRef<'div'>, 'title'> {
  icon?: ReactNode;
  title?: ReactNode;
}

export function Empty({ icon, title, className, children, ...props }: EmptyProps) {
  return (
    <div className={cx('lzt-empty', className)} {...props}>
      {icon && <div className="lzt-empty__icon">{icon}</div>}
      {title && <div className="lzt-empty__title">{title}</div>}
      {children}
    </div>
  );
}

export interface TableProps extends ComponentPropsWithoutRef<'table'> {
  /** Right-aligns + tabular-nums the last column (`lzt-table--num`). */
  numeric?: boolean;
}

export function Table({ numeric, className, children, ...props }: TableProps) {
  return (
    <div className="lzt-table-wrap">
      <table className={cx('lzt-table', numeric && 'lzt-table--num', className)} {...props}>
        {children}
      </table>
    </div>
  );
}
