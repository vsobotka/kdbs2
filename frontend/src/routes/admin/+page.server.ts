import { fail, redirect, type Cookies } from '@sveltejs/kit';
import { PUBLIC_BACKEND_URL } from '$env/static/public';
import type { Actions, PageServerLoad } from './$types';

const getUser = async (cookies: Cookies, fetch: typeof globalThis.fetch) => {
  const token = cookies.get('session');
  if (!token) return null;
  const res = await fetch(`${PUBLIC_BACKEND_URL}/api/me`, {
    headers: { authorization: `Bearer ${token}` },
  });
  return res.ok ? await res.json() : null;
};

export const load: PageServerLoad = async ({ cookies, fetch }) => {
  const user = await getUser(cookies, fetch);
  if (!user) throw redirect(303, '/login');
  if (user.role !== 'admin') throw redirect(303, '/');   // non-admins kept out
};

export const actions: Actions = {
  addCommodity: async ({ request, fetch, cookies }) => {
    const token = cookies.get('session');
    if (!token) throw redirect(303, '/login');
    const f = await request.formData();
    const res = await fetch(`${PUBLIC_BACKEND_URL}/api/commodities`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
      body: JSON.stringify({ symbol: f.get('symbol'), name: f.get('name'), unit: f.get('unit') }),
    });
    if (!res.ok) return fail(400, { error: (await res.json()).error });
    return { success: true };
  },
};
