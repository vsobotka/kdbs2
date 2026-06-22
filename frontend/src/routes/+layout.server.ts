import { PUBLIC_BACKEND_URL } from '$env/static/public';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ cookies, fetch }) => {
  const token = cookies.get('session');
  if (!token) return { user: null };
  const res = await fetch(`${PUBLIC_BACKEND_URL}/api/me`, {
    headers: { authorization: `Bearer ${token}` },
  });
  return { user: res.ok ? await res.json() : null };   // shared with every page
};
