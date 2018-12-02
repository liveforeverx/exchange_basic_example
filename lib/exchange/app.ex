defmodule Exchange.App do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = []

    opts = [strategy: :one_for_one, name: Exchange.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Actually better way to know upfront if we need persistence or not, so that we can add our
  persistent layer in a supervision tree upfront.
  """
  def ensure_persistent!() do
    case Supervisor.start_child(Exchange.Supervisor, Exchange.Db) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _}} -> :ok
      {:error, error} -> raise "Error by starting of persistent layer: #{inspect(error)}"
    end
  end
end
