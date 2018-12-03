defmodule Exchange do
  @moduledoc """
  This is a basic implementation for an order book challenge.

  Assumptions:

    * asks and bids should be managed separately (as I understand the problem) and merged only
      for actual show of order books, actually it needs further clarifications.
    * `:new` for the existing values(or low values) happens not so oft, as it rebuilds keys for
      all further indexes
    * keys should be sorted for more efficient `order_book` function. For the case that insert
      shouldn't be slow (like O(n) for lists, and gb_trees will have O(log(n)))
    * This doesn't interacts with user, so no validation of input data done
    * `price_index_level` is always positive integer, or at least should be.
    * `price_index_level` starts with 1 in order_book
    * how to handle situation if `price_level_index` 1 and 3 provided, but 2 was missing?
      * should be filled with zeros (chosen at the moment)
      * should 2 be ignored?

  Actually for persistent storage some real database should be used (depending on the system), but
  for this simplified example rocksdb was used (as it allows sorted keys iterators) and can replace
  our tree.

    * Current limitation, only one process can be started with `persistent: true`, so further
      changes for interface needed (for example using `name` to identify which order booking
      is used).

  Direct replacement of a datastructure was chosen based on time constraints, so actually internal
  datastructure should be used a state cache for a database (or may be accumulation for frequent
  order book requests).

  Proposal for changes in challenge:

    * `{:ok}` - is never used in Elixir programms, it would be better to simplify to `:ok` or
      `{:ok, true}` or any other usefull information `{:ok, any()}`. I have used `:ok` in
      implementation.
    * specs are wrong for the corresponding example, this `exchange: pid()` (keyword) should
      be changed to `exchange :: pid()` (named parameters).
  """

  alias Exchange.{Tree, MemoryTree, PersistentTree}
  use GenServer

  defstruct [:bids, :asks, :impl]

  @doc """
  Usage for persistent

      > GenServer.start_link(persistent: true)
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  @spec send_instruction(exchange :: pid(), event :: map()) :: :ok | {:error, reason :: any()}
  def send_instruction(pid, instruction) do
    GenServer.call(pid, {:instruction, instruction})
  end

  @spec order_book(exchange :: pid(), book_depth :: integer()) :: list(map())
  def order_book(pid, book_depth) do
    GenServer.call(pid, {:order_book, book_depth})
  end

  @impl true
  def init(opts) do
    persistent? = opts[:persistent] || false
    impl = implementation(persistent?)
    {:ok, %__MODULE__{asks: Tree.new(impl, :asks), bids: Tree.new(impl, :bids), impl: impl}}
  end

  defp implementation(true), do: PersistentTree
  defp implementation(false), do: MemoryTree

  @impl true
  def handle_call({:instruction, instruction}, _from, state) do
    {reply, state} = apply_instruction(state, instruction)
    {:reply, reply, state}
  end

  def handle_call({:order_book, book_depth}, _from, state) do
    {:reply, calc_order_book(state, book_depth), state}
  end

  defp apply_instruction(state, %{side: side} = instruction) do
    apply_on_side(state, side, &instruction_on_tree(&1, instruction))
  end

  defp apply_on_side(%{asks: asks} = state, :ask, fun) do
    case fun.(asks) do
      {:ok, asks} -> {:ok, %{state | asks: asks}}
      {:error, error} -> {{:error, error}, state}
    end
  end

  defp apply_on_side(%{bids: bids} = state, :bid, fun) do
    case fun.(bids) do
      {:ok, bids} -> {:ok, %{state | bids: bids}}
      {:error, error} -> {{:error, error}, state}
    end
  end

  defp instruction_on_tree(tree, %{instruction: :new} = instruction) do
    %{price_level_index: index, price: price, quantity: quantity} = instruction

    tree =
      tree
      |> shift(index, 1)
      |> Tree.put(index, %{price: price, quantity: quantity})

    {:ok, tree}
  end

  defp instruction_on_tree(tree, %{instruction: :update} = instruction) do
    %{price_level_index: index, price: price, quantity: quantity} = instruction

    case Tree.get(tree, index) do
      nil -> {:error, :not_found}
      _value -> {:ok, Tree.put(tree, index, %{price: price, quantity: quantity})}
    end
  end

  defp instruction_on_tree(tree, %{instruction: :delete} = instruction) do
    %{price_level_index: index} = instruction
    tree = tree |> shift(index, -1) |> Tree.delete(index)
    {:ok, tree}
  end

  defp shift(tree, index, modifier) do
    elements = tree |> Tree.iter(index) |> elements(index, [])
    tree = Enum.reduce(elements, tree, &Tree.delete(&2, elem(&1, 0)))

    Enum.reduce(elements, tree, fn {key, value}, tree -> Tree.put(tree, key + modifier, value) end)
  end

  defp elements(iter, index, elements) do
    case Tree.next(iter) do
      {{key, value}, iter} when key >= index ->
        elements(iter, index, [{key, value} | elements])

      _ ->
        Tree.iter_close(iter)
        elements
    end
  end

  # We calculate one order starting from 1 based on assumption
  defp calc_order_book(%{asks: asks, bids: bids}, book_depth) do
    asks_next = first_next(asks)
    bids_next = first_next(bids)
    do_calc_order_book(asks_next, bids_next, 1, book_depth, [])
  end

  defp do_calc_order_book({_, asks_iter}, {_, bids_iter}, index, book_depth, acc)
       when index > book_depth do
    # TODO: Actually would be better to have fold with automatic closing after usage
    Tree.iter_close(asks_iter)
    Tree.iter_close(bids_iter)
    Enum.reverse(acc)
  end

  defp do_calc_order_book(asks_next, bids_next, index, book_depth, acc) do
    {{ask_price, ask_quantity}, asks_next} = lookup_step_next(asks_next, index)
    {{bid_price, bid_quantity}, bids_next} = lookup_step_next(bids_next, index)

    order = %{
      ask_price: ask_price,
      ask_quantity: ask_quantity,
      bid_price: bid_price,
      bid_quantity: bid_quantity
    }

    do_calc_order_book(asks_next, bids_next, index + 1, book_depth, [order | acc])
  end

  defp first_next(tree), do: tree |> Tree.iter() |> Tree.next()

  defp lookup_step_next({{index, %{price: price, quantity: quantity}}, iter}, index),
    do: {{price, quantity}, Tree.next(iter)}

  defp lookup_step_next(next, _index), do: {{0.0, 0}, next}
end
