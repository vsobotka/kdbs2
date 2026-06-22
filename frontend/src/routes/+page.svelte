<script lang="ts">
  let status = $state('checking…');

  $effect(() => {
    fetch('/api/health')
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
  <h1>Komoditní burza</h1>
  <p>Backend health: <code>{status}</code></p>
</main>
