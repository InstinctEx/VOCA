// Shared by the browser and the CLI; preview copy must never enable a sale alone.
export function releaseProblems(config) {
  const problems = [];
  if (!config.releaseReady) problems.push('Preview mode is enabled.');
  if (!['unsigned-beta', 'notarized'].includes(config.distributionChannel)) problems.push('Choose a distribution channel.');
  for (const key of ['checkoutUrl', 'downloadUrl', 'sourceUrl', 'termsUrl']) {
    try {
      const url = new URL(config[key]);
      if (url.protocol !== 'https:' || url.username || url.password || !url.hostname.includes('.') || /(^|\.)(localhost|example\.(com|org|net))$/.test(url.hostname)) throw Error();
    } catch { problems.push(`${key} must be a real public HTTPS URL.`); }
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(config.supportEmail ?? '')) problems.push('A support email is required.');
  if (!config.sellerName?.trim()) problems.push('A public seller name is required.');
  if (!Number.isFinite(config.lifetimePrice) || config.lifetimePrice <= 0) problems.push('Set a valid price.');
  if (config.distributionChannel === 'unsigned-beta' && !config.betaDisclosureAccepted) problems.push('Confirm the unsigned-beta disclosure before opening sales.');
  return problems;
}
