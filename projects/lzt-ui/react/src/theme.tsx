import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
  type ComponentPropsWithoutRef,
  type ReactNode,
} from 'react';
import { cx } from './cx';

export type Theme = 'light' | 'dark';

const STORAGE_KEY = 'lzt-theme';

export interface ThemeContextValue {
  theme: Theme;
  setTheme: (theme: Theme) => void;
  toggle: () => void;
}

const ThemeContext = createContext<ThemeContextValue | null>(null);

function applyTheme(theme: Theme): void {
  document.documentElement.setAttribute('data-theme', theme);
}

export interface ThemeProviderProps {
  children: ReactNode;
  /** Theme assumed for the very first render, before localStorage is read. */
  defaultTheme?: Theme;
}

export function ThemeProvider({ children, defaultTheme = 'dark' }: ThemeProviderProps) {
  const [theme, setThemeState] = useState<Theme>(defaultTheme);

  useEffect(() => {
    // Deferred to an effect so server/client markup match on first paint —
    // localStorage doesn't exist during SSR, reading it here (not during render)
    // avoids a hydration mismatch.
    const stored = window.localStorage.getItem(STORAGE_KEY);
    const initial: Theme = stored === 'light' || stored === 'dark' ? stored : defaultTheme;
    setThemeState(initial);
    applyTheme(initial);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const setTheme = useCallback((next: Theme) => {
    setThemeState(next);
    applyTheme(next);
    window.localStorage.setItem(STORAGE_KEY, next);
  }, []);

  const toggle = useCallback(() => {
    setTheme(theme === 'dark' ? 'light' : 'dark');
  }, [theme, setTheme]);

  return <ThemeContext.Provider value={{ theme, setTheme, toggle }}>{children}</ThemeContext.Provider>;
}

export function useTheme(): ThemeContextValue {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme must be used within a ThemeProvider');
  return ctx;
}

export interface ThemeToggleProps extends ComponentPropsWithoutRef<'button'> {}

export function ThemeToggle({ className, type = 'button', ...props }: ThemeToggleProps) {
  const { theme, toggle } = useTheme();
  return (
    <button
      type={type}
      className={cx('lzt-btn', 'lzt-btn--ghost', className)}
      onClick={toggle}
      aria-label="Toggle color theme"
      {...props}
    >
      {theme === 'dark' ? 'Dark' : 'Light'}
    </button>
  );
}
