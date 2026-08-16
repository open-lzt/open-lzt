'use client';

import { useEffect, useRef, useState } from 'react';

/**
 * One IntersectionObserver for every scene and reveal on the page.
 *
 * The prototype had six separate observers and timers. They all answered the
 * same question — "is this on screen yet" — so they collapse into one shared
 * observer, and each element just subscribes to its own answer.
 */

type Callback = (inView: boolean) => void;

let observer: IntersectionObserver | null = null;
const subscribers = new Map<Element, Callback>();

function shared(): IntersectionObserver {
  observer ??= new IntersectionObserver(
    (entries) => {
      for (const entry of entries) subscribers.get(entry.target)?.(entry.isIntersecting);
    },
    { threshold: 0.15 },
  );
  return observer;
}

/**
 * @param once stop watching after the first time it becomes visible — used by
 *   reveals, where re-hiding on scroll-back would be a distraction.
 */
export function useInView<T extends HTMLElement>(once = true) {
  const ref = useRef<T | null>(null);
  const [inView, setInView] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    // A reduced-motion visitor gets the final state immediately: the observer
    // exists to time animation, and there is no animation to time.
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      setInView(true);
      return;
    }

    const io = shared();
    subscribers.set(el, (visible) => {
      setInView(visible);
      if (visible && once) {
        subscribers.delete(el);
        io.unobserve(el);
      }
    });
    io.observe(el);

    return () => {
      subscribers.delete(el);
      io.unobserve(el);
    };
  }, [once]);

  return { ref, inView };
}
