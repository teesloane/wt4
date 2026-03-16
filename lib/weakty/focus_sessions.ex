defmodule Weakty.FocusSessions do
  use Ash.Domain, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Weakty.FocusSessions.FocusSession
  end
end
