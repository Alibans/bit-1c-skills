// node docx-edit.js <dir с распакованным docx> <spec.json>
// spec: { unnum: [idx] — снять автонумерацию, set: {idx: "текст"}, del: [idx], after: {idx: [{like: idx, text}]}, before: {idx: [{like, text}]} }
// Текст абзаца заменяется одним прогоном с форматом первого прогона; новые абзацы клонируют абзац like.
const fs = require('fs'), path = require('path');
const [, , dir, specFile] = process.argv;
const spec = JSON.parse(fs.readFileSync(specFile, 'utf8'));
const docPath = path.join(dir, 'word', 'document.xml');
let x = fs.readFileSync(docPath, 'utf8');
const re = /<w:p[ >][\s\S]*?<\/w:p>/g;
const ps = x.match(re);
const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
function withText(p, text) {
  const pPr = (p.match(/<w:pPr>[\s\S]*?<\/w:pPr>/) || [''])[0];
  const firstRun = p.match(/<w:r[ >][\s\S]*?<\/w:r>/);
  const rPr = firstRun ? ((firstRun[0].match(/<w:rPr>[\s\S]*?<\/w:rPr>/) || [''])[0]) : '';
  const open = p.match(/^<w:p[^>]*>/)[0];
  return `${open}${pPr}<w:r>${rPr}<w:t xml:space="preserve">${esc(text)}</w:t></w:r></w:p>`;
}
const out = ps.map((p, i) => {
  if ((spec.del || []).includes(i)) return '';
  let cur = spec.set && spec.set[i] !== undefined ? withText(p, spec.set[i]) : p;
  if ((spec.unnum || []).includes(i)) cur = cur.replace(/<w:numPr>[\s\S]*?<\/w:numPr>/, '');
  const bef = ((spec.before || {})[i] || []).map(n => withText(ps[n.like], n.text)).join('');
  const aft = ((spec.after || {})[i] || []).map(n => withText(ps[n.like], n.text)).join('');
  return bef + cur + aft;
});
let k = 0;
x = x.replace(re, () => out[k++]);
fs.writeFileSync(docPath, x);
console.log('абзацев было', ps.length);
