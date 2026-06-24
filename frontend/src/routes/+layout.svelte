<script lang="ts">
  import { enhance } from "$app/forms";
  import type { LayoutProps } from "./$types";
  let { data, children }: LayoutProps = $props();
</script>

<header class="topbar">
  <a href="/" class="brand">Commodity exchange</a>
  <nav>
    {#if data.user}
      <span class="money">{data.user.balance} CZK</span>
      {#if data.user.role === 'admin'}<a href="/admin">Admin</a>{/if}
      <a href="/profile">{data.user.username}</a>
      <form method="POST" action="/logout" use:enhance>
        <button>Log out</button>
      </form>
    {:else}
      <a href="/login">Log in</a>
    {/if}
  </nav>
</header>

{@render children()}

<style>
  .topbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0.6rem 1rem;
    border-bottom: 1px solid #ddd;
  }
  .topbar nav {
    display: flex;
    gap: 1rem;
    align-items: center;
  }
  .money {
    font-weight: 600;
  }
</style>
