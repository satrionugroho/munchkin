defmodule Munchkin.Inventory.Technical.Stats do
  def linregress(x, y) when is_list(x) and is_list(y) do
    _ = define_size(x, y)

    {result, _globals} =
      Pythonx.eval(
        """
        import numpy as np
        from scipy.stats import linregress

        stock_returns = np.array(y)
        market_returns = np.array(x)

        slope, intercept, r_value, p_value, std_err = linregress(market_returns, stock_returns)
        {
          "slope": slope,
          "intercept": intercept,
          "r_value": r_value,
          "p_value": p_value,
          "std_err": std_err
        }
        """,
        %{"x" => x, "y" => y}
      )

    Pythonx.decode(result)
  end

  defp define_size(x, y) when length(x) == length(y) do
    length(x)
  end

  defp define_size(x, y) do
    Nx.size(x)
    |> then(fn s ->
      Nx.size(y)
      |> Kernel.==(s)
    end)
    |> case do
      true -> Nx.size(x)
      _ -> raise ArgumentError, message: "given data is not the same length"
    end
  end

  def beta_covariance(x, y) do
    _ = define_size(x, y)

    {result, _globals} =
      Pythonx.eval(
        """
        import numpy as np

        stock_returns = np.array(y)
        market_returns = np.array(x)

        ccov = np.cov(stock_returns, market_returns)[0, 1]
        market_variance = np.var(market_returns)
        covariance = ccov / market_variance

        {
          "covariance": ccov,
          "variance": market_variance,
          "beta": covariance
        }
        """,
        %{"x" => x, "y" => y}
      )

    Pythonx.decode(result)
  end
end
