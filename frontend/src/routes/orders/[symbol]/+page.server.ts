import { error, fail, redirect, type Cookies } from '@sveltejs/kit';
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

const getCommodity = async (fetch: typeof globalThis.fetch, symbol: string) => {
  const res = await fetch(`${PUBLIC_BACKEND_URL}/api/commodities/${symbol}`);
  if (!res.ok) throw error(404, `Unknown commodity: ${symbol}`);
  return res.json();
};

type Order = { id: number; side: "buy" | "sell"; quantity: string; price: string; created_at: string };

const getOrders = async (fetch: typeof globalThis.fetch, symbol: string): Promise<Order[]> => {
  const res = await fetch(`${PUBLIC_BACKEND_URL}/api/orders/${symbol}`);
  if (!res.ok) throw error(404, `Error fetching orders`);
  return res.json();
}

export const load: PageServerLoad = async ({ params, fetch, cookies }) => {
  const user = await getUser(cookies, fetch);
  if (!user) throw redirect(303, '/login');            // hide the page from guests
  return { commodity: await getCommodity(fetch, params.symbol), orders: await getOrders(fetch, params.symbol) };
};

export const actions: Actions = {
  create: async ({ params, request, fetch, cookies }) => {
    const user = await getUser(cookies, fetch);
    if (!user) throw redirect(303, '/login');          // the real gate: block the POST itself
    if (user.role === 'admin') return fail(403, { error: 'Admins cannot trade' });
    const commodity = await getCommodity(fetch, params.symbol);   // id from URL, not the form
    const f = await request.formData();
    const order = {
      commodityId: commodity.id,
      userId: user.id,                                  // identity from the session, not the form
      side: String(f.get('side')),
      quantity: Number(f.get('quantity')),
      price: Number(f.get('price')),
    };
    if (!order.quantity || order.quantity <= 0)
      return fail(400, { error: 'Quantity must be positive' });

    const res = await fetch(`${PUBLIC_BACKEND_URL}/api/orders`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(order),
    });
    if (!res.ok) return fail(400, { error: (await res.json()).error });
    return { success: true };
  },
};

