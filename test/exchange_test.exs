defmodule ExchangeTest do
  use ExUnit.Case
  doctest Exchange

  setup_all do
    # Clean database after test run TODO: use other database location based on environment
    on_exit(fn ->
      File.rm_rf!("priv/exchange")
    end)

    :ok
  end

  test "basic example" do
    {:ok, pid} = Exchange.start_link()

    instruction = build_instr(:new, :bid, 1, 50.0, 30)
    Exchange.send_instruction(pid, instruction)

    instruction = build_instr(:new, :bid, 2, 40.0, 40)
    Exchange.send_instruction(pid, instruction)

    instruction = build_instr(:new, :ask, 1, 60.0, 10)
    Exchange.send_instruction(pid, instruction)

    instruction = build_instr(:new, :ask, 2, 70.0, 10)
    Exchange.send_instruction(pid, instruction)

    instruction = build_instr(:update, :ask, 2, 70.0, 20)
    Exchange.send_instruction(pid, instruction)

    instruction = build_instr(:update, :bid, 1, 50.0, 40)
    Exchange.send_instruction(pid, instruction)

    assert [
             %{ask_price: 60.0, ask_quantity: 10, bid_price: 50.0, bid_quantity: 40},
             %{ask_price: 70.0, ask_quantity: 20, bid_price: 40.0, bid_quantity: 40}
           ] == Exchange.order_book(pid, 2)

    assert [
             %{ask_price: 60.0, ask_quantity: 10, bid_price: 50.0, bid_quantity: 40},
             %{ask_price: 70.0, ask_quantity: 20, bid_price: 40.0, bid_quantity: 40},
             %{ask_price: 0.0, ask_quantity: 0, bid_price: 0.0, bid_quantity: 0}
           ] == Exchange.order_book(pid, 3)
  end

  test "persistent example" do
    {:ok, pid} = Exchange.start_link(persistent: true)

    instruction = build_instr(:new, :bid, 1, 50.0, 30)
    Exchange.send_instruction(pid, instruction)

    assert [
             %{ask_price: 0.0, ask_quantity: 0, bid_price: 50.0, bid_quantity: 30},
             %{ask_price: 0.0, ask_quantity: 0, bid_price: 0.0, bid_quantity: 0}
           ] == Exchange.order_book(pid, 2)
  end

  defp build_instr(instruction, side, price_level_index, price, quantity) do
    %{
      instruction: instruction,
      side: side,
      price_level_index: price_level_index,
      price: price,
      quantity: quantity
    }
  end
end
