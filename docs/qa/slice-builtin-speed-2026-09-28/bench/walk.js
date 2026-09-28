const fs = require('fs'), path = require('path');
let n = 0;
function walk(d) {
  for (const e of fs.readdirSync(d)) {
    const p = path.join(d, e);
    const s = fs.statSync(p);
    n++;
    if (s.isDirectory()) walk(p);
  }
}
walk(process.argv[2]);
if (n < 1000) process.exit(3);
