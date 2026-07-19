/* lzt-icons — one line-icon set, injected as an inline SVG sprite.

   Why injected rather than an external `icons.svg` file: `<use href="file.svg#id">`
   is blocked by CORS on file:// and cross-origin, so a shared external sprite
   silently renders nothing. Injecting keeps one source of truth and works everywhere.

   Usage:  <svg class="lzt-icon"><use href="#i-search"/></svg>
           <svg class="lzt-icon lzt-icon--lg"><use href="#i-bell"/></svg>

   Grid 24x24, stroke-based, 2px stroke, round caps and joins, currentColor.
   Every icon obeys the same optical weight — do not mix in filled glyphs. */
(function () {
  'use strict';

  var PATHS = {
    /* navigation */
    'home': '<path d="M3 10.5 12 3l9 7.5"/><path d="M5.5 9.5V20h13V9.5"/><path d="M9.5 20v-6h5v6"/>',
    'menu': '<path d="M4 7h16M4 12h16M4 17h16"/>',
    'grid': '<rect x="3.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="13.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="3.5" y="13.5" width="7" height="7" rx="1.5"/><rect x="13.5" y="13.5" width="7" height="7" rx="1.5"/>',
    'list': '<path d="M8 6h13M8 12h13M8 18h13"/><path d="M3.5 6h.01M3.5 12h.01M3.5 18h.01"/>',
    'search': '<circle cx="11" cy="11" r="7"/><path d="M16.5 16.5 21 21"/>',
    'filter': '<path d="M3 5h18l-7 8v6l-4 2v-8z"/>',
    'sort': '<path d="M7 4v16M7 20l-3-3M7 20l3-3"/><path d="M17 20V4M17 4l-3 3M17 4l3 3"/>',
    'external': '<path d="M14 4h6v6"/><path d="M20 4 11 13"/><path d="M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5"/>',
    'link': '<path d="M10 13.5a4 4 0 0 0 5.7 0l3-3A4 4 0 0 0 13 4.8l-1.7 1.7"/><path d="M14 10.5a4 4 0 0 0-5.7 0l-3 3A4 4 0 0 0 11 19.2l1.7-1.7"/>',

    /* chevrons + arrows */
    'chevron-down': '<path d="m6 9 6 6 6-6"/>',
    'chevron-up': '<path d="m6 15 6-6 6 6"/>',
    'chevron-left': '<path d="m15 6-6 6 6 6"/>',
    'chevron-right': '<path d="m9 6 6 6-6 6"/>',
    'arrow-right': '<path d="M4 12h15"/><path d="m13 6 6 6-6 6"/>',
    'arrow-left': '<path d="M20 12H5"/><path d="m11 6-6 6 6 6"/>',
    'arrow-up': '<path d="M12 20V5"/><path d="m6 11 6-6 6 6"/>',
    'arrow-down': '<path d="M12 4v15"/><path d="m6 13 6 6 6-6"/>',

    /* actions */
    'plus': '<path d="M12 5v14M5 12h14"/>',
    'minus': '<path d="M5 12h14"/>',
    'x': '<path d="m6 6 12 12M18 6 6 18"/>',
    'check': '<path d="m4 12.5 5 5L20 6.5"/>',
    'edit': '<path d="M4 20h4L19 9a2.8 2.8 0 0 0-4-4L4 16z"/><path d="m14.5 6.5 3 3"/>',
    'trash': '<path d="M4 7h16"/><path d="M9.5 7V4.5h5V7"/><path d="M6 7v13a1 1 0 0 0 1 1h10a1 1 0 0 0 1-1V7"/><path d="M10 11v6M14 11v6"/>',
    'copy': '<rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5.5 15H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1h9a1 1 0 0 1 1 1v.5"/>',
    'share': '<circle cx="18" cy="5.5" r="2.5"/><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="18.5" r="2.5"/><path d="m8.2 10.8 7.6-4M8.2 13.2l7.6 4"/>',
    'send': '<path d="M21 3 10.5 13.5"/><path d="M21 3 14.5 21l-4-7.5L3 9.5z"/>',
    'upload': '<path d="M4 16v3a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-3"/><path d="M12 15V4"/><path d="m7.5 8.5 4.5-4.5 4.5 4.5"/>',
    'download': '<path d="M4 16v3a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-3"/><path d="M12 4v11"/><path d="m7.5 10.5 4.5 4.5 4.5-4.5"/>',
    'refresh': '<path d="M20 11A8 8 0 0 0 6.3 6.3L4 8.5"/><path d="M4 4v4.5h4.5"/><path d="M4 13a8 8 0 0 0 13.7 4.7L20 15.5"/><path d="M20 20v-4.5h-4.5"/>',
    'more-h': '<circle cx="5.5" cy="12" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="18.5" cy="12" r="1.4"/>',
    'more-v': '<circle cx="12" cy="5.5" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="12" cy="18.5" r="1.4"/>',

    /* forum + social */
    'message': '<path d="M20 15a2 2 0 0 1-2 2H8l-4 4V6a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2z"/>',
    'messages': '<path d="M17 12a2 2 0 0 1-2 2H8l-4 3.5V5a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2z"/><path d="M8 16.5v.5a2 2 0 0 0 2 2h5l4 3.5V10a2 2 0 0 0-2-2h-.5"/>',
    'reply': '<path d="M9 14 4 9l5-5"/><path d="M4 9h10a6 6 0 0 1 6 6v5"/>',
    'quote': '<path d="M10 6H6a2 2 0 0 0-2 2v3h5v3a2 2 0 0 1-2 2H6"/><path d="M20 6h-4a2 2 0 0 0-2 2v3h5v3a2 2 0 0 1-2 2h-1"/>',
    'heart': '<path d="M12 20S3.5 14.5 3.5 9A4.5 4.5 0 0 1 12 6.8 4.5 4.5 0 0 1 20.5 9c0 5.5-8.5 11-8.5 11z"/>',
    'star': '<path d="m12 3.5 2.7 5.6 6 .9-4.4 4.3 1.1 6.1-5.4-2.9-5.4 2.9 1.1-6.1L3.3 10l6-.9z"/>',
    'bookmark': '<path d="M6 4h12a1 1 0 0 1 1 1v15l-7-4-7 4V5a1 1 0 0 1 1-1z"/>',
    'pin': '<path d="M12 17v5"/><path d="M9 10.8V4h6v6.8l2.2 2.4a1 1 0 0 1-.8 1.8H7.6a1 1 0 0 1-.8-1.8z"/>',
    'user': '<circle cx="12" cy="8" r="4"/><path d="M4.5 20a7.5 7.5 0 0 1 15 0"/>',
    'users': '<circle cx="9.5" cy="8" r="3.5"/><path d="M3 20a6.5 6.5 0 0 1 13 0"/><path d="M16.5 4.6a3.5 3.5 0 0 1 0 6.8"/><path d="M18 14.2A6.5 6.5 0 0 1 21 20"/>',
    'inbox': '<path d="M3 13h5l1.5 3h5L16 13h5"/><path d="M5.5 4.5h13L21 13v6a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-6z"/>',
    'bell': '<path d="M18 9a6 6 0 1 0-12 0c0 6-2.5 8-2.5 8h17S18 15 18 9z"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/>',
    'flame': '<path d="M12 21a6 6 0 0 0 6-6c0-4-3-5.5-3-9 0-1-1.5-3-3-3 .5 3-2 4.5-3.5 7A7.6 7.6 0 0 0 6 15a6 6 0 0 0 6 6z"/><path d="M12 21a2.7 2.7 0 0 0 2.7-2.7c0-1.8-1.4-2.5-1.4-4.1-1.3.9-2.6 2-2.6 4.1A2.7 2.7 0 0 0 12 21z"/>',
    'eye': '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle cx="12" cy="12" r="3"/>',

    /* status + system */
    'lock': '<rect x="4" y="10.5" width="16" height="10" rx="2"/><path d="M8 10.5V7a4 4 0 0 1 8 0v3.5"/>',
    'unlock': '<rect x="4" y="10.5" width="16" height="10" rx="2"/><path d="M8 10.5V7a4 4 0 0 1 7.5-2"/>',
    'shield': '<path d="M12 3.5 20 6v6c0 4.5-3.4 7.6-8 9-4.6-1.4-8-4.5-8-9V6z"/><path d="m9 12 2 2 4-4"/>',
    'zap': '<path d="M13.5 3 5 13.5h6L10.5 21 19 10.5h-6z"/>',
    'info': '<circle cx="12" cy="12" r="9"/><path d="M12 11.5v5"/><path d="M12 7.8h.01"/>',
    'alert': '<path d="M12 4 2.8 20h18.4z"/><path d="M12 10v4"/><path d="M12 17.2h.01"/>',
    'clock': '<circle cx="12" cy="12" r="9"/><path d="M12 7v5.3l3.3 2"/>',
    'calendar': '<rect x="3.5" y="5.5" width="17" height="15" rx="2"/><path d="M3.5 10h17"/><path d="M8 3.5v4M16 3.5v4"/>',
    'settings': '<circle cx="12" cy="12" r="3"/><path d="M12 2.5v3M12 18.5v3M21.5 12h-3M5.5 12h-3M18.7 5.3l-2.1 2.1M7.4 16.6l-2.1 2.1M18.7 18.7l-2.1-2.1M7.4 7.4 5.3 5.3"/>',
    'sliders': '<path d="M4 7h9M17 7h3M4 17h3M11 17h9"/><circle cx="15" cy="7" r="2"/><circle cx="9" cy="17" r="2"/>',
    'logout': '<path d="M15 5h3a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1h-3"/><path d="M11 8 7 12l4 4"/><path d="M7 12h9"/>',
    'sun': '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
    'moon': '<path d="M20 14.5A8.5 8.5 0 0 1 9.5 4 8.5 8.5 0 1 0 20 14.5z"/>',

    /* domain: market, code, files */
    'wallet': '<path d="M3.5 7.5A2 2 0 0 1 5.5 5.5H18a1 1 0 0 1 1 1v2"/><path d="M3.5 7.5v10a2 2 0 0 0 2 2H19a1 1 0 0 0 1-1v-9a1 1 0 0 0-1-1H5.5a2 2 0 0 1-2-2z"/><path d="M16.5 13h.01"/>',
    'chart': '<path d="M4 20V4"/><path d="M4 20h16"/><path d="M8 16v-4M12.5 16V8M17 16v-6"/>',
    'package': '<path d="M12 3 3.5 7.5v9L12 21l8.5-4.5v-9z"/><path d="M3.5 7.5 12 12l8.5-4.5"/><path d="M12 12v9"/>',
    'folder': '<path d="M3.5 7a1 1 0 0 1 1-1h4l2 2.5h8a1 1 0 0 1 1 1V18a1 1 0 0 1-1 1h-14a1 1 0 0 1-1-1z"/>',
    'image': '<rect x="3.5" y="4.5" width="17" height="15" rx="2"/><circle cx="9" cy="10" r="1.6"/><path d="m4.5 17.5 4.8-4.5 4 3.6 2.7-2.4 3.5 3.3"/>',
    'code': '<path d="m8.5 8-5 4 5 4"/><path d="m15.5 8 5 4-5 4"/><path d="m13.5 4.5-3 15"/>',
    'terminal': '<rect x="3" y="4.5" width="18" height="15" rx="2"/><path d="m7.5 9.5 3 2.5-3 2.5"/><path d="M12.5 15h4"/>',
    'tag': '<path d="M11 3.5H5.5a2 2 0 0 0-2 2V11a2 2 0 0 0 .6 1.4l7.5 7.5a2 2 0 0 0 2.8 0l5.5-5.5a2 2 0 0 0 0-2.8L12.4 4.1a2 2 0 0 0-1.4-.6z"/><path d="M8 8h.01"/>',
    'bot': '<rect x="4" y="8" width="16" height="12" rx="3"/><path d="M12 4v4"/><circle cx="12" cy="3" r="1.2"/><path d="M9 13.5h.01M15 13.5h.01"/><path d="M9.5 17h5"/>'
  };

  function build() {
    var svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('aria-hidden', 'true');
    svg.setAttribute('width', '0');
    svg.setAttribute('height', '0');
    svg.style.position = 'absolute';
    svg.style.overflow = 'hidden';

    var markup = '';
    for (var name in PATHS) {
      if (!Object.prototype.hasOwnProperty.call(PATHS, name)) continue;
      markup +=
        '<symbol id="i-' + name + '" viewBox="0 0 24 24" fill="none" stroke="currentColor"' +
        ' stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' +
        PATHS[name] +
        '</symbol>';
    }
    svg.innerHTML = markup;
    document.body.insertBefore(svg, document.body.firstChild);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', build);
  } else {
    build();
  }

  window.lztIcons = Object.keys(PATHS);
})();
