<script lang="ts">
  import { enhance } from "$app/forms";
  let { data, form } = $props(); // data.commodities (load) · form (action result)
</script>

<h1>Place an order</h1>

{#if form?.success}<p style="color:green">Order placed ✓</p>{/if}
{#if form?.error}<p style="color:red">{form.error}</p>{/if}

<form method="POST" action="?/create" use:enhance>
  <select name="commodityId">
    {#each data.commodities as c}<option value={c.id}>{c.symbol}</option>{/each}
  </select>
  <select name="side"><option>buy</option><option>sell</option></select>
  <input name="quantity" type="number" step="any" placeholder="quantity" />
  <input name="price" type="number" step="any" placeholder="price" />
  <button>Submit</button>
</form>
