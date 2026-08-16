'use client';

import type { ReactNode } from 'react';

import { useInView } from '@/hooks/useInView';

/**
 * The frame every project scene shares: rounded panel, terminal bar, the slow
 * glow. Nine scenes used to carry their own copy of this chrome; now they pass
 * content and get the shell.
 *
 * `inView` is handed down so a scene can start its animation exactly when it is
 * seen — one shared observer decides that for all of them.
 */
export function Scene({
  title,
  className = '',
  children,
}: {
  title: string;
  className?: string;
  children: ReactNode | ((inView: boolean) => ReactNode);
}) {
  const { ref, inView } = useInView<HTMLDivElement>(false);

  return (
    <div ref={ref} className={`scene ${className}`.trim()}>
      <div className="term-bar">
        <i />
        <i />
        <i />
        <span className="ttl">{title}</span>
      </div>
      {typeof children === 'function' ? children(inView) : children}
    </div>
  );
}
