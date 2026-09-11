import { siteConfig } from '../config.js';
const problems = [];
if (!siteConfig.releaseReady) problems.push('The site is in preview mode.');
for (const key of ['checkoutUrl', 'downloadUrl']) {
  try { if (new URL(siteConfig[key]).protocol !== 'https:') throw Error(); }
  catch { problems.push(`${key} must be a configured HTTPS URL.`); }
}
if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(siteConfig.supportEmail)) problems.push('An owned support email is required.');
if (problems.length) { console.error(problems.join('\n')); process.exitCode = 1; }
else console.log('Site configuration checks passed. Verify seller terms, privacy, source delivery, refund flow, and real checkout before publishing sales.');
