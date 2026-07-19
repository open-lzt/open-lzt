import type { ComponentPropsWithoutRef } from 'react';
import { cx } from './cx';

type BoxProps = ComponentPropsWithoutRef<'div'>;

function makeBox(baseClass: string, displayName: string) {
  function Box({ className, ...props }: BoxProps) {
    return <div className={cx(baseClass, className)} {...props} />;
  }
  Box.displayName = displayName;
  return Box;
}

export type ShellProps = BoxProps;
export type ContainerProps = BoxProps;
export type MainProps = BoxProps;
export type StackProps = BoxProps;
export type GridProps = BoxProps;
export type SpacerProps = BoxProps;

export const Shell = makeBox('lzt-shell', 'Shell');
export const Container = makeBox('lzt-container', 'Container');
export const Main = makeBox('lzt-main', 'Main');
export const Stack = makeBox('lzt-stack', 'Stack');
export const Grid = makeBox('lzt-grid', 'Grid');
export const Spacer = makeBox('lzt-spacer', 'Spacer');

export interface RowProps extends BoxProps {
  between?: boolean;
  wrap?: boolean;
}

export function Row({ between, wrap, className, ...props }: RowProps) {
  return (
    <div
      className={cx('lzt-row', between && 'lzt-row--between', wrap && 'lzt-row--wrap', className)}
      {...props}
    />
  );
}

export type DividerProps = ComponentPropsWithoutRef<'hr'>;

export function Divider({ className, ...props }: DividerProps) {
  return <hr className={cx('lzt-divider', className)} {...props} />;
}
