import type { PageLoad } from './$types';
import { PUBLIC_BACKEND_URL } from '$env/static/public';

export const load: PageLoad = async ({ fetch }) => {
  // Absolute URL: this load also runs on the SvelteKit server (SSR / hard
  // refresh), where a relative /api URL does NOT go through the Vite proxy.
  const res = await fetch(`${PUBLIC_BACKEND_URL}/api/commodities`);
  const commodities = await res.json();
  return { commodities };
};
