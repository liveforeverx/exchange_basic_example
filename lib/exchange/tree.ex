defmodule Exchange.Tree do
  @moduledoc """
  Behaviour for using in `Exchange`, which abstract functions to have 2 different implementations
  of underlying sorted storage. For example:

    * in memory
    * persistent
  """

  @type t :: %__MODULE__{impl: module(), data: any()}

  @typep data :: any()
  @typep key :: any()
  @typep value :: any()
  @typep iter :: any()
  @callback new(type :: atom()) :: data()
  @callback put(data, key, value) :: data()
  @callback get(data, key) :: value() | nil
  @callback delete(data, key) :: data()
  @callback iter(data) :: iter()
  @callback iter(data, key) :: iter()
  @callback next(iter) :: {{key, value} | nil, iter}
  @callback iter_close(iter) :: any

  defstruct impl: nil, data: nil

  @doc """
  Creates empty `tree`.
  """
  def new(impl, type), do: %__MODULE__{impl: impl, data: impl.new(type)}

  @doc """
  Puts the given value under `key` in `tree`.
  """
  def put(%{impl: impl, data: data} = cont, key, value),
    do: %{cont | data: impl.put(data, key, value)}

  @doc """
  Gets the value for a specific `key` in `tree`.

  If `key` is present in `tree` with value `value`, then `value` is returned. Otherwise,
  `default` is returned (which is `nil` unless specified otherwise).
  """
  def get(%{impl: impl, data: data}, key), do: impl.get(data, key)

  @doc """
  Delete the `key` in `tree`.
  """
  def delete(%{impl: impl, data: data} = cont, key), do: %{cont | data: impl.delete(data, key)}

  @doc """
  Returns an iterator that can be used for traversing the entries of `tree`.
  """
  def iter(%{impl: impl, data: data} = cont), do: %{cont | data: impl.iter(data)}

  @doc """
  Returns an iterator that can be used for traversing the entries of `tree`, starting from `key`.
  """
  def iter(%{impl: impl, data: data} = cont, key), do: %{cont | data: impl.iter(data, key)}

  @doc """
  Returns `{{key, value} | nil, iter}`
  """
  def next(%{impl: impl, data: data} = cont) do
    {result, iter} = impl.next(data)
    {result, %{cont | data: iter}}
  end

  @doc """
  Closes iterator if needed
  """
  def iter_close(%{impl: impl, data: data}), do: impl.iter_close(data)
end
