'use client';

import type { Content, Project } from '@/content/types';
import { InstallBox } from '@/components/ui/Copy';
import { Rich } from '@/components/ui/Rich';
import { ProjectScene } from '@/components/scenes/scenes';

/**
 * One project. Sides alternate down the page (`flip`), so text and scene swap
 * columns block to block instead of marching in one rail.
 */
export function ProjectBlock({
  project,
  flip,
  labels,
}: {
  project: Project;
  flip: boolean;
  labels: { copyAll: string; copied: string };
}) {
  return (
    <article className={`proj reveal is-in${flip ? ' flip' : ''}`} id={project.id}>
      <div className="p-copy">
        <div className="p-kicker">{project.kicker}</div>
        <h3>
          <a href={project.href} target="_blank" rel="noopener noreferrer">
            {project.name}
          </a>
        </h3>
        <p>
          <Rich text={project.body} />
        </p>
        <div className="p-meta">
          {project.tags.map((tag) => (
            <span className="tagchip" key={tag}>
              {tag}
            </span>
          ))}
        </div>
        <InstallBox block={project.install} labels={labels} />
      </div>

      <div className="p-scene">
        <ProjectScene id={project.scene} />
      </div>
    </article>
  );
}

export function ProjectList({ t }: { t: Content }) {
  const labels = { copyAll: t.builder.copy === 'copy' ? 'copy all' : 'скопировать всё', copied: t.builder.copied };
  return (
    <section className="sec" id="projects">
      <div className="sec-head reveal is-in">
        <h2>
          {t.projectsHead.title}
          <br />
          <span className="g">{t.projectsHead.titleAccent}</span>
        </h2>
        <p>{t.projectsHead.sub}</p>
      </div>
      {t.projects.map((project, i) => (
        <ProjectBlock key={project.id} project={project} flip={i % 2 === 1} labels={labels} />
      ))}
    </section>
  );
}
