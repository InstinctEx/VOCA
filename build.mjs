import {mkdir, copyFile, cp, rm} from 'node:fs/promises';
// Keep each upload free of stale files from earlier builds.
await rm('dist',{recursive:true,force:true});
await mkdir('dist',{recursive:true});
for (const file of ['index.html','styles.css','app.js','config.js','release-config.js']) await copyFile(file,`dist/${file}`);
await cp('public/assets','dist/assets',{recursive:true,filter:source=>!source.endsWith('.png')});
console.log('Static site built in dist/');
