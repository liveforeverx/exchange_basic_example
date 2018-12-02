defmodule Tree do
  @moduledoc """
  This a basic port of :gb_trees to idiomatic Elixir code, which uses the data structure as first
  argument.

  Implementation is extended only to functions, which are needed to use for the challenge.

  It is not in a namespace of `Exchange`, because for the case of real project, it should be moved
  to separate library in my opinion.
  """

  @typep key :: any
  @typep value :: any
  @typep iter :: any
  @opaque tree :: :gb_trees.tree(key, value)

  @spec new :: tree
  @doc """
  Creates empty `tree`.
  """
  def new, do: :gb_trees.empty()

  @doc """
  Creates a `tree` from an `enumerable`. Duplicated keys are removed.
  """
  @spec new(Enumerable.t()) :: tree
  def new(enumerable), do: enumerable |> Enum.to_list() |> :gb_trees.from_orddict()

  @doc """
  Puts the given value under `key` in `tree`.
  """
  @spec put(tree, key, value) :: tree
  def put(tree, key, value), do: :gb_trees.enter(key, value, tree)

  @doc """
  Gets the value for a specific `key` in `tree`.

  If `key` is present in `tree` with value `value`, then `value` is returned. Otherwise,
  `default` is returned (which is `nil` unless specified otherwise).
  """
  @spec get(tree, key) :: tree
  def get(tree, key) do
    case :gb_trees.lookup(key, tree) do
      :none -> nil
      {:value, value} -> value
    end
  end

  @doc """
  Updates the `key` in `tree` with the given function.
  """
  @spec update(tree, key, value, (value() -> value())) :: tree
  def update(tree, key, default, fun) do
    case get(tree, key) do
      nil -> put(tree, key, default)
      value -> put(tree, key, fun.(value))
    end
  end

  @doc """
  Delete the `key` in `tree`.
  """
  @spec delete(tree, key) :: tree
  def delete(tree, key), do: :gb_trees.delete_any(key, tree)

  @doc """
  Returns an iterator that can be used for traversing the entries of `tree`.
  """
  @spec iter(tree) :: iter
  def iter(tree), do: :gb_trees.iterator(tree)

  @doc """
  Returns an iterator that can be used for traversing the entries of `tree`, starting from `key`.
  """
  @spec iter(tree, key) :: iter
  def iter(tree, key), do: :gb_trees.iterator_from(key, tree)

  @doc """
  Returns `{{key, value} | nil, iter}`
  """
  @spec next(iter) :: {{key, value}, iter} | {nil, iter}
  def next(iter) do
    case :gb_trees.next(iter) do
      :none -> {nil, iter}
      {key, value, iter} -> {{key, value}, iter}
    end
  end

  @doc """
  Converts `tree` to a `list`, where every element is `{key, value}` tuple.
  """
  @spec to_list(tree) :: list({key, value})
  def to_list(tree), do: :gb_trees.to_list(tree)
end
