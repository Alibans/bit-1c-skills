// Внутреннее описание решения (Word) по шаблону Первого БИТа: 16 разделов, оформление и стили — из образца
// assets/docs/Пример внутреннего описания.docx (заголовок, разделы, абзацы, маркированный список, картинки).
//
// usage: node make-description.js <spec.json> <out.docx>
// spec.json:
// {
//   "title": "Расширение «Контроль цен»",
//   "sections": {                       // ключи — номера разделов 1..16; все 16 обязательны
//     "1": ["Абзац текста.", "Ещё абзац."],
//     "2": ["Решение позволяет:", "- пункт списка;", "- последний пункт."],
//     "7": ["### 7.1. Отчёт «…»", "Абзац", "- пункт"],    // ### — подзаголовок
//     "11": [{ "caption": "Список документов с колонками:", "image": "img/list.png" }]
//   }
// }
// Пути к картинкам — относительно spec.json. Нужен 7-Zip (C:\Program Files\7-Zip\7z.exe).
const fs = require('fs'), path = require('path'), cp = require('child_process'), os = require('os');
const [, , specFile, outDocx] = process.argv;
const SEVEN = 'C:\\Program Files\\7-Zip\\7z.exe';
const HEADINGS = ['Назначение решения', 'Какие задачи решает решение', 'Для кого подходит решение', 'Тип решения',
  'Для каких конфигураций подходит', 'Принцип работы', 'Функциональные возможности', 'Преимущества решения',
  'Условия сопровождения', 'Ограничения решения', 'Скриншоты расширения', 'Демо видео', 'Стоимость (в тг)',
  'Стоимость (в часах)', 'Ответственное лицо за решение', 'Офис'];

const spec = JSON.parse(fs.readFileSync(specFile, 'utf8').replace(/^\uFEFF/, ''));
const specDir = path.dirname(path.resolve(specFile));
for (let i = 1; i <= 16; i++) if (!spec.sections || !spec.sections[i]) throw new Error(`Нет раздела ${i}. ${HEADINGS[i - 1]}`);

const work = fs.mkdtempSync(path.join(os.tmpdir(), 'bitdesc-'));
cp.execFileSync(SEVEN, ['x', '-y', path.join(__dirname, '..', 'docs', 'Пример внутреннего описания.docx'), `-o${work}`], { stdio: 'pipe' });
const docPath = path.join(work, 'word', 'document.xml');
let doc = fs.readFileSync(docPath, 'utf8');
const paras = doc.match(/<w:p[ >][\s\S]*?<\/w:p>/g);
const style = p => (p.match(/<w:pStyle w:val="([^"]+)"/) || [])[1];
const pick = (f, what) => { const p = paras.find(f); if (!p) throw new Error('В образце нет: ' + what); return p; };
const T = {
  title: paras[0],
  head: pick(p => style(p) === '21', 'заголовок раздела'),
  text: pick(p => !style(p) && !p.includes('<w:numPr>') && !p.includes('<w:drawing') && /<w:t[ >]/.test(p), 'абзац'),
  bullet: pick(p => p.includes('<w:numPr>'), 'пункт списка'),
  image: pick(p => p.includes('<w:drawing'), 'картинка'),
};
const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
function withText(p, text) {
  const pPr = (p.match(/<w:pPr>[\s\S]*?<\/w:pPr>/) || [''])[0];
  const run = p.match(/<w:r[ >][\s\S]*?<\/w:r>/);
  const rPr = run ? ((run[0].match(/<w:rPr>[\s\S]*?<\/w:rPr>/) || [''])[0]) : '';
  return `${p.match(/^<w:p[^>]*>/)[0]}${pPr}<w:r>${rPr}<w:t xml:space="preserve">${esc(text)}</w:t></w:r></w:p>`;
}

// картинки
const relsPath = path.join(work, 'word', '_rels', 'document.xml.rels');
let rels = fs.readFileSync(relsPath, 'utf8');
for (const old of [...rels.matchAll(/<Relationship [^>]*Target="media\/[^"]+"[^>]*\/>/g)]) rels = rels.replace(old[0], '');
for (const f of fs.readdirSync(path.join(work, 'word', 'media'))) fs.unlinkSync(path.join(work, 'word', 'media', f));
const maxCx = +(T.image.match(/<wp:extent cx="(\d+)"/) || [0, 5940425])[1];
let imgNo = 0;
function imagePara(file) {
  imgNo++;
  const src = path.resolve(specDir, file);
  const b = fs.readFileSync(src);
  if (b.readUInt32BE(0) !== 0x89504E47) throw new Error('Нужен PNG: ' + src);
  const w = b.readUInt32BE(16), h = b.readUInt32BE(20);
  const cx = Math.min(maxCx, w * 9525), cy = Math.round(cx * h / w);
  const id = `rIdBit${imgNo}`, name = `bit${imgNo}.png`;
  fs.copyFileSync(src, path.join(work, 'word', 'media', name));
  rels = rels.replace('</Relationships>', `<Relationship Id="${id}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/${name}"/></Relationships>`);
  return T.image.replace(/r:embed="[^"]+"/, `r:embed="${id}"`)
    .replace(/(<wp:extent )cx="\d+" cy="\d+"/, `$1cx="${cx}" cy="${cy}"`)
    .replace(/(<a:ext )cx="\d+" cy="\d+"/, `$1cx="${cx}" cy="${cy}"`)
    .replace(/(<wp:docPr id=")\d+/, `$1${100 + imgNo}`)
    .replace(/(<pic:cNvPr id=")\d+/, `$1${100 + imgNo}`);
}

const body = [withText(T.title, spec.title)];
for (let i = 1; i <= 16; i++) {
  body.push(withText(T.head, `${i}. ${HEADINGS[i - 1]}`));
  for (const item of [].concat(spec.sections[i])) {
    if (typeof item === 'object') {
      if (item.caption) body.push(withText(T.text, item.caption));
      if (item.image) body.push(imagePara(item.image));
    } else if (item.startsWith('### ')) body.push(withText(T.head, item.slice(4)));
    else if (item.startsWith('- ')) body.push(withText(T.bullet, item.slice(2)));
    else body.push(withText(T.text, item));
  }
}
const bStart = doc.indexOf('<w:body>') + '<w:body>'.length, sect = doc.lastIndexOf('<w:sectPr');
doc = doc.slice(0, bStart) + body.join('') + doc.slice(sect);
fs.writeFileSync(docPath, doc);
// свойства файла: автор — Первый БИТ, без имён сотрудников из образца
const corePath = path.join(work, 'docProps', 'core.xml');
if (fs.existsSync(corePath)) {
  let core = fs.readFileSync(corePath, 'utf8');
  core = core.replace(/<dc:creator>[^<]*<\/dc:creator>/, '<dc:creator>Первый БИТ</dc:creator>')
    .replace(/<cp:lastModifiedBy>[^<]*<\/cp:lastModifiedBy>/, '<cp:lastModifiedBy>Первый БИТ</cp:lastModifiedBy>')
    .replace(/<dc:title>[^<]*<\/dc:title>/, '')
    .replace('</cp:coreProperties>', '<dc:title>' + esc(spec.title) + '</dc:title></cp:coreProperties>');
  fs.writeFileSync(corePath, core);
}
fs.writeFileSync(relsPath, rels);
const out = path.resolve(outDocx);
fs.rmSync(out, { force: true });
cp.execFileSync(SEVEN, ['a', '-tzip', '-mx=5', out, '.'], { cwd: work, stdio: 'pipe' });
fs.rmSync(work, { recursive: true, force: true });
console.log('written', out, `(картинок: ${imgNo})`);
