import {mkdir, copyFile, cp} from 'node:fs/promises';
await mkdir('dist',{recursive:true});
for (const file of ['index.html','styles.css','app.js','config.js']) await copyFile(file,`dist/${file}`);
await cp('public/assets','dist/assets',{recursive:true,filter:source=>!source.endsWith('.png')});
console.log('Static site built in dist/');
