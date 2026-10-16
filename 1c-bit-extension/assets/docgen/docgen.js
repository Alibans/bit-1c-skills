// Генератор docx на фирменном бланке: берёт распакованный шаблон, подставляет тело документа.
// usage: node docgen.js <templateDir> <outDocx> <contentModule.js>
const fs = require('fs'), path = require('path'), cp = require('child_process');
const [,, tplDir, outDocx, contentFile] = process.argv;
const esc = s => String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
const FONT = '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>';
function rpr(o={}) {
  let r = FONT;
  if (o.b) r += '<w:b/><w:bCs/>';
  if (o.i) r += '<w:i/><w:iCs/>';
  if (o.color) r += `<w:color w:val="${o.color}"/>`;
  if (o.size) r += `<w:sz w:val="${o.size}"/><w:szCs w:val="${o.size}"/>`;
  if (o.caps) r += '<w:caps/>';
  if (o.spacing) r += `<w:spacing w:val="${o.spacing}"/>`;
  return `<w:rPr>${r}</w:rPr>`;
}
function run(text, o={}) {
  if (Array.isArray(text)) return text.map(t => typeof t === 'string' ? run(t, o) : run(t.t, Object.assign({}, o, t))).join('');
  return `<w:r>${rpr(o)}<w:t xml:space="preserve">${esc(text)}</w:t></w:r>`;
}
function ppr(o={}) {
  let p = '';
  if (o.keepNext) p += '<w:keepNext/>';
  if (o.keepLines) p += '<w:keepLines/>';
  if (o.pageBreakBefore) p += '<w:pageBreakBefore/>';
  if (o.numId != null) p += `<w:numPr><w:ilvl w:val="${o.ilvl||0}"/><w:numId w:val="${o.numId}"/></w:numPr>`;
  if (o.border) p += `<w:pBdr>${o.border}</w:pBdr>`;
  if (o.shd) p += `<w:shd w:val="clear" w:color="auto" w:fill="${o.shd}"/>`;
  p += `<w:spacing w:before="${o.before||0}" w:after="${o.after==null?120:o.after}" w:line="${o.line||264}" w:lineRule="auto"/>`;
  if (o.ind) p += `<w:ind ${o.ind}/>`;
  if (o.align) p += `<w:jc w:val="${o.align}"/>`;
  return `<w:pPr>${p}</w:pPr>`;
}
function para(runs, o={}, ro={}) { return `<w:p>${ppr(o)}${run(runs, Object.assign({size:22}, ro))}</w:p>`; }
function emptyPara(after=0) { return `<w:p>${ppr({after, line:240})}</w:p>`; }
function image(relId, cx, cy, id, o={}) {
  return `<w:p>${ppr(Object.assign({after:60, before:60, keepNext:true}, o))}<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="${cx}" cy="${cy}"/><wp:effectExtent l="0" t="0" r="0" b="0"/><wp:docPr id="${id}" name="Picture ${id}"/><wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/></wp:cNvGraphicFramePr><a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:nvPicPr><pic:cNvPr id="${id}" name="Picture ${id}"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="${relId}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="${cx}" cy="${cy}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:ln w="6350"><a:solidFill><a:srgbClr val="D9D9D9"/></a:solidFill></a:ln></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>`;
}
function cell(content, w, o={}) {
  let pr = `<w:tcW w:w="${w}" w:type="dxa"/>`;
  if (o.shd) pr += `<w:shd w:val="clear" w:color="auto" w:fill="${o.shd}"/>`;
  pr += `<w:tcMar><w:top w:w="70" w:type="dxa"/><w:left w:w="110" w:type="dxa"/><w:bottom w:w="70" w:type="dxa"/><w:right w:w="110" w:type="dxa"/></w:tcMar>`;
  if (o.vAlign) pr += `<w:vAlign w:val="${o.vAlign}"/>`;
  return `<w:tc><w:tcPr>${pr}</w:tcPr>${content}</w:tc>`;
}
function table(rows, widths, o={}) {
  const total = widths.reduce((a,b)=>a+b,0);
  const bc = o.borderColor || 'D9D9D9';
  const borders = o.noBorders ? '<w:tblBorders><w:top w:val="nil"/><w:left w:val="nil"/><w:bottom w:val="nil"/><w:right w:val="nil"/><w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders>'
    : `<w:tblBorders><w:top w:val="single" w:sz="4" w:color="${bc}"/><w:left w:val="nil"/><w:bottom w:val="single" w:sz="4" w:color="${bc}"/><w:right w:val="nil"/><w:insideH w:val="single" w:sz="4" w:color="${bc}"/><w:insideV w:val="nil"/></w:tblBorders>`;
  let t = `<w:tbl><w:tblPr><w:tblW w:w="${total}" w:type="dxa"/>${borders}<w:tblLayout w:type="fixed"/><w:tblLook w:val="0000"/></w:tblPr><w:tblGrid>${widths.map(w=>`<w:gridCol w:w="${w}"/>`).join('')}</w:tblGrid>`;
  for (const r of rows) {
    t += `<w:tr><w:trPr><w:cantSplit/></w:trPr>${r.map((c,i)=>cell(c.content, widths[i], c)).join('')}</w:tr>`;
  }
  return t + '</w:tbl>';
}
const api = { esc, run, para, emptyPara, image, table, cell, ppr, rpr };
const content = require(path.resolve(contentFile))(api);
// --- assemble ---
const work = outDocx + '.dir';
fs.rmSync(work, { recursive: true, force: true });
fs.cpSync(tplDir, work, { recursive: true });
const docPath = path.join(work, 'word/document.xml');
let doc = fs.readFileSync(docPath, 'utf8');
const bodyStart = doc.indexOf('<w:body>') + '<w:body>'.length;
const sectStart = doc.indexOf('<w:sectPr');
doc = doc.slice(0, bodyStart) + content.body + doc.slice(sectStart);
fs.writeFileSync(docPath, doc);
// numbering
const accent = content.accent || 'E4007C';
const numbering = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="hybridMultilevel"/><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="&#8226;"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="567" w:hanging="283"/></w:pPr><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:hint="default"/><w:color w:val="${accent}"/></w:rPr></w:lvl></w:abstractNum><w:abstractNum w:abstractNumId="1"><w:multiLevelType w:val="hybridMultilevel"/><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="567" w:hanging="283"/></w:pPr><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:hint="default"/><w:b/><w:color w:val="${accent}"/></w:rPr></w:lvl></w:abstractNum><w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num><w:num w:numId="2"><w:abstractNumId w:val="1"/></w:num></w:numbering>`;
fs.writeFileSync(path.join(work, 'word/numbering.xml'), numbering);
// rels + media
const relsPath = path.join(work, 'word/_rels/document.xml.rels');
let rels = fs.readFileSync(relsPath, 'utf8');
let extra = '<Relationship Id="rId100" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>';
(content.images || []).forEach((img, i) => {
  const name = `img${i+1}${path.extname(img.file)}`;
  fs.copyFileSync(img.file, path.join(work, 'word/media', name));
  extra += `<Relationship Id="${img.relId}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/${name}"/>`;
});
rels = rels.replace('</Relationships>', extra + '</Relationships>');
fs.writeFileSync(relsPath, rels);
const ctPath = path.join(work, '[Content_Types].xml');
let ct = fs.readFileSync(ctPath, 'utf8');
ct = ct.replace('</Types>', '<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/></Types>');
fs.writeFileSync(ctPath, ct);
// docProps title
const corePath = path.join(work, 'docProps/core.xml');
if (fs.existsSync(corePath) && content.title) {
  let core = fs.readFileSync(corePath, 'utf8');
  core = core.replace(/<dc:title>[^<]*<\/dc:title>/, '').replace(/<dc:creator>[^<]*<\/dc:creator>/, '<dc:creator>Первый БИТ</dc:creator>');
  core = core.replace('</cp:coreProperties>', `<dc:title>${esc(content.title)}</dc:title></cp:coreProperties>`);
  fs.writeFileSync(corePath, core);
}
// zip
fs.rmSync(outDocx, { force: true });
cp.execFileSync('C:\\Program Files\\7-Zip\\7z.exe', ['a', '-tzip', '-mx=5', outDocx, '.'], { cwd: work, stdio: 'pipe' });
console.log('written', outDocx);
