import type { ComponentPropsWithoutRef } from 'react';
import { cx } from './cx';

export interface IconProps extends ComponentPropsWithoutRef<'svg'> {
  /** Sprite symbol name without the `i-` prefix, e.g. "search" for `#i-search`. */
  name: string;
  /** Pixel size. Omit to inherit `.lzt-icon` (16px) or a `--sm`/`--lg`/`--xl` modifier. */
  size?: number;
}

/** Requires the sprite from `lzt-icons.js` to be present on the page. */
export function Icon({ name, size, className, ...props }: IconProps) {
  return (
    <svg
      className={cx('lzt-icon', className)}
      width={size}
      height={size}
      aria-hidden="true"
      {...props}
    >
      <use href={`#i-${name}`} />
    </svg>
  );
}
