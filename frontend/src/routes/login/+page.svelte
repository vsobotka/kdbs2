<script lang="ts">
  import { enhance } from "$app/forms";
  let { form } = $props();
</script>

<h1>Log in</h1>
{#if form?.error}<p style="color:red">{form.error}</p>{/if}
<form method="POST" use:enhance>
  <input name="username" placeholder="username" />
  <input name="password" type="password" placeholder="password" />
  <button>Log in</button>
</form>
