import { useEffect, useRef, type ComponentPropsWithoutRef, type ReactNode } from 'react';
import { cx } from './cx';

export interface ModalProps extends Omit<ComponentPropsWithoutRef<'div'>, 'title'> {
  open: boolean;
  onClose: () => void;
  title?: ReactNode;
  footer?: ReactNode;
}

const FOCUSABLE_SELECTOR =
  'a[href], button:not([disabled]), textarea, input, select, [tabindex]:not([tabindex="-1"])';

export function Modal({ open, onClose, title, footer, className, children, ...props }: ModalProps) {
  const modalRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const previouslyFocused = document.activeElement as HTMLElement | null;
    modalRef.current?.focus();

    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
        return;
      }
      if (e.key !== 'Tab' || !modalRef.current) return;
      const focusable = modalRef.current.querySelectorAll<HTMLElement>(FOCUSABLE_SELECTOR);
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault();
        first.focus();
      }
    };

    document.addEventListener('keydown', onKeyDown);
    return () => {
      document.removeEventListener('keydown', onKeyDown);
      previouslyFocused?.focus();
    };
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div className="lzt-overlay is-open" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div
        ref={modalRef}
        role="dialog"
        aria-modal="true"
        aria-label={typeof title === 'string' ? title : undefined}
        tabIndex={-1}
        className={cx('lzt-modal', className)}
        {...props}
      >
        {title && <div className="lzt-modal__head">{title}</div>}
        <div className="lzt-modal__body">{children}</div>
        {footer && <div className="lzt-modal__foot">{footer}</div>}
      </div>
    </div>
  );
}

export interface TooltipProps extends ComponentPropsWithoutRef<'span'> {
  content: string;
}

export function Tooltip({ content, className, children, ...props }: TooltipProps) {
  return (
    <span className={cx('lzt-tip', className)} data-tip={content} {...props}>
      {children}
    </span>
  );
}

export interface ProgressProps extends ComponentPropsWithoutRef<'div'> {
  /** 0–100 */
  value: number;
  flow?: boolean;
}

export function Progress({ value, flow, className, ...props }: ProgressProps) {
  const clamped = Math.min(100, Math.max(0, value));
  return (
    <div
      role="progressbar"
      aria-valuenow={clamped}
      aria-valuemin={0}
      aria-valuemax={100}
      className={cx('lzt-progress', flow && 'lzt-progress--flow', className)}
      {...props}
    >
      <div className="lzt-progress__bar" style={{ width: `${clamped}%` }} />
    </div>
  );
}

export type LoaderBarProps = ComponentPropsWithoutRef<'div'>;

export function LoaderBar({ className, ...props }: LoaderBarProps) {
  return <div role="progressbar" className={cx('lzt-loaderbar', className)} {...props} />;
}

export interface SpinnerProps extends ComponentPropsWithoutRef<'div'> {
  size?: 'md' | 'lg';
}

export function Spinner({ size = 'md', className, ...props }: SpinnerProps) {
  return (
    <div
      role="status"
      aria-label="Loading"
      className={cx('lzt-spinner', size === 'lg' && 'lzt-spinner--lg', className)}
      {...props}
    />
  );
}

export type DotsProps = ComponentPropsWithoutRef<'span'>;

export function Dots({ className, ...props }: DotsProps) {
  return (
    <span role="status" aria-label="Loading" className={cx('lzt-dots', className)} {...props}>
      <span />
      <span />
      <span />
    </span>
  );
}

export type SkeletonVariant = 'text' | 'title' | 'avatar';

export interface SkeletonProps extends ComponentPropsWithoutRef<'div'> {
  variant?: SkeletonVariant;
}

export function Skeleton({ variant, className, ...props }: SkeletonProps) {
  return <div className={cx('lzt-skeleton', variant && `lzt-skeleton--${variant}`, className)} {...props} />;
}
