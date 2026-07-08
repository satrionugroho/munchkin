defmodule Munchkin.Cldr do
  use Cldr,
    locales: [:en, :id],
    providers: [Cldr.Number]
end
