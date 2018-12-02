defmodule Exchange.MemoryTree do
  @moduledoc """
  Implementation for in-memory handling of sorted structure using `Tree`
  """

  @behaviour Exchange.Tree

  @impl true
  def new(_type), do: Tree.new()

  @impl true
  def put(tree, key, value), do: Tree.put(tree, key, value)

  @impl true
  def get(tree, key), do: Tree.get(tree, key)

  @impl true
  def delete(tree, key), do: Tree.delete(tree, key)

  @impl true
  def iter(tree), do: Tree.iter(tree)

  @impl true
  def iter(tree, key), do: Tree.iter(tree, key)

  @impl true
  def next(iter), do: Tree.next(iter)

  @impl true
  def iter_close(_iter), do: nil
end
