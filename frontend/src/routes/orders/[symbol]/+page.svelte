<script lang="ts">
  import { enhance } from "$app/forms";
  import type { PageProps } from "./$types";
  let { data, form }: PageProps = $props();
  const buyOrders = $derived(
    data.orders.filter((o) => o.side === "buy").reverse(),
  );
  const sellOrders = $derived(data.orders.filter((o) => o.side === "sell"));
</script>

<h1>Trade: {data.commodity.name}</h1>
<p>Priced per {data.commodity.unit}</p>

{#if form?.success}<p style="color:green">Order placed ✓</p>{/if}
{#if form?.error}<p style="color:red">{form.error}</p>{/if}

<form method="POST" action="?/create" use:enhance>
  <select name="side"><option>buy</option><option>sell</option></select>
  <input name="quantity" type="number" step="any" placeholder="quantity" />
  <input name="price" type="number" step="any" placeholder="price" />
  <button>Place order for {data.commodity.symbol}</button>
</form>

<h2>Orders</h2>
<div style="width:350px;text-align:center">
  <table style="float:left; text-align: right;">
    <thead>
      <tr>
        <th>Side</th>
        <th>Quantity</th>
        <th>Price</th>
      </tr>
    </thead>
    <tbody>
      {#each buyOrders as order}
        <tr style="color: green">
          <td>{order.side}</td>
          <td>{order.quantity}</td>
          <td>{order.price}</td>
        </tr>
      {/each}
    </tbody>
  </table>

  <table style="float:right; text-align: left;">
    <thead>
      <tr>
        <th>Price</th>
        <th>Quantity</th>
        <th>Side</th>
      </tr>
    </thead>
    <tbody>
      {#each sellOrders as order}
        <tr style="color: red">
          <td>{order.price}</td>
          <td>{order.quantity}</td>
          <td>{order.side}</td>
        </tr>
      {/each}
    </tbody>
  </table>
</div>
