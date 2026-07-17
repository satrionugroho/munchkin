defmodule Munchkin.Cldr do
  use Cldr,
    locales: [:en, :id],
    providers: [Cldr.Number, Cldr.DateTime, Cldr.Calendar]
end
