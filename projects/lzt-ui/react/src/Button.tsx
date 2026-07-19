import { forwardRef, type ComponentPropsWithoutRef } from 'react';
import { cx } from './cx';

export type ButtonVariant = 'default' | 'primary' | 'danger' | 'outline' | 'ghost' | 'gradient';
export type ButtonSize = 'sm' | 'md' | 'lg';

export interface ButtonProps extends ComponentPropsWithoutRef<'button'> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  /** Square icon-only button (`lzt-btn--icon`). */
  icon?: boolean;
  block?: boolean;
  loading?: boolean;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = 'default', size = 'md', icon, block, loading, disabled, className, type = 'button', children, ...props },
  ref,
) {
  return (
    <button
      ref={ref}
      type={type}
      className={cx(
        'lzt-btn',
        variant !== 'default' && `lzt-btn--${variant}`,
        size === 'sm' && 'lzt-btn--sm',
        size === 'lg' && 'lzt-btn--lg',
        icon && 'lzt-btn--icon',
        block && 'lzt-btn--block',
        loading && 'is-loading',
        className,
      )}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      {...props}
    >
      {children}
    </button>
  );
});

export type ButtonGroupProps = ComponentPropsWithoutRef<'div'>;

export function ButtonGroup({ className, ...props }: ButtonGroupProps) {
  return <div className={cx('lzt-btn-group', className)} {...props} />;
}
