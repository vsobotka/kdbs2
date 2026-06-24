<script lang="ts">
  import type { PageProps } from "./$types";
  let { data }: PageProps = $props();
</script>

<main style="font-family: system-ui; padding: 2rem; max-width: 640px;">
  <h1>Commodity exchange</h1>
  {#each data.commodities as c}
    <p>
      <a href="/orders/{c.symbol}">{c.name}</a>
    </p>
  {/each}
</main>
