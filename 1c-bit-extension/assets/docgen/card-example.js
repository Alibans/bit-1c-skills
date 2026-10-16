// Клиентская карточка «БИТ: Срок действия счёта» (одна страница). Сборка: tools\docgen\make-card.ps1
const fs = require('fs'), path = require('path');
const pngSize = f => { const b = fs.readFileSync(f); return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) }; };

module.exports = ({ para, image, table }) => {
  const ACCENT = 'E2006E', DARK = '1A1A1A', GRAY = '595959', LIGHT = 'F7F2F5';
  const W = 9355;
  const imgDir = process.env.IMG_DIR || path.join(__dirname, 'img');
  const images = [];
  const body = [];

  const h2 = t => para(t, { before: 200, after: 80, keepNext: true }, { b: true, size: 26, color: ACCENT });
  const text = (runs, o = {}) => para(runs, Object.assign({ after: 110 }, o), { color: DARK });
  const lead = t => ({ t, b: true });
  const picture = (file, relId, id, widthShare, caption) => {
    const dim = pngSize(file);
    const cx = Math.round(W * 635 * widthShare), cy = Math.round(cx * dim.h / dim.w);
    images.push({ relId, file });
    body.push(image(relId, cx, cy, id, { before: 60, after: 40, keepNext: false }));
    body.push(para(caption, { after: 40 }, { i: true, size: 18, color: GRAY }));
  };

  // Шапка
  body.push(para('Для «1С:Бухгалтерия для Казахстана», ред. 3.0, локально и в 1С:Фреш', { after: 40 }, { size: 20, color: GRAY }));
  body.push(para('БИТ: Срок действия счёта', { after: 60 }, { b: true, size: 48, color: DARK }));
  body.push(para('Покупатель сразу видит, сколько дней действует счёт.', { after: 160 }, { size: 26, color: ACCENT }));

  // Боль
  body.push(text('Цены и остатки на складе меняются, а покупатель может оплатить счёт, выставленный месяц назад, и ждать отгрузки по старой цене. Чтобы этого не было, менеджеры дописывают срок действия в счёт вручную или напоминают о нём письмом. В спешке об этом легко забыть.'));
  body.push(text('Срок действия счёта решает это одним полем в документе.', { after: 60 }));

  picture(path.join(imgDir, 'print_crop.png'), 'rId201', 11, 0.9, 'Строка о сроке действия в печатной форме счёта');

  // Как работает
  body.push(h2('Как это работает'));
  body.push(text([lead('Одно поле в счёте. '), 'В документе «Счёт на оплату покупателю» появляется поле «Действителен дней». Укажите, например, 5, и в печатной форме под итогами появится строка «Внимание! Счет действителен к оплате в течение 5 (пяти) рабочих дней». Если поле не заполнено, строка не печатается.']));

  // Что это даёт
  body.push(h2('Что это даёт'));
  const cellP = (t, b) => para(t, { after: 0 }, b ? { b: true, size: 22, color: DARK } : { size: 21, color: DARK });
  const cell = (title, t) => ({ content: cellP(title, true) + cellP(t, false), vAlign: 'top' });
  body.push(table([
    [cell('Понятные условия', 'Срок действия написан в самом счёте, цифрами и прописью.'),
     cell('Без ручных правок', 'Не нужно редактировать печатную форму перед отправкой покупателю.')],
    [cell('Свой срок для каждого счёта', 'Срочному заказу три дня, постоянному клиенту десять: как решите.'),
     cell('Ничего не ломает', 'Это расширение: типовая конфигурация не меняется, обновления 1С идут как обычно. Работает и в локальной базе, и в 1С:Фреш.')],
  ], [Math.round(W / 2), W - Math.round(W / 2)], { noBorders: true }));

  // Кому
  body.push(h2('Кому подойдёт'));
  body.push(text('Компаниям, у которых часто меняются цены или наличие товара: оптовой и розничной торговле, дистрибуции, услугам с регулярно пересматриваемым прайсом.', { after: 160 }));

  // Важно знать — ограничения, которые влияют на решение клиента о покупке (1–3 пункта, языком клиента).
  // Пусто — блок не выводится. Пример: 'Срок печатается в форме «Счёт на оплату». В других печатных формах — по отдельной доработке.'
  const limits = [];
  if (limits.length) {
    body.push(h2('Важно знать'));
    for (const l of limits) body.push(text('• ' + l, { after: 60 }));
    body.push(para('', { after: 100 }));
  }

  // Призыв
  body.push(para([lead('Стоимость — 23 896 тг. '), 'Чтобы подключить срок действия счёта или посмотреть его на своей базе, напишите вашему менеджеру Первого БИТа или оставьте заявку на 1bit.kz.'], { shd: LIGHT, after: 0, border: `<w:left w:val="single" w:sz="24" w:space="8" w:color="${ACCENT}"/>` }, { color: DARK }));

  return { body: body.join(''), images, accent: ACCENT, title: 'БИТ: Срок действия счёта' };
};
