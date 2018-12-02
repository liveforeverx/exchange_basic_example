defmodule Exchange.Db do
  @moduledoc """
  Basic database layer for an application to access local persistence for Exchange.

  It creates public ets table with the same name as database for easier shared access.

  Keys can be only binaries.
  """

  use GenServer
  @default_db :exchange

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  @doc """
  Get database reference by name
  """
  def db(name) do
    :ets.lookup_element(name, :db, 2)
  end

  @doc """
  Get a object by the specified key
  """
  def get(name \\ __MODULE__, key) do
    db = db(name)

    case :rocksdb.get(db, key, []) do
      {:ok, binary} -> :erlang.binary_to_term(binary)
      :not_found -> nil
    end
  end

  @doc """
  Add one object to a store
  """
  def put(name \\ __MODULE__, key, value) do
    db = db(name)
    :rocksdb.put(db, key, :erlang.term_to_binary(value), [])
  end

  @doc """
  Remove one object from a store
  """
  def delete(name \\ __MODULE__, key) do
    IO.inspect({:delete, key})
    db = db(name)
    :rocksdb.delete(db, key, [])
  end

  # TODO: Add basic documentation
  def iter(), do: iter(__MODULE__)

  def iter(name) when is_atom(name) do
    db = db(name)
    {:ok, iter} = :rocksdb.iterator(db, [])
    {:first, iter}
  end

  def iter(key) when is_binary(key), do: iter(__MODULE__, key)

  def iter(name, key) do
    db = db(name)
    {:ok, iter} = :rocksdb.iterator(db, [])
    {{:seek, key}, iter}
  end

  def next({next, iter})
      when (is_tuple(next) and elem(next, 0) == :seek) or next in [:next, :first] do
    case :rocksdb.iterator_move(iter, next) do
      {:ok, key, value} -> {{key, :erlang.binary_to_term(value)}, {:next, iter}}
      {:error, :iterator_closed} -> {nil, {:closed, iter}}
      {:error, :invalid_iterator} -> {nil, {:closed, iter}}
    end
  end

  def iter_close({:closed, _iter}), do: nil
  def iter_close({_, iter}), do: :rocksdb.iterator_close(iter)

  # Implementation

  @impl true
  def init(opts) do
    name = opts[:name] || __MODULE__
    db_path = db_path(opts[:database] || @default_db)
    {:ok, db_ref} = :rocksdb.open(db_path, create_if_missing: true)
    :ets.new(name, [:named_table, :public, {:read_concurrency, true}])
    :ets.insert(name, {:db, db_ref})
    {:ok, db_ref}
  end

  defp db_path("/" <> _ = path) do
    ensure_exists!(path)
    to_charlist(path)
  end

  defp db_path(database) do
    db_dir = :exchange |> :code.priv_dir() |> to_string()
    db_path = Path.join(db_dir, to_string(database))
    db_path(db_path)
  end

  defp ensure_exists!(path) do
    case File.mkdir_p(path) do
      :ok ->
        :ok

      {:error, :eexist} ->
        :ok

      {:error, reason} ->
        raise File.Error,
          reason: reason,
          action: "make directory (with -p)",
          path: IO.chardata_to_string(path)
    end
  end
end
