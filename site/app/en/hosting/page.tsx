import type { Metadata } from 'next';

import { HostingPage } from '@/components/hosting/HostingPage';
import { en } from '@/content/en';

export const metadata: Metadata = {
  title: en.hosting.meta.title,
  description: en.hosting.meta.description,
  alternates: { canonical: '/en/hosting', languages: { ru: '/hosting', en: '/en/hosting' } },
};

export default function EnHostingPage() {
  return <HostingPage t={en} locale="en" />;
}
