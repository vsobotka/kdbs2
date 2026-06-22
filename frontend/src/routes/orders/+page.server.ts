import { fail } from '@sveltejs/kit';
import { PUBLIC_BACKEND_URL } from '$env/static/public';
import type { Actions, PageServerLoad } from './$types';

// This file runs only on the SvelteKit server, which cannot use the Vite proxy,
// so every call to Express must use its absolute URL.

export const load: PageServerLoad = async ({ fetch }) => {
  const commodities = await (await fetch(`${PUBLIC_BACKEND_URL}/api/commodities`)).json();
  return { commodities };
};

export const actions: Actions = {
  create: async ({ request, fetch }) => {
    const data = await request.formData();
    const order = {
      commodityId: Number(data.get('commodityId')),
      side: String(data.get('side')),
      quantity: Number(data.get('quantity')),
      price: Number(data.get('price')),
    };
    // app-level validation → instant, friendly feedback
    if (!order.quantity || order.quantity <= 0)
      return fail(400, { error: 'Quantity must be positive', values: order });

    const res = await fetch(`${PUBLIC_BACKEND_URL}/api/orders`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(order),
    });
    if (!res.ok) return fail(400, { error: (await res.json()).error, values: order });
    return { success: true };
  },
};
