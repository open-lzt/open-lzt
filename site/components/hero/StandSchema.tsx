'use client';

import { useCallback, useEffect, useRef, useState } from 'react';

import type { Content } from '@/content/types';
import { Icon, type IconName } from '@/components/ui/Icon';
import { Rich } from '@/components/ui/Rich';

/**
 * The signature moment: the stand drawn as a layered graph, with one pulse that
 * travels a wire, then DWELLS on the node it reached. A process is a sequence of
 * waits, not a smooth glide — and there is exactly one dot, never a trail.
 *
 * Clicking a node scrolls to that project.
 */

type Node = { tag: string; icon: IconName; x: number; y: number; base?: boolean };

const NODES: Node[] = [
  { tag: 'PYLZT', icon: 'py', x: 391, y: 352, base: true },
  { tag: 'TESTNET', icon: 'flask', x: 218, y: 196 },
  { tag: 'EVENTUS', icon: 'bolt', x: 348, y: 196 },
  { tag: 'AUTO-LZT', icon: 'flow', x: 458, y: 196 },
  { tag: 'MCP', icon: 'mcp', x: 580, y: 196 },
  { tag: 'SDK', icon: 'sdk', x: 260, y: 36 },
  { tag: 'FLOWS', icon: 'box', x: 404, y: 36 },
  { tag: 'PLUGINS', icon: 'plug', x: 536, y: 36 },
  { tag: 'UI', icon: 'ui', x: 668, y: 36 },
];

/** Wire id → the node tag it ends on. */
const WIRES: { d: string; to: string }[] = [
  { d: 'M430 356 C430 322 260 320 250 268', to: 'TESTNET' },
  { d: 'M430 356 C430 322 380 318 380 268', to: 'EVENTUS' },
  { d: 'M430 356 C430 322 490 318 490 268', to: 'AUTO-LZT' },
  { d: 'M430 356 C430 322 600 320 612 268', to: 'MCP' },
  { d: 'M380 196 C380 150 300 150 292 108', to: 'SDK' },
  { d: 'M490 196 C490 150 440 150 436 108', to: 'FLOWS' },
  { d: 'M490 196 C490 150 560 150 568 108', to: 'PLUGINS' },
  { d: 'M612 196 C620 150 690 152 700 108', to: 'UI' },
];

const STAGE_W = 860;
const STAGE_H = 430;

export function StandSchema({ t }: { t: Content['stand'] }) {
  const wrapRef = useRef<HTMLDivElement>(null);
  const pathsRef = useRef<Map<string, SVGPathElement>>(new Map());
  const dotRef = useRef<SVGCircleElement>(null);

  const [scale, setScale] = useState(1);
  const [hot, setHot] = useState<string | null>(null);
  const [caption, setCaption] = useState<string | null>(null);
  const paused = useRef(false);

  // The stage is drawn at a fixed size and scaled down — a diagram is rescaled,
  // never reflowed, or the geometry stops meaning anything.
  useEffect(() => {
    const fit = () => {
      const width = wrapRef.current?.clientWidth ?? STAGE_W;
      setScale(Math.min(1, width / STAGE_W));
    };
    fit();
    window.addEventListener('resize', fit);
    return () => window.removeEventListener('resize', fit);
  }, []);

  const captionFor = useCallback(
    (tag: string) => t.nodes.find((n) => n.tag === tag)?.caption ?? null,
    [t.nodes],
  );

  useEffect(() => {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

    let index = 0;
    let frame = 0;
    let timer: ReturnType<typeof setTimeout>;

    const step = () => {
      if (paused.current) {
        timer = setTimeout(step, 600);
        return;
      }
      const wire = WIRES[index % WIRES.length];
      index += 1;
      const path = pathsRef.current.get(wire.to);
      const dot = dotRef.current;
      if (!path || !dot) return;

      const length = path.getTotalLength();
      const t0 = performance.now();
      dot.setAttribute('opacity', '1');

      const travel = (now: number) => {
        const p = Math.min(1, (now - t0) / 1100);
        const eased = 1 - Math.pow(1 - p, 3);
        const point = path.getPointAtLength(length * eased);
        dot.setAttribute('cx', String(point.x));
        dot.setAttribute('cy', String(point.y));
        if (p < 1) {
          frame = requestAnimationFrame(travel);
          return;
        }
        // Arrived: hide the dot under the node and let the node itself flare.
        dot.setAttribute('opacity', '0');
        setHot(wire.to);
        if (!paused.current) setCaption(captionFor(wire.to));
        timer = setTimeout(() => {
          setHot(null);
          timer = setTimeout(step, 300);
        }, 800);
      };
      frame = requestAnimationFrame(travel);
    };

    timer = setTimeout(step, 1200);
    return () => {
      clearTimeout(timer);
      cancelAnimationFrame(frame);
    };
  }, [captionFor]);

  return (
    <div className="stand" id="stand" ref={wrapRef}>
      <div className="stand-scale" style={{ transform: `scale(${scale})`, height: STAGE_H * scale }}>
        <div className="stand-stage">
          <svg className="wires" viewBox={`0 0 ${STAGE_W} ${STAGE_H}`} width={STAGE_W} height={STAGE_H} aria-hidden="true">
            {WIRES.map((wire) => (
              <path
                key={wire.to}
                d={wire.d}
                ref={(el) => {
                  if (el) pathsRef.current.set(wire.to, el);
                }}
              />
            ))}
            <circle className="pulse-dot" r="4.5" fill="#6bf24a" opacity="0" ref={dotRef} />
          </svg>

          {NODES.map((node) => {
            const target = t.nodes.find((n) => n.tag === node.tag);
            return (
              <button
                type="button"
                key={node.tag}
                className={`snode${node.base ? ' base' : ''}${hot === node.tag ? ' hot' : ''}`}
                style={{ left: node.x, top: node.y }}
                onMouseEnter={() => {
                  paused.current = true;
                  setCaption(target?.caption ?? null);
                }}
                onMouseLeave={() => {
                  paused.current = false;
                }}
                onClick={() => {
                  const el = document.getElementById(target?.goto ?? '');
                  el?.scrollIntoView({ behavior: 'smooth', block: 'center' });
                }}
              >
                <span className="pad">
                  <Icon name={node.icon} size={node.base ? 40 : 32} />
                </span>
                <span className="tag">{node.tag}</span>
              </button>
            );
          })}
        </div>
      </div>

      <div className="stand-cap">{caption ? <Rich text={caption} /> : t.hint}</div>
    </div>
  );
}
