defmodule Munchkin.Inventory.Transaction do
  use Ecto.Schema

  require Decimal

  import Ecto.Changeset, warn: false

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "transactions" do
    field :transaction_type, Munchkin.EctoType.Enum,
      values: [:buy, :sell],
      module: Munchkin.Inventory.TransactionType

    field :status, Munchkin.EctoType.Enum,
      values: [:pending, :queue, :ongoing, :executed],
      module: Munchkin.Inventory.TransactionStatus

    field :transaction_date, :utc_datetime
    field :settlement_date, :utc_datetime
    field :reference_id, :string

    field :market_id, :integer, virtual: true

    field :price, :integer
    field :quantity, :integer

    field :fee, :decimal
    field :others, :map
    field :realizations, :map

    field :total_value, :decimal
    field :current_quantity, :integer

    belongs_to :asset, Munchkin.Inventory.Asset
    belongs_to :user, Munchkin.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(trx, params \\ %{}) do
    trx
    |> cast(params, [
      :transaction_type,
      :transaction_date,
      :price,
      :settlement_date,
      :reference_id,
      :quantity,
      :market_id,
      :status,
      :asset_id,
      :user_id
    ])
    |> validate_required([
      :transaction_date,
      :price,
      :quantity,
      :transaction_type
    ])
    |> detailed_transaction(params)
    |> assign_status()
    |> assign_current_quantity()
    |> ensure_validation(params)
  end

  defp ensure_validation(changeset, %{portfolio: portfolio}) do
    validate(changeset, portfolio)
  end

  defp ensure_validation(changeset, %{"portfolio" => portfolio}) do
    validate(changeset, portfolio)
  end

  defp ensure_validation(changeset, _), do: changeset

  defp assign_current_quantity(changeset) do
    quantity = get_field(changeset, :quantity)

    case get_field(changeset, :transaction_type) do
      %{key: :buy} ->
        put_change(changeset, :current_quantity, quantity)

      _ ->
        changeset
    end
  end

  def validate(%Ecto.Changeset{} = trx, portfolio) do
    case get_field(trx, :transaction_type) do
      %{key: :sell} ->
        qty = Map.get(portfolio, :quantity) |> Decimal.to_integer()

        trx
        |> validate_number(:quantity, less_than_or_equal_to: qty)

      _ ->
        trx
    end
  end

  def subtract_quantity(%__MODULE__{} = trx, quantity) do
    cast(trx, %{}, [])
    |> subtract_quantity(quantity)
  end

  def subtract_quantity(%Ecto.Changeset{} = changeset, qty) do
    current = get_field(changeset, :current_quantity)
    IO.inspect(current)
    IO.inspect(qty)

    case Kernel.<=(current, qty) do
      true -> put_change(changeset, :current_quantity, current - qty)
      _ -> add_error(changeset, :current_quantity, "quantity cannot less than 0")
    end
  end

  def settlement_changeset(trx, params \\ %{}) do
    trx
    |> cast(params, [:reference_id])
    |> put_change(:settlement_date, DateTime.utc_now(:second))
    |> put_change(:status, Munchkin.Inventory.TransactionStatus.executed())
  end

  defp detailed_transaction(%{valid?: true} = changeset, params) do
    case Enum.reduce(params, nil, fn
           {k, v}, _acc when k == "market" or k == :market -> v
           _, acc -> acc
         end) do
      %Munchkin.Inventory.Market{} = market ->
        case get_field(changeset, :transaction_type) do
          %Munchkin.Inventory.TransactionType{id: 1} -> buy_transaction(changeset, market)
          _ -> sell_transaction(changeset, market)
        end

      _ ->
        add_error(changeset, :market, "need to include the market")
    end
  end

  defp detailed_transaction(changeset, _), do: changeset

  defp buy_transaction(changeset, market) do
    price = get_field(changeset, :price)
    share = get_field(changeset, :quantity)
    net_buy = price * share
    basis_points = market.fee_compositions.buy_fee / 100 / 100
    realized_buy = (1 + basis_points) * net_buy

    changeset
    |> put_change(:total_value, realized_buy)
    |> put_change(:fee, realized_buy - net_buy)
  end

  defp sell_transaction(changeset, market) do
    price = get_field(changeset, :price)
    share = get_field(changeset, :quantity)
    net_sell = price * share
    basis_points = market.fee_compositions.sell_fee / 100 / 100
    sell_fee = basis_points * net_sell
    income_tax_points = market.fee_compositions.income_tax / 100 / 100
    income_tax = income_tax_points * net_sell
    realized_val = net_sell - (sell_fee + income_tax)

    changeset
    |> put_change(:total_value, realized_val)
    |> put_change(:fee, sell_fee)
    |> put_change(:others, %{"income_tax" => income_tax})
  end

  defp assign_status(changeset) do
    case get_field(changeset, :status) do
      nil -> put_status(changeset)
      _ -> changeset
    end
  end

  defp put_status(changeset) do
    case get_field(changeset, :settlement_date) do
      nil -> put_change(changeset, :status, Munchkin.Inventory.TransactionStatus.pending())
      _ -> put_change(changeset, :status, Munchkin.Inventory.TransactionStatus.executed())
    end
  end
end
