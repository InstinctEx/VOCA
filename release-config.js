export function isPublicHttpsUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && !url.username && !url.password && url.hostname.includes('.') && !/(^|\.)(localhost|example\.(com|org|net))$/.test(url.hostname);
  } catch { return false; }
}

// Free distribution needs actual binary/source links, not a checkout account.
export function releaseProblems(config) {
  const problems = [];
  if (!config.releaseReady) problems.push('Preview mode is enabled.');
  if (!['unsigned-beta', 'notarized'].includes(config.distributionChannel)) problems.push('Choose a distribution channel.');
  for (const key of ['downloadUrl', 'sourceUrl', 'releaseUrl']) {
    if (!isPublicHttpsUrl(config[key])) problems.push(`${key} must be a real public HTTPS URL.`);
  }
  if (config.distributionChannel === 'unsigned-beta' && !config.betaDisclosureAccepted) problems.push('Confirm the unnotarized-beta disclosure before enabling downloads.');
  return problems;
}
