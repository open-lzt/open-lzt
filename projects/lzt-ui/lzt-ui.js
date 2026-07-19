/* lzt-ui — the small amount of behaviour the CSS can't express.
   No dependencies. Delegated listeners, so markup rendered later still works. */
(function () {
  'use strict';

  var THEME_KEY = 'lzt-theme';

  function closest(el, sel) {
    return el && el.closest ? el.closest(sel) : null;
  }

  /* theme ------------------------------------------------------------- */
  function applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    try {
      localStorage.setItem(THEME_KEY, theme);
    } catch (err) {
      /* private mode — the toggle still works for this page load */
    }
  }

  function initTheme() {
    var saved;
    try {
      saved = localStorage.getItem(THEME_KEY);
    } catch (err) {
      saved = null;
    }
    applyTheme(saved || 'dark');
  }

  function toggleTheme() {
    var now = document.documentElement.getAttribute('data-theme');
    applyTheme(now === 'light' ? 'dark' : 'light');
  }

  /* toast -------------------------------------------------------------- */
  function toast(message, variant, ms) {
    var host = document.querySelector('.lzt-toasts');
    if (!host) {
      host = document.createElement('div');
      host.className = 'lzt-toasts';
      document.body.appendChild(host);
    }
    var el = document.createElement('div');
    el.className = 'lzt-toast' + (variant ? ' lzt-toast--' + variant : '');
    el.textContent = message;
    host.appendChild(el);

    setTimeout(function () {
      el.classList.add('is-leaving');
      el.addEventListener('animationend', function () {
        el.remove();
      });
    }, ms || 3000);
    return el;
  }

  /* modal -------------------------------------------------------------- */
  function openModal(id) {
    var el = document.getElementById(id);
    if (el) el.classList.add('is-open');
  }

  function closeModal(el) {
    if (el) el.classList.remove('is-open');
  }

  /* delegated wiring ---------------------------------------------------- */
  document.addEventListener('click', function (e) {
    var t = e.target;

    var themeBtn = closest(t, '[data-lzt-theme-toggle]');
    if (themeBtn) {
      toggleTheme();
      return;
    }

    var tab = closest(t, '.lzt-tab');
    if (tab) {
      var tabs = tab.parentElement.querySelectorAll('.lzt-tab');
      for (var i = 0; i < tabs.length; i++) {
        tabs[i].setAttribute('aria-selected', String(tabs[i] === tab));
      }
      var panelId = tab.getAttribute('data-lzt-panel');
      if (panelId) {
        var group = tab.parentElement.getAttribute('data-lzt-tabs');
        var panels = document.querySelectorAll('[data-lzt-panel-group="' + group + '"]');
        for (var j = 0; j < panels.length; j++) {
          panels[j].hidden = panels[j].id !== panelId;
          if (!panels[j].hidden) panels[j].classList.add('lzt-enter');
        }
      }
      return;
    }

    var seg = closest(t, '.lzt-segmented__item');
    if (seg) {
      var segs = seg.parentElement.querySelectorAll('.lzt-segmented__item');
      for (var s = 0; s < segs.length; s++) {
        segs[s].setAttribute('aria-selected', String(segs[s] === seg));
      }
      return;
    }

    var spoilerBtn = closest(t, '.lzt-spoiler__btn');
    if (spoilerBtn) {
      closest(spoilerBtn, '.lzt-spoiler').classList.toggle('is-open');
      return;
    }

    var reaction = closest(t, '.lzt-reaction');
    if (reaction) {
      var mine = reaction.classList.toggle('is-mine');
      var countEl = reaction.querySelector('[data-count]');
      if (countEl) {
        countEl.textContent = String(Number(countEl.textContent) + (mine ? 1 : -1));
      }
      return;
    }

    var openBtn = closest(t, '[data-lzt-open]');
    if (openBtn) {
      openModal(openBtn.getAttribute('data-lzt-open'));
      return;
    }

    if (closest(t, '[data-lzt-close]')) {
      closeModal(closest(t, '.lzt-overlay'));
      return;
    }

    if (t.classList && t.classList.contains('lzt-overlay')) {
      closeModal(t);
      return;
    }

    var toastBtn = closest(t, '[data-lzt-toast]');
    if (toastBtn) {
      toast(toastBtn.getAttribute('data-lzt-toast'), toastBtn.getAttribute('data-lzt-toast-variant'));
      return;
    }

    /* dropdowns: toggle the clicked one, close the rest */
    var trigger = closest(t, '[data-lzt-dropdown]');
    var open = document.querySelectorAll('.lzt-dropdown.is-open');
    for (var k = 0; k < open.length; k++) {
      if (!trigger || closest(trigger, '.lzt-dropdown') !== open[k]) {
        open[k].classList.remove('is-open');
      }
    }
    if (trigger) closest(trigger, '.lzt-dropdown').classList.toggle('is-open');
  });

  document.addEventListener('keydown', function (e) {
    if (e.key !== 'Escape') return;
    var openOverlay = document.querySelector('.lzt-overlay.is-open');
    if (openOverlay) closeModal(openOverlay);
    var dd = document.querySelectorAll('.lzt-dropdown.is-open');
    for (var i = 0; i < dd.length; i++) dd[i].classList.remove('is-open');
  });

  initTheme();

  window.lzt = { toast: toast, openModal: openModal, setTheme: applyTheme };
})();
