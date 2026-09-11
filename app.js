import { siteConfig } from './config.js';
import { releaseProblems } from './release-config.js';
const salesEnabled = releaseProblems(siteConfig).length === 0;

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const formatPrice = new Intl.NumberFormat('en-IE', {style:'currency',currency:siteConfig.currency,maximumFractionDigits:0});
$$('[data-price]').forEach(el => { el.textContent = formatPrice.format(siteConfig.lifetimePrice); });
$('#year').textContent = new Date().getFullYear();

// A flat, recognisable voice mark is repeated in the product UI, not a stock mic.
$$('.waveform').forEach(wave => {
  [7,13,19,10,24,16,9,18,12].forEach((height,index) => {
    const bar=document.createElement('i');
    bar.style.setProperty('--height',`${height}px`);
    bar.style.setProperty('--delay',`${index * -0.12}s`);
    wave.append(bar);
  });
});
const apple = $('.apple-svg').outerHTML;
$$('.apple,.mac-apple').forEach(el => {el.innerHTML=apple;});

const menu=$('.menu-toggle');
const closeMenu=()=>{$('.nav-shell').classList.remove('menu-open');menu.setAttribute('aria-expanded','false');menu.setAttribute('aria-label','Open menu');};
menu.addEventListener('click',()=>{
  const open=$('.nav-shell').classList.toggle('menu-open');
  menu.setAttribute('aria-expanded',String(open));menu.setAttribute('aria-label',open?'Close menu':'Open menu');
});
$$('.nav-shell a').forEach(a=>a.addEventListener('click',closeMenu));
document.addEventListener('keydown',e=>{if(e.key==='Escape')closeMenu();});
document.addEventListener('click',e=>{if(!e.target.closest('.nav-shell'))closeMenu();});

let isPaused=reducedMotion.matches;
const motionButton=$('.motion-toggle');
function setMotion(paused){isPaused=paused;document.body.classList.toggle('motion-paused',paused);motionButton.setAttribute('aria-pressed',String(paused));motionButton.innerHTML=paused?'Resume scenery <span>▶</span>':'Pause scenery <span>Ⅱ</span>';}
setMotion(isPaused);
motionButton.addEventListener('click',()=>setMotion(!isPaused));
reducedMotion.addEventListener('change',e=>setMotion(e.matches));

// Fixed-size foliage. Only the soft mask moves; plants never grow or scale.
// Map client coordinates through each rock's CSS transform, including mirroring.
const rocks=$$('.rock');
let revealFrame=0, lastPointer=null;
function hideFoliage(){lastPointer=null;rocks.forEach(rock=>rock.style.setProperty('--reveal','0'));}
function updateFoliage(){
  revealFrame=0;
  if(!lastPointer)return;
  for(const rock of rocks){
    const rect=rock.getBoundingClientRect();
    const near=lastPointer.x>rect.left-50&&lastPointer.x<rect.right+50&&lastPointer.y>rect.top&&lastPointer.y<rect.bottom;
    if(!near){rock.style.setProperty('--reveal','0');continue;}
    const style=getComputedStyle(rock), matrix=new DOMMatrix(style.transform==='none'?undefined:style.transform);
    const centerX=rect.left+rect.width/2,centerY=rect.top+rect.height/2;
    const point=new DOMPoint(lastPointer.x-centerX,lastPointer.y-centerY).matrixTransform(matrix.inverse());
    rock.style.setProperty('--mx',`${point.x+rock.offsetWidth/2}px`);
    rock.style.setProperty('--my',`${point.y+rock.offsetHeight/2}px`);
    rock.style.setProperty('--reveal','1');
  }
}
$('.hero').addEventListener('pointermove',event=>{
  if(event.pointerType==='touch')return;
  lastPointer={x:event.clientX,y:event.clientY};
  if(!revealFrame)revealFrame=requestAnimationFrame(updateFoliage);
});
$('.hero').addEventListener('pointerleave',hideFoliage);
window.addEventListener('blur',hideFoliage);
window.addEventListener('scroll',hideFoliage,{passive:true});

// Deterministic, microphone-free product walkthrough. No fake speech recognition.
const raw='“Hey Alex, um, let’s take the meeting outside. I think, uh, our best ideas could use a little fresh air.”';
const clean='Hey Alex, let’s take the meeting outside. I think our best ideas could use a little fresh air.';
let demoTimers=[], demoStep=0, demoPlaying=false;
function stopDemo(){demoTimers.forEach(clearTimeout);demoTimers=[];demoPlaying=false;$('.replay-demo').textContent='↻ Play the walkthrough';}
function selectStep(index){
  demoStep=index;
  $$('.step').forEach((step,i)=>{step.classList.toggle('active',i===index);step.setAttribute('aria-selected',String(i===index));step.tabIndex=i===index?0:-1;});
  $('#demo-panel').setAttribute('aria-labelledby',`step-${index}`);
  $('#demo-label').textContent=['You say','Voca tidies up','Ready to send'][index];
  if(index===1){$('#demo-text').innerHTML='“Hey Alex, <mark>um,</mark> let’s take the meeting outside. I think, <mark>uh,</mark> our best ideas could use a little fresh air.”';}
  else $('#demo-text').textContent=index===0?raw:clean;
  $('#demo-status').textContent=['Listening','Polishing','Written ✓'][index];
  $('#demo-hint').textContent=['Use your dictation shortcut','Your meaning stays yours','Finish. Review. Send when ready.'][index];
  $('.mini-pill').classList.toggle('listening',index===0 && demoPlaying);
}
function playDemo(){
  if(demoPlaying){stopDemo();selectStep(demoStep);return;}
  stopDemo();demoPlaying=true;selectStep(0);$('.replay-demo').textContent='Ⅱ Pause the walkthrough';
  demoTimers.push(setTimeout(()=>selectStep(1),2400),setTimeout(()=>selectStep(2),4700),setTimeout(()=>{stopDemo();selectStep(2);$('.replay-demo').textContent='↻ Replay the walkthrough';},6500));
}
$$('.step').forEach((step,index)=>{
  step.addEventListener('click',()=>{stopDemo();selectStep(index);});
  step.addEventListener('keydown',event=>{
    let next=index;
    if(event.key==='ArrowRight'||event.key==='ArrowDown')next=(index+1)%3;
    else if(event.key==='ArrowLeft'||event.key==='ArrowUp')next=(index+2)%3;
    else if(event.key==='Home')next=0;
    else if(event.key==='End')next=2;
    else return;
    event.preventDefault();stopDemo();selectStep(next);$$('.step')[next].focus();
  });
});
$('.replay-demo').addEventListener('click',playDemo);
selectStep(0);

let heroTimers=[],heroRunning=false;
const heroPill=$('#hero-pill');
const heroText=$('#hero-transcript');
const originalHeroText=heroText.innerHTML;
function finishHero(){heroRunning=false;heroPill.classList.remove('is-speaking');heroPill.setAttribute('aria-label','Replay dictation demo');$('.pill-label').textContent='Written. Just like that.';heroText.innerHTML=originalHeroText;}
heroPill.addEventListener('click',()=>{
  if(heroRunning)return;
  heroTimers.forEach(clearTimeout);heroRunning=true;heroPill.classList.add('is-speaking');heroPill.setAttribute('aria-label','Dictation demo playing');$('.pill-label').textContent='Listening to you…';
  const text='Hey Alex, let’s take the meeting outside. I think our best ideas could use a little fresh air.';
  heroText.textContent='';
  const words=text.split(' ');
  words.forEach((word,i)=>heroTimers.push(setTimeout(()=>{heroText.textContent=words.slice(0,i+1).join(' ');}, reducedMotion.matches?0:i*100)));
  heroTimers.push(setTimeout(()=>{heroPill.classList.remove('is-speaking');$('.pill-label').textContent='A little polish…';},reducedMotion.matches?350:2500));
  heroTimers.push(setTimeout(finishHero,reducedMotion.matches?600:3200));
});

// Native dialogs provide focus trapping, Escape dismissal, and focus restoration.
$$('dialog').forEach(dialog=>{
  dialog.querySelector('.close-dialog').addEventListener('click',()=>dialog.close());
  dialog.addEventListener('click',event=>{const r=dialog.getBoundingClientRect();if(event.target===dialog && (event.clientX<r.left||event.clientX>r.right||event.clientY<r.top||event.clientY>r.bottom))dialog.close();});
});
const videoDialog=$('#video-dialog');
$('.watch-button').addEventListener('click',()=>{
  if(siteConfig.walkthroughVideoUrl && !videoDialog.querySelector('video')){
    const video=document.createElement('video');video.controls=true;video.playsInline=true;video.src=siteConfig.walkthroughVideoUrl;video.poster='/assets/landscape.webp';
    $('.video-placeholder').replaceWith(video);
  }
  videoDialog.showModal();
});
videoDialog.addEventListener('close',()=>videoDialog.querySelector('video')?.pause());
$('#open-interactive').addEventListener('click',()=>{
  videoDialog.close();$('#how-it-works').scrollIntoView({behavior:reducedMotion.matches?'instant':'smooth'});stopDemo();playDemo();
});
function showInfo(title,message){$('#info-title').textContent=title;$('#info-text').textContent=message;$('#info-dialog').showModal();}
$('#info-done').addEventListener('click',()=>$('#info-dialog').close());
$('.purchase-button').addEventListener('click',()=>{
  if(salesEnabled){window.location.assign(siteConfig.checkoutUrl);return;}
  showInfo('A little more headspace is on its way.','VOCA’s source is public and free to build. The €5 prebuilt beta includes all local features. This beta is not Apple-notarized and may need manual approval in macOS Privacy & Security. Purchases open after download, source delivery, and seller details are verified. Optional AI API costs are separate.');
});
if(salesEnabled){
  $('.price-description').textContent = 'All local features are included. This beta is locally signed, not Apple-notarized; macOS may require manual approval in Privacy & Security. Read the purchase terms before buying.';
  $('#purchase-faq p').textContent = 'The price covers this prebuilt beta with all local features. Optional cloud AI usage is billed separately by your provider. See the purchase terms for support and upgrade details.';
  $('#availability-faq p').textContent = 'The prebuilt beta is available through checkout. It is not Apple-notarized and may require manual approval in Privacy & Security. Apple Silicon and macOS 15+ are required; Liquid Glass requires macOS 26. The source is also free to build.';
  $('.purchase-button').textContent = `Buy the beta · ${formatPrice.format(siteConfig.lifetimePrice)} ↗`;
  $('.purchase-caption').textContent = siteConfig.deliveryMode === 'hosted-checkout' ? 'Secure checkout and file delivery through the store. Your receipt includes download access.' : 'One-time beta download. Optional API usage is billed separately.';
  if (siteConfig.deliveryMode !== 'hosted-checkout') {
    const link=document.createElement('a');link.href=siteConfig.downloadUrl;link.className='download-link';link.textContent='Already own Voca? Download for Mac';$('.price-card').append(link);
  }
  for (const [label, url] of [['Matching source (GPLv3)', siteConfig.sourceUrl], ['Purchase terms', siteConfig.termsUrl]]) { const a=document.createElement('a');a.href=url;a.className='download-link';a.textContent=label;$('.price-card').append(a); }
}
$$('[data-info]').forEach(button=>button.addEventListener('click',()=>{
  if(button.dataset.info==='privacy')showInfo('Your privacy, here.','This page doesn’t use your microphone, store your dictation, or run analytics. The demos use sample text. Details about the Mac app’s data handling will be provided with its release.');
  else if(siteConfig.supportEmail)window.location.href=`mailto:${siteConfig.supportEmail}`;
  else showInfo('Say hello.','Our support contact will be available here when Voca launches. In the meantime, explore the walkthrough to get a feel for the app.');
}));
document.addEventListener('visibilitychange',()=>{if(document.hidden){hideFoliage();stopDemo();heroTimers.forEach(clearTimeout);if(heroRunning)finishHero();}});
