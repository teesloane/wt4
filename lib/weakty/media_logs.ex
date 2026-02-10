defmodule Weakty.MediaLogs do
  use Ash.Domain, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Weakty.MediaLogs.MediaLog
    resource Weakty.MediaLogs.MediaLogTag
  end
end
