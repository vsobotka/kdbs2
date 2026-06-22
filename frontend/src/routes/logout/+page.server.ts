import { redirect } from '@sveltejs/kit';
import { PUBLIC_BACKEND_URL } from '$env/static/public';
import type { Actions } from './$types';

export const actions: Actions = {
  default: async ({ cookies, fetch }) => {
    const token = cookies.get('session');
    if (token) {
      await fetch(`${PUBLIC_BACKEND_URL}/api/logout`, {
        method: 'POST', headers: { authorization: `Bearer ${token}` },
      });
      cookies.delete('session', { path: '/' });
    }
    throw redirect(303, '/login');
  },
};
