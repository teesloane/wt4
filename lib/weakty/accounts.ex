defmodule Weakty.Accounts do
  use Ash.Domain, otp_app: :weakty, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Weakty.Accounts.Token
    resource Weakty.Accounts.User
  end
end
