<script lang="ts">
  import { enhance } from '$app/forms';
  import type { PageProps } from './$types';
  let { form }: PageProps = $props();
</script>

<h1>Admin — manage commodities</h1>

{#if form?.success}<p style="color:green">Commodity added ✓</p>{/if}
{#if form?.error}<p style="color:red">{form.error}</p>{/if}

<form method="POST" action="?/addCommodity" use:enhance>
  <input name="symbol" placeholder="symbol (e.g. SILVER)" />
  <input name="name" placeholder="name" />
  <input name="unit" placeholder="unit (e.g. oz)" />
  <button>Add commodity</button>
</form>
