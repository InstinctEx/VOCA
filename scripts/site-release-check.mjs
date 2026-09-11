import { siteConfig } from '../config.js';
import { releaseProblems } from '../release-config.js';
const problems = releaseProblems(siteConfig);
if (problems.length) { console.error(problems.join('\n')); process.exitCode = 1; }
else console.log('Configuration passed. Verify the published download, matching source, checksums and installation guide.');
