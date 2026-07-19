import { forwardRef, type ComponentPropsWithoutRef, type ReactNode } from 'react';
import { cx } from './cx';
import { Icon } from './Icon';

export type FieldProps = ComponentPropsWithoutRef<'div'>;

export function Field({ className, ...props }: FieldProps) {
  return <div className={cx('lzt-field', className)} {...props} />;
}

export type LabelProps = ComponentPropsWithoutRef<'label'>;

export function Label({ className, ...props }: LabelProps) {
  return <label className={cx('lzt-label', className)} {...props} />;
}

export interface HintProps extends ComponentPropsWithoutRef<'span'> {
  error?: boolean;
}

export function Hint({ error, className, ...props }: HintProps) {
  return <span className={cx('lzt-hint', error && 'lzt-hint--error', className)} {...props} />;
}

export interface InputProps extends Omit<ComponentPropsWithoutRef<'input'>, 'size'> {
  size?: 'sm' | 'md';
  invalid?: boolean;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(function Input(
  { size = 'md', invalid, className, ...props },
  ref,
) {
  return (
    <input
      ref={ref}
      className={cx('lzt-input', size === 'sm' && 'lzt-input--sm', invalid && 'lzt-input--invalid', className)}
      aria-invalid={invalid || undefined}
      {...props}
    />
  );
});

export type TextareaProps = ComponentPropsWithoutRef<'textarea'>;

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(function Textarea(
  { className, ...props },
  ref,
) {
  return <textarea ref={ref} className={cx('lzt-textarea', className)} {...props} />;
});

export type SelectProps = ComponentPropsWithoutRef<'select'>;

export const Select = forwardRef<HTMLSelectElement, SelectProps>(function Select({ className, ...props }, ref) {
  return <select ref={ref} className={cx('lzt-select', className)} {...props} />;
});

export type SearchProps = ComponentPropsWithoutRef<'input'>;

export function Search({ className, ...props }: SearchProps) {
  return (
    <div className="lzt-search">
      <span className="lzt-search__icon">
        <Icon name="search" size={14} />
      </span>
      <input type="search" className={cx('lzt-input', className)} {...props} />
    </div>
  );
}

export interface CheckboxProps extends ComponentPropsWithoutRef<'input'> {
  label?: ReactNode;
}

export function Checkbox({ label, className, ...props }: CheckboxProps) {
  return (
    <label className={cx('lzt-check', className)}>
      <input type="checkbox" {...props} />
      {label}
    </label>
  );
}

export interface RadioProps extends ComponentPropsWithoutRef<'input'> {
  label?: ReactNode;
}

export function Radio({ label, className, ...props }: RadioProps) {
  return (
    <label className={cx('lzt-check', className)}>
      <input type="radio" {...props} />
      {label}
    </label>
  );
}

export interface SwitchProps extends ComponentPropsWithoutRef<'input'> {
  label?: ReactNode;
}

export function Switch({ label, className, ...props }: SwitchProps) {
  return (
    <label className={cx('lzt-switch', className)}>
      <input type="checkbox" {...props} />
      {label}
    </label>
  );
}
