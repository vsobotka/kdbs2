<script lang="ts">
  let { data } = $props();
</script>

<h1>Profile</h1>
{#if data.user}
  <p>Signed in as <strong>{data.user.username}</strong></p>
  <p>Balance: {data.user.balance} Kč</p>
{:else}
  <p><a href="/login">Log in</a> to see your profile.</p>
{/if}
