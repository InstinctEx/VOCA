import http from 'node:http';
import {readFile, stat} from 'node:fs/promises';
import path from 'node:path';
const root = process.cwd();
const port = Number(process.env.PORT || 5173);
const mime = {'.html':'text/html; charset=utf-8','.css':'text/css','.js':'text/javascript','.svg':'image/svg+xml','.png':'image/png','.webp':'image/webp','.woff2':'font/woff2','.ttf':'font/ttf','.mp4':'video/mp4','.json':'application/json'};
http.createServer(async (req,res) => {
  try {
    const pathname = decodeURIComponent(new URL(req.url,'http://localhost').pathname);
    const relative = pathname.startsWith('/assets/') ? '/public'+pathname : pathname;
    const target = path.resolve(root,'.'+(relative === '/' ? '/index.html' : relative));
    if (!target.startsWith(root+path.sep)) {res.writeHead(403);return res.end();}
    await stat(target);
    res.writeHead(200,{'Content-Type':mime[path.extname(target)] || 'application/octet-stream','Cache-Control':'no-cache'});
    res.end(await readFile(target));
  } catch {res.writeHead(404);res.end('Not found');}
}).listen(port,'127.0.0.1',()=>console.log(`Voca preview: http://localhost:${port}`));
