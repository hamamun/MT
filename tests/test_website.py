#!/usr/bin/env python3
"""Check the static guide's input coverage, in-page links and search behavior."""
from html.parser import HTMLParser
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[1]
html = (root / 'docs/index.html').read_text(encoding='utf-8')

class GuideParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.ids = set()
        self.links = []
        self.cards = []
        self.card = None
        self.depth = 0

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            assert attrs['id'] not in self.ids, f"duplicate id {attrs['id']}"
            self.ids.add(attrs['id'])
        if tag == 'a' and 'href' in attrs:
            self.links.append(attrs['href'])
        if self.card is not None:
            self.depth += 1
        elif tag == 'article' and 'data-input' in attrs:
            self.card, self.depth = [], 1

    def handle_endtag(self, tag):
        if self.card is not None:
            self.depth -= 1
            if self.depth == 0:
                self.cards.append(' '.join(self.card))
                self.card = None

    def handle_data(self, data):
        if self.card is not None:
            self.card.append(data)

parser = GuideParser()
parser.feed(html)
assert parser.card is None
for href in parser.links:
    if href.startswith('#'):
        assert href[1:] in parser.ids, f'broken anchor {href}'
for name in ('overview', 'start', 'modes', 'panel', 'inputs', 'execution', 'trailstop', 'diary', 'help'):
    assert name in parser.ids

source = '\n'.join((root / f).read_text(encoding='utf-8') for f in
                   ('MT_CRF_Inputs.mqh', 'MT_PlanRuntime.mqh', 'MT_CRF.mq5'))
inputs = set(re.findall(r'^input(?:\([^\n]*\))?\s+\w+\s+(Inp\w+)\s*=', source, re.M))
covered = [name for card in parser.cards for name in re.findall(r'\bInp\w+\b', card)]
assert set(covered) == inputs, f'missing={inputs-set(covered)}, extra={set(covered)-inputs}'
assert len(covered) == len(inputs), 'each input should have exactly one card'
assert len(inputs) == 27
for asset in ('styles.css', 'script.js'):
    assert (root / 'docs' / asset).is_file() and asset in html
assert 'Auto trading is off by default' in html
assert 'M15 (CRF Excluded)' in html

# Execute the actual search script against a minimal DOM and check the states.
script = r'''
const fs = require('fs'), vm = require('vm');
const search={value:'',addEventListener(_n,fn){this.handle=fn}};
const count={textContent:''}, empty={hidden:true};
const cards=[{textContent:'CRF trailstop',hidden:false},{textContent:'Daily timer',hidden:false}];
const groups=cards.map(card=>({hidden:false,querySelector(){return card.hidden?null:card}}));
const document={querySelector(s){return {'#input-search':search,'#search-count':count,'#no-results':empty}[s]},querySelectorAll(s){return s==='[data-input]'?cards:groups}};
vm.runInNewContext(fs.readFileSync('docs/script.js','utf8'),{document});
function check(b){if(!b)process.exit(1)}
search.value='TRAIL';search.handle();check(!cards[0].hidden && cards[1].hidden && !groups[0].hidden && groups[1].hidden && count.textContent==='1 input found' && empty.hidden);
search.value='missing';search.handle();check(empty.hidden===false && count.textContent==='0 inputs found');
search.value='';search.handle();check(cards.every(c=>!c.hidden) && groups.every(g=>!g.hidden) && empty.hidden && count.textContent==='All inputs');
'''
subprocess.run(['node', '-e', script], cwd=root, check=True)
print('Static guide input coverage, links and search checks passed')
