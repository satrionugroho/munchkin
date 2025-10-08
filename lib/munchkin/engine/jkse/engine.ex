defmodule Munchkin.Engine.Jkse.Engine do
  defmacro __using__(_) do
    quote do
      import Munchkin.Engine.Jkse.Config,
        only: [base_url: 0, runtime_dir: 0, get_url: 2, json_module: 0, get_url: 1]

      import Munchkin.Engine.Jkse.Session, only: [fetch: 2, download: 3]
      import Munchkin.Engine.Jkse.Utils, only: [parse_date: 1, string_to_date: 1]
    end
  end
end
