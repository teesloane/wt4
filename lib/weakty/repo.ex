defmodule Weakty.Repo do
  use AshSqlite.Repo,
    otp_app: :weakty
end
