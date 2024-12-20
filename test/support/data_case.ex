defmodule Horionos.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Horionos.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias Horionos.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Horionos.DataCase
    end
  end

  setup tags do
    Horionos.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(Horionos.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts
        |> Keyword.get(String.to_existing_atom(key), key)
        |> to_string()
      end)
    end)
  end

  def extract_user_token(fun) do
    {:ok, captured_emails} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    captured_email = captured_emails[Horionos.Accounts.Notifications.Channels.Email]
    [_, token | _] = String.split(captured_email.assigns.url, "[TOKEN]")
    token
  end
end
