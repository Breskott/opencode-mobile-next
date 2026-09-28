const fs = require('fs');
const dir = '/root/bench/io';
fs.mkdirSync(dir, { recursive: true });
const buf = Buffer.alloc(1024, 97);
for (let i = 0; i < 10000; i++) {
  const p = dir + '/f' + (i % 100);
  fs.writeFileSync(p, buf);
  fs.readFileSync(p);
}
