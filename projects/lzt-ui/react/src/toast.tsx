import { createContext, useCallback, useContext, useRef, useState, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { cx } from './cx';

export type ToastTone = 'default' | 'danger' | 'warning';

export interface ToastOptions {
  tone?: ToastTone;
  /** ms before auto-dismiss. Default 4000. */
  duration?: number;
}

interface ToastRecord extends ToastOptions {
  id: number;
  message: ReactNode;
  leaving: boolean;
}

export interface ToastContextValue {
  show: (message: ReactNode, options?: ToastOptions) => number;
  dismiss: (id: number) => void;
}

const ToastContext = createContext<ToastContextValue | null>(null);

// Matches --lzt-base in lzt-ui.css, the duration of .lzt-toast.is-leaving's exit animation.
const EXIT_DURATION_MS = 180;
const DEFAULT_DURATION_MS = 4000;

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<ToastRecord[]>([]);
  const idRef = useRef(0);

  const dismiss = useCallback((id: number) => {
    setToasts((current) => current.map((t) => (t.id === id ? { ...t, leaving: true } : t)));
    window.setTimeout(() => {
      setToasts((current) => current.filter((t) => t.id !== id));
    }, EXIT_DURATION_MS);
  }, []);

  const show = useCallback(
    (message: ReactNode, options: ToastOptions = {}) => {
      const id = (idRef.current += 1);
      const duration = options.duration ?? DEFAULT_DURATION_MS;
      setToasts((current) => [...current, { id, message, tone: options.tone, leaving: false }]);
      window.setTimeout(() => dismiss(id), duration);
      return id;
    },
    [dismiss],
  );

  return (
    <ToastContext.Provider value={{ show, dismiss }}>
      {children}
      {typeof document !== 'undefined' &&
        createPortal(
          <div className="lzt-toasts">
            {toasts.map((t) => (
              <div
                key={t.id}
                role="status"
                className={cx('lzt-toast', t.tone && t.tone !== 'default' && `lzt-toast--${t.tone}`, t.leaving && 'is-leaving')}
              >
                {t.message}
              </div>
            ))}
          </div>,
          document.body,
        )}
    </ToastContext.Provider>
  );
}

export function useToast(): ToastContextValue {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error('useToast must be used within a ToastProvider');
  return ctx;
}
