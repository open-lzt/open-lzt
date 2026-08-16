import type { Metadata } from 'next';

import '@/styles/tokens.css';
import '@/styles/base.css';
import '@/styles/components.css';

import { ru } from '@/content/ru';
import { SITE_URL } from '@/lib/site';

export const metadata: Metadata = {
  title: ru.meta.title,
  description: ru.meta.description,
  metadataBase: new URL(SITE_URL),
  openGraph: {
    title: ru.meta.title,
    description: ru.meta.description,
    url: SITE_URL,
    siteName: 'OPENLZT',
    type: 'website',
  },
  alternates: { canonical: '/', languages: { ru: '/', en: '/en' } },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  // `lang` is corrected per page by the EN route's own <html lang> is not
  // available in a shared layout under static export, so the EN page sets it on
  // <body data-lang> for styling and screen readers announce via the page title.
  return (
    <html lang="ru">
      <body id="top">{children}</body>
    </html>
  );
}
