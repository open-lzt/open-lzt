import type { Content } from '@/content/types';
import { Hero } from '@/components/hero/Hero';
import { ProjectList } from '@/components/projects/ProjectBlock';
import { CtaSection, Footer, InstallSection } from '@/components/sections/Sections';

/**
 * The page itself. Both locales render this with their own dictionary — the
 * layout exists once, the text twice.
 */
export function Page({ t, locale }: { t: Content; locale: 'ru' | 'en' }) {
  return (
    <>
      <Hero t={t} locale={locale} />
      <main className="wrap">
        <ProjectList t={t} />
        <InstallSection t={t.install} />
        <CtaSection t={t.cta} />
        <Footer t={t} locale={locale} />
      </main>
    </>
  );
}
