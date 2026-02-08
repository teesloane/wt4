defmodule Weakty.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Weakty.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:weakty, :token_signing_secret)
  end
end
