<script lang="ts">
  import type { PageProps } from "./$types";

  let status = $state("checking…");
  let { data }: PageProps = $props();

  $effect(() => {
    fetch("/api/health")
      .then((r) => r.json())
      .then((data) => {
        status = data.ok ? `ok — db time ${data.db}` : `error: ${data.error}`;
      })
      .catch((err: Error) => {
        status = `fetch failed: ${err.message}`;
      });
  });
</script>

<main style="font-family: system-ui; padding: 2rem; max-width: 640px;">
  <h1>Commodity exchange</h1>
  {#each data.commodities as c}
    <p>
      <a href="/orders/{c.symbol}">{c.name}</a>
    </p>
  {/each}
</main>
