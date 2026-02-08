defmodule WeaktyWeb.PageController do
  use WeaktyWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
