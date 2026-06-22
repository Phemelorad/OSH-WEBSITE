const path = require('path');
const fs = require('fs');
const c = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
let tags = [];
let i = 0;
while ((i = c.indexOf('<script', i)) !== -1) {
  let close = c.indexOf('</script>', i);
  let isExternal = c.substring(i, i + 80).includes('src=');
  let src = isExternal ? (c.substring(i, i + 80).match(/src="(.*?)"/) || [, ''])[1] : 'INLINE';
  let line = c.substring(0, i).split('\n').length;
  tags.push({ start: i, end: close + 9, src, line });
  i = close + 9;
}
for (const t of tags) {
  const content = c.substring(t.start, t.end);
  const haslogin = content.includes('showLoginBanner');
  console.log(`Script at line ${t.line}: ${t.src.substring(0, 60)} [has showLoginBanner: ${haslogin ? 'YES' : 'no'}, length=${content.length}]`);
}
