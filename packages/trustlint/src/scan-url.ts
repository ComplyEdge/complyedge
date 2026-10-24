/**
 * The hosted check for an API key's region: ce_eu_ is EU, ce_ is US, else EU.
 * Same rule as @complyedge/sdk; an account's key only works on its region's host.
 */
export function scanUrl(apiKey: string): string {
  if (apiKey.startsWith("ce_") && !apiKey.startsWith("ce_eu_")) {
    return "https://api.complyedge.io/v1/check";
  }
  return "https://eu.api.complyedge.io/v1/check";
}
