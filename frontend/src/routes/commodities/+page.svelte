<script lang="ts">
  let { data } = $props();
</script>

<h1>Commodities</h1>
<ul>
  {#each data.commodities as c}
    <li><strong>{c.symbol}</strong> - {c.name} ({c.unit})</li>
  {/each}
</ul>
