defmodule Exchange.PersistentTree do
  @moduledoc """
  Implementation for persistent handling of sorted structure using rocksdb.

  In this case we need to trasform integer keys to binary keys and we will use this schema:

    `prefix` <> `:` <> `0...` <> `key`

  Prefix is used to differentiate different types in the same database. Than separator `:`.
  Zeros are used to make key searchable via prefix. So that 9 will be before 11
  (with zeros: "09", "11").
  """

  alias Exchange.{App, Db}
  @behaviour Exchange.Tree

  # We define length and dependend on it the keys and default zeros key will be regenerated of
  @length 10

  @impl true
  def new(type) do
    App.ensure_persistent!()
    # We use type as our key prefix in rocksdb
    to_string(type)
  end

  @impl true
  def put(prefix, key, value) do
    key |> normalize_key(prefix) |> Db.put(value)
    prefix
  end

  @impl true
  def get(prefix, key), do: key |> normalize_key(prefix) |> Db.get()

  @impl true
  def delete(prefix, key) do
    key |> normalize_key(prefix) |> Db.delete()
    prefix
  end

  # We control via prefix, what we can iterate in rocksdb for our type
  @impl true
  def iter(prefix), do: {Db.iter(prefix), prefix}

  @impl true
  def iter(prefix, key) do
    key = normalize_key(key, prefix)
    {Db.iter(key), prefix}
  end

  @impl true
  def next({iter, prefix}) do
    case Db.next(iter) do
      {{key, value}, iter} ->
        if String.starts_with?(key, prefix),
          do: {{parse_key(key), value}, {iter, prefix}},
          else: {nil, {iter, prefix}}

      {_, iter} ->
        {nil, {iter, prefix}}
    end
  end

  @impl true
  def iter_close({iter, _prefix}), do: Db.iter_close(iter)

  defp normalize_key(key, prefix) do
    digits = Integer.to_string(key)
    prefix <> ":" <> String.duplicate("0", @length - byte_size(digits)) <> digits
  end

  defp parse_key(key) do
    [_, digits] = String.split(key, ":", parts: 2)
    {int, ""} = Integer.parse(digits)
    int
  end
end
