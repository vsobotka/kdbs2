
import { fail } from '@sveltejs/kit';
import { PUBLIC_BACKEND_URL } from '$env/static/public';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ fetch, cookies }) => {
  const token = cookies.get('session');
  const transactions = await (await fetch(`${PUBLIC_BACKEND_URL}/api/transactions`, {
    headers: { authorization: `Bearer ${token}` },
  })).json();
  console.log(transactions)
  return { transactions };
};

export const actions: Actions = {
  deposit: async ({ request, fetch, cookies }) => {
    const token = cookies.get('session');
    const data = await request.formData();
    const amount = Number(data.get('amount'));

    if (amount <= 0) return fail(400, { error: 'Deposit must be greater than 0' });

    const res = await fetch(`${PUBLIC_BACKEND_URL}/api/deposit`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
      body: JSON.stringify({ amount }),
    });
    if (!res.ok) return fail(400, { error: (await res.json()).error });
    return { success: true };
  },
  withdraw: async ({ request, fetch, cookies }) => {
    const token = cookies.get('session');
    const data = await request.formData();
    const amount = Number(data.get('amount'));

    if (amount <= 0) return fail(400, { error: 'Withdraw must be greater than 0' });

    const res = await fetch(`${PUBLIC_BACKEND_URL}/api/withdraw`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
      body: JSON.stringify({ amount }),
    });
    if (!res.ok) return fail(400, { error: (await res.json()).error });
    return { success: true };
  }
};
