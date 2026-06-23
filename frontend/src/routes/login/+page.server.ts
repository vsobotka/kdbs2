import { fail, redirect } from '@sveltejs/kit';
import { PUBLIC_BACKEND_URL } from '$env/static/public';
import type { Actions } from './$types';

export const actions: Actions = {
  default: async ({ request, fetch, cookies }) => {
    const data = await request.formData();
    const res = await fetch(`${PUBLIC_BACKEND_URL}/api/login`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ username: data.get('username'), password: data.get('password') }),
    });
    if (!res.ok) return fail(401, { error: 'Invalid username or password' });

    const { token, expiresAt } = await res.json();
    cookies.set('session', token, {
      httpOnly: true,            // JS can't read it → safe from XSS theft
      sameSite: 'lax',
      path: '/',
      secure: false,             // true in production (HTTPS only)
      expires: new Date(expiresAt),
    });
    throw redirect(303, '/');
  },
};

