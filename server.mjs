import http from 'node:http';
import {readFile, stat} from 'node:fs/promises';
import path from 'node:path';
const root = process.cwd();
const port = Number(process.env.PORT || 5173);
const mime = {'.html':'text/html; charset=utf-8','.css':'text/css','.js':'text/javascript','.svg':'image/svg+xml','.png':'image/png','.webp':'image/webp','.woff2':'font/woff2','.ttf':'font/ttf','.mp4':'video/mp4','.json':'application/json'};
const server = http.createServer(async (req,res) => {
  try {
    const pathname = decodeURIComponent(new URL(req.url,'http://localhost').pathname);
    const publicFiles = new Set(['/','/index.html','/styles.css','/app.js','/config.js','/release-config.js']);
    if (!publicFiles.has(pathname) && !pathname.startsWith('/assets/')) { res.writeHead(404); return res.end('Not found'); }
    const relative = pathname.startsWith('/assets/') ? '/public'+pathname : pathname;
    const target = path.resolve(root,'.'+(relative === '/' ? '/index.html' : relative));
    if (!target.startsWith(root+path.sep)) {res.writeHead(403);return res.end();}
    if (pathname.startsWith('/assets/') && !target.startsWith(path.join(root,'public','assets')+path.sep)) { res.writeHead(404); return res.end('Not found'); }
    await stat(target);
    res.writeHead(200,{'Content-Type':mime[path.extname(target)] || 'application/octet-stream','Cache-Control':'no-cache'});
    res.end(await readFile(target));
  } catch {res.writeHead(404);res.end('Not found');}
}).listen(port,'127.0.0.1',()=>console.log(`Voca preview: http://localhost:${server.address().port}`));
