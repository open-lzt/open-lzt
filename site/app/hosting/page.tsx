import type { Metadata } from 'next';

import { HostingPage } from '@/components/hosting/HostingPage';
import { ru } from '@/content/ru';

export const metadata: Metadata = {
  title: ru.hosting.meta.title,
  description: ru.hosting.meta.description,
  alternates: { canonical: '/hosting', languages: { ru: '/hosting', en: '/en/hosting' } },
};

export default function RuHostingPage() {
  return <HostingPage t={ru} locale="ru" />;
}
