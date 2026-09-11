import test from 'node:test';
import assert from 'node:assert/strict';
import { releaseProblems, isPublicHttpsUrl } from '../release-config.js';
const ready = {releaseReady:true,distributionChannel:'unsigned-beta',betaDisclosureAccepted:true,downloadUrl:'https://github.com/InstinctEx/VOCA/releases/download/beta/test.zip',sourceUrl:'https://github.com/InstinctEx/VOCA/archive/test.zip',releaseUrl:'https://github.com/InstinctEx/VOCA/releases/tag/beta'};
test('free release needs no checkout, seller or donation account',()=>assert.deepEqual(releaseProblems(ready),[]));
test('unready releases remain blocked',()=>assert.ok(releaseProblems({...ready,releaseReady:false}).length));
test('binary, source and release notes are required',()=>{for(const key of ['downloadUrl','sourceUrl','releaseUrl']) assert.ok(releaseProblems({...ready,[key]:''}).length)});
test('unsafe URLs are rejected',()=>{for(const url of ['javascript:alert(1)','http://github.com/a','https://user:password@github.com/a','https://example.com','']) assert.equal(isPublicHttpsUrl(url),false)});
test('beta disclosure is required',()=>assert.ok(releaseProblems({...ready,betaDisclosureAccepted:false}).length));
test('donations never gate downloads',()=>{for(const donationUrl of ['', 'https://ko-fi.com/voca', 'javascript:alert(1)']) assert.deepEqual(releaseProblems({...ready,donationUrl}),[])});
test('preview server serves public files but not repository or private files', async () => {
  const {spawn} = await import('node:child_process');
  const child=spawn(process.execPath,['server.mjs'],{env:{...process.env,PORT:'0'},stdio:['ignore','pipe','pipe']});
  try {
    const port=await new Promise((resolve,reject)=>{
      const timeout=setTimeout(()=>reject(Error('Server startup timed out')),5000);
      child.once('error',reject);
      child.stdout.on('data',chunk=>{const match=chunk.toString().match(/localhost:(\d+)/);if(match){clearTimeout(timeout);resolve(match[1]);}});
    });
    for(const file of ['/', '/release-config.js']) assert.equal((await fetch(`http://127.0.0.1:${port}${file}`)).status,200);
    for(const file of ['/.git/config','/.env','/VocaSource/Info.plist','/assets/%2e%2e/%2e%2e/.git/config']) assert.equal((await fetch(`http://127.0.0.1:${port}${file}`)).status,404);
  } finally {child.kill();}
});
