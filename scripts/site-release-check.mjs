import { siteConfig } from '../config.js';
import { releaseProblems } from '../release-config.js';
const problems = releaseProblems(siteConfig);
if (problems.length) { console.error(problems.join('\n')); process.exitCode = 1; }
else console.log('Configuration passed. Verify actual checkout, download, matching source, and refund flow before opening sales.');
