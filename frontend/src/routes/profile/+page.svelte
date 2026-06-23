<script lang="ts">
  import { enhance } from "$app/forms";
  let { data, form } = $props();
</script>

<h1>Profile</h1>
{#if data.user}
  <p>Signed in as <strong>{data.user.username}</strong></p>
  <p>Balance: {data.user.balance} CZK</p>
{:else}
  <p><a href="/login">Log in</a> to see your profile.</p>
{/if}

{#if form?.error}<p style="color:red">{form.error}</p>{/if}

<form method="POST" action="?/deposit" use:enhance>
  <input name="amount" min="0" type="number" step="any" placeholder="amount" />
  <button>Deposit</button>
</form>

<form method="POST" action="?/withdraw" use:enhance>
  <input name="amount" min="0" type="number" step="any" placeholder="amount" />
  <button>Withdraw</button>
</form>

<h2>Transactions</h2>
<table>
  <thead>
    <tr>
      <th>Timestamp</th>
      <th>Type</th>
      <th>Change</th>
    </tr>
  </thead>
  <tbody>
    {#each data.transactions as transaction}
      <tr>
        <td>{transaction.created_at}</td>
        <td>{transaction.type}</td>
        <td>{transaction.change}</td>
      </tr>
    {/each}
  </tbody>
</table>
