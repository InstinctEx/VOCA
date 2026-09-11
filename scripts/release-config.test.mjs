import test from 'node:test';
import assert from 'node:assert/strict';
import { releaseProblems } from '../release-config.js';
const ready = {releaseReady:true, distributionChannel:'unsigned-beta', betaDisclosureAccepted:true, lifetimePrice:5, sellerName:'Test seller',supportEmail:'support@voca.test',checkoutUrl:'https://pay.voca.test/buy',downloadUrl:'https://download.voca.test/app.zip',sourceUrl:'https://download.voca.test/source.zip',termsUrl:'https://voca.test/terms'};
test('complete beta configuration passes',()=>assert.deepEqual(releaseProblems(ready),[]));
test('preview never opens sales',()=>assert.ok(releaseProblems({...ready,releaseReady:false}).length));
test('source delivery and terms cannot be omitted',()=>{for(const key of ['sourceUrl','termsUrl'])assert.ok(releaseProblems({...ready,[key]:''}).length)});
test('reject executable, insecure and credential-bearing links',()=>{for(const checkoutUrl of ['javascript:alert(1)','http://pay.voca.test','https://user:password@pay.voca.test','https://example.com'])assert.ok(releaseProblems({...ready,checkoutUrl}).length)});
test('unsigned beta needs an explicit disclosure decision',()=>assert.ok(releaseProblems({...ready,betaDisclosureAccepted:false}).length));

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
