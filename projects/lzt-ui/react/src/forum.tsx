import { useState, type ComponentPropsWithoutRef, type ReactNode } from 'react';
import { cx } from './cx';
import { Icon } from './Icon';

export interface ThreadProps extends ComponentPropsWithoutRef<'div'> {
  unread?: boolean;
  pinned?: boolean;
}

export function Thread({ unread, pinned, className, ...props }: ThreadProps) {
  return <div className={cx('lzt-thread', unread && 'is-unread', pinned && 'is-pinned', className)} {...props} />;
}

export type ThreadMainProps = ComponentPropsWithoutRef<'div'>;
export function ThreadMain({ className, ...props }: ThreadMainProps) {
  return <div className={cx('lzt-thread__main', className)} {...props} />;
}

export type ThreadTitleProps = ComponentPropsWithoutRef<'div'>;
export function ThreadTitle({ className, ...props }: ThreadTitleProps) {
  return <div className={cx('lzt-thread__title', className)} {...props} />;
}

export type ThreadMetaProps = ComponentPropsWithoutRef<'div'>;
export function ThreadMeta({ className, ...props }: ThreadMetaProps) {
  return <div className={cx('lzt-thread__meta', className)} {...props} />;
}

export type ThreadStatsProps = ComponentPropsWithoutRef<'div'>;
export function ThreadStats({ className, ...props }: ThreadStatsProps) {
  return <div className={cx('lzt-thread__stats', className)} {...props} />;
}

export interface ThreadStatProps extends ComponentPropsWithoutRef<'div'> {
  value: ReactNode;
  label: ReactNode;
}
export function ThreadStat({ value, label, className, ...props }: ThreadStatProps) {
  return (
    <div className={cx('lzt-thread__stat', className)} {...props}>
      <b>{value}</b>
      <span>{label}</span>
    </div>
  );
}

export interface PostProps extends ComponentPropsWithoutRef<'div'> {
  op?: boolean;
}
export function Post({ op, className, ...props }: PostProps) {
  return <div className={cx('lzt-post', op && 'is-op', className)} {...props} />;
}

export type PostUserProps = ComponentPropsWithoutRef<'div'>;
export function PostUser({ className, ...props }: PostUserProps) {
  return <div className={cx('lzt-post__user', className)} {...props} />;
}

export type PostNameProps = ComponentPropsWithoutRef<'div'>;
export function PostName({ className, ...props }: PostNameProps) {
  return <div className={cx('lzt-post__name', className)} {...props} />;
}

export type PostRoleProps = ComponentPropsWithoutRef<'div'>;
export function PostRole({ className, ...props }: PostRoleProps) {
  return <div className={cx('lzt-post__role', className)} {...props} />;
}

export type PostUserStatsProps = ComponentPropsWithoutRef<'div'>;
export function PostUserStats({ className, ...props }: PostUserStatsProps) {
  return <div className={cx('lzt-post__userstats', className)} {...props} />;
}

export type PostBodyProps = ComponentPropsWithoutRef<'div'>;
export function PostBody({ className, ...props }: PostBodyProps) {
  return <div className={cx('lzt-post__body', className)} {...props} />;
}

export type PostHeadProps = ComponentPropsWithoutRef<'div'>;
export function PostHead({ className, ...props }: PostHeadProps) {
  return <div className={cx('lzt-post__head', className)} {...props} />;
}

export type PostContentProps = ComponentPropsWithoutRef<'div'>;
export function PostContent({ className, ...props }: PostContentProps) {
  return <div className={cx('lzt-post__content', className)} {...props} />;
}

export type PostFootProps = ComponentPropsWithoutRef<'div'>;
export function PostFoot({ className, ...props }: PostFootProps) {
  return <div className={cx('lzt-post__foot', className)} {...props} />;
}

export interface QuoteProps extends ComponentPropsWithoutRef<'blockquote'> {
  author?: ReactNode;
}
export function Quote({ author, className, children, ...props }: QuoteProps) {
  return (
    <blockquote className={cx('lzt-quote', className)} {...props}>
      {author && <span className="lzt-quote__author">{author}</span>}
      {children}
    </blockquote>
  );
}

export type CodeProps = ComponentPropsWithoutRef<'pre'>;
export function Code({ className, children, ...props }: CodeProps) {
  return (
    <pre className={cx('lzt-code', className)} {...props}>
      <code>{children}</code>
    </pre>
  );
}

export interface SpoilerProps extends ComponentPropsWithoutRef<'div'> {
  label: ReactNode;
  open?: boolean;
  defaultOpen?: boolean;
  onOpenChange?: (open: boolean) => void;
}

export function Spoiler({ label, open, defaultOpen = false, onOpenChange, className, children, ...props }: SpoilerProps) {
  const [internalOpen, setInternalOpen] = useState(defaultOpen);
  const isOpen = open ?? internalOpen;

  const toggle = () => {
    const next = !isOpen;
    if (open === undefined) setInternalOpen(next);
    onOpenChange?.(next);
  };

  return (
    <div className={cx('lzt-spoiler', isOpen && 'is-open', className)} {...props}>
      <button type="button" className="lzt-spoiler__btn" aria-expanded={isOpen} onClick={toggle}>
        {label}
        <span className="lzt-spoiler__chevron">
          <Icon name="chevron-down" size={14} />
        </span>
      </button>
      {/* the inner wrapper is load-bearing: the 0fr→1fr grid animation
          collapses without a min-height:0 child to clip */}
      <div className="lzt-spoiler__content">
        <div className="lzt-spoiler__inner">{children}</div>
      </div>
    </div>
  );
}

export type ReactionsProps = ComponentPropsWithoutRef<'div'>;
export function Reactions({ className, ...props }: ReactionsProps) {
  return <div className={cx('lzt-reactions', className)} {...props} />;
}

export interface ReactionProps extends ComponentPropsWithoutRef<'button'> {
  mine?: boolean;
}
export function Reaction({ mine, className, type = 'button', ...props }: ReactionProps) {
  return <button type={type} className={cx('lzt-reaction', mine && 'is-mine', className)} {...props} />;
}
