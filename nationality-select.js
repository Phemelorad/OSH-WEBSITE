// Searchable nationality combobox — use on claim form #nationality
(function () {

  if (!document.getElementById('nat-select-styles')) {
    const s = document.createElement('style');
    s.id = 'nat-select-styles';
    s.textContent = `
      .nat-select-wrap { position: relative; }
      .nat-select-wrap input[type="text"] { width: 100%; }
      .nat-dropdown {
        position: absolute; left: 0; right: 0; top: 100%;
        margin-top: 4px; max-height: 240px; overflow-y: auto;
        background: #fff; border: 2px solid #e0e0e0; border-radius: 8px;
        box-shadow: 0 8px 24px rgba(0,0,0,0.12); z-index: 200;
        display: none;
      }
      .nat-dropdown.open { display: block; }
      .nat-option {
        padding: 10px 14px; font-size: 14px; cursor: pointer;
        border-bottom: 1px solid #f5f5f5; color: #333;
      }
      .nat-option:last-child { border-bottom: none; }
      .nat-option:hover, .nat-option.active { background: #f0f0f0; }
      .nat-option.pinned { font-weight: 600; }
      .nat-empty {
        padding: 14px; font-size: 13px; color: #888; text-align: center;
      }
      .nat-hint {
        font-size: 11px; color: #999; margin-top: 4px;
      }
    `;
    document.head.appendChild(s);
  }

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;')
      .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  /**
   * @param {string} inputId — e.g. 'nationality'
   * @param {{ pinned?: string[] }} options
   */
  window.initNationalitySelect = function (inputId, options) {
    const input = document.getElementById(inputId);
    if (!input) return;

    const list = window.NATIONALITIES || [];
    const pinned = new Set((options && options.pinned) || ['Botswana']);

    let wrap = input.closest('.nat-select-wrap');
    if (!wrap) {
      wrap = document.createElement('div');
      wrap.className = 'nat-select-wrap';
      input.parentNode.insertBefore(wrap, input);
      wrap.appendChild(input);
    }

    let dropdown = wrap.querySelector('.nat-dropdown');
    if (!dropdown) {
      dropdown = document.createElement('div');
      dropdown.className = 'nat-dropdown';
      dropdown.setAttribute('role', 'listbox');
      wrap.appendChild(dropdown);
    }

    let hint = wrap.querySelector('.nat-hint');
    if (!hint) {
      hint = document.createElement('p');
      hint.className = 'nat-hint';
      hint.textContent = 'Type to search, then click a nationality';
      wrap.appendChild(hint);
    }

    input.setAttribute('autocomplete', 'off');
    input.setAttribute('role', 'combobox');
    input.setAttribute('aria-expanded', 'false');
    input.setAttribute('aria-autocomplete', 'list');
    if (!input.placeholder || input.placeholder === 'Enter nationality') {
      input.placeholder = 'Search nationality…';
    }

    let activeIndex = -1;
    let filtered = [];

    function filterList(q) {
      const term = (q || '').trim().toLowerCase();
      if (!term) {
        return list.slice(0, 80);
      }
      return list.filter(n => n.toLowerCase().includes(term)).slice(0, 80);
    }

    function renderOptions(items) {
      filtered = items;
      activeIndex = -1;
      if (!items.length) {
        dropdown.innerHTML = '<div class="nat-empty">No matching nationality</div>';
        return;
      }
      dropdown.innerHTML = items.map((name, i) => {
        const pin = pinned.has(name) ? ' pinned' : '';
        return `<div class="nat-option${pin}" role="option" data-index="${i}">${escapeHtml(name)}</div>`;
      }).join('');
      dropdown.querySelectorAll('.nat-option').forEach(el => {
        el.addEventListener('mousedown', e => {
          e.preventDefault();
          selectValue(el.textContent);
        });
      });
    }

    function openDropdown() {
      renderOptions(filterList(input.value));
      dropdown.classList.add('open');
      input.setAttribute('aria-expanded', 'true');
    }

    function closeDropdown() {
      dropdown.classList.remove('open');
      input.setAttribute('aria-expanded', 'false');
      activeIndex = -1;
    }

    function selectValue(val) {
      input.value = val;
      closeDropdown();
      input.dispatchEvent(new Event('change', { bubbles: true }));
      input.classList.remove('error');
    }

    function setActive(idx) {
      const opts = dropdown.querySelectorAll('.nat-option');
      opts.forEach(o => o.classList.remove('active'));
      if (idx < 0 || idx >= opts.length) return;
      activeIndex = idx;
      opts[idx].classList.add('active');
      opts[idx].scrollIntoView({ block: 'nearest' });
    }

    input.addEventListener('focus', openDropdown);
    input.addEventListener('input', openDropdown);

    input.addEventListener('keydown', e => {
      if (!dropdown.classList.contains('open')) {
        if (e.key === 'ArrowDown' || e.key === 'Enter') openDropdown();
        return;
      }
      const opts = dropdown.querySelectorAll('.nat-option');
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        setActive(Math.min(activeIndex + 1, opts.length - 1));
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        setActive(Math.max(activeIndex - 1, 0));
      } else if (e.key === 'Enter' && activeIndex >= 0 && opts[activeIndex]) {
        e.preventDefault();
        selectValue(opts[activeIndex].textContent);
      } else if (e.key === 'Escape') {
        closeDropdown();
      }
    });

    input.addEventListener('blur', () => {
      setTimeout(() => {
        closeDropdown();
        const v = input.value.trim();
        if (v && !list.includes(v)) {
          const match = list.find(n => n.toLowerCase() === v.toLowerCase());
          if (match) input.value = match;
        }
      }, 150);
    });

    document.addEventListener('click', e => {
      if (!wrap.contains(e.target)) closeDropdown();
    });
  };
})();
