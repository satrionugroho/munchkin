defmodule Munchkin.Engine.Jkse.CLI do
  alias Munchkin.Engine.Jkse.Config

  def __after_compile__(_env, _module) do
    __MODULE__.run([])
  end

  def run(_args) do
    with {:ok, package_manager} <- find_package_manager(),
         :ok <- install_prerequites(package_manager),
         :ok <- remove_lock(),
         {_result, 0} <- install() do
      :logger.info("Done.")
    else
      :installed ->
        :logger.info("All set!.")

      {_result, exit_status} when is_number(exit_status) ->
        :logger.warning(
          "Failed to install playwright browsers. Status code #{inspect(exit_status)}"
        )

      {:error, msg} ->
        :logger.warning(msg)
    end
  end

  defp find_package_manager do
    ["pnpm", "npm", "bun"]
    |> Enum.reduce(nil, fn x, acc ->
      case acc do
        url when is_bitstring(url) -> url
        _ -> System.find_executable(x)
      end
    end)
    |> then(fn
      nil -> {:error, "Cannot find nodejs package manager"}
      url -> {:ok, url}
    end)
  end

  defp install_prerequites(manager) do
    with node_prj <- Config.runtime_dir(),
         module <- Path.join(node_prj, "node_modules"),
         false <- File.exists?(module),
         {_, 0} <- System.cmd(manager, ["install"], cd: node_prj) do
      :logger.info("All required packages are download")
      :ok
    else
      true -> :installed
    end
  end

  defp remove_lock do
    :logger.info("Removing lock")

    Config.runtime_dir()
    |> File.ls!()
    |> Enum.find(&String.contains?(&1, "lock"))
    |> case do
      file when is_bitstring(file) -> Path.join(Config.runtime_dir(), file)
      _ -> :error
    end
    |> then(fn
      path when is_bitstring(path) -> File.rm!(path)
      ret -> ret
    end)
    |> tap(fn _ ->
      :logger.info("Continuing to download the driver")
    end)
  end

  defp install do
    Config.runtime_dir()
    |> Path.join("node_modules/playwright/cli.js")
    |> System.cmd(["install", "--with-deps"])
    |> IO.inspect()
  end
end
