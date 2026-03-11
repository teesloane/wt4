defmodule Weakty.MediaLogs.Status do
  use Ash.Type.Enum,
    values: [
      :want_to_consume,
      :consuming,
      :consumed,
      :on_hold,
      :abandoned
    ]
end
