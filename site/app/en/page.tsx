import type { Metadata } from 'next';

import { Page } from '@/components/Page';
import { en } from '@/content/en';

export const metadata: Metadata = {
  title: en.meta.title,
  description: en.meta.description,
  alternates: { canonical: '/en' },
};

export default function EnPage() {
  return <Page t={en} locale="en" />;
}
