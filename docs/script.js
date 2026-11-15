(() => {
  const search = document.querySelector('#input-search');
  const cards = [...document.querySelectorAll('[data-input]')];
  const groups = [...document.querySelectorAll('.input-group')];
  const count = document.querySelector('#search-count');
  const empty = document.querySelector('#no-results');
  if (!search || !count || !empty) return;
  search.addEventListener('input', () => {
    const query = search.value.trim().toLocaleLowerCase();
    let visible = 0;
    for (const card of cards) {
      const match = card.textContent.toLocaleLowerCase().includes(query);
      card.hidden = !match;
      if (match) visible++;
    }
    for (const group of groups) group.hidden = !group.querySelector('[data-input]:not([hidden])');
    empty.hidden = visible !== 0;
    count.textContent = query ? `${visible} ${visible === 1 ? 'input' : 'inputs'} found` : 'All inputs';
  });
})();
