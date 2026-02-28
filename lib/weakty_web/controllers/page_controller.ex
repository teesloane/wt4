defmodule WeaktyWeb.PageController do
  use WeaktyWeb, :controller
  require Ash.Query

  def home(conn, _params) do
    posts =
      Weakty.Posts.Post
      |> Ash.Query.filter(status == :published and post_type == :post)
      |> Ash.Query.sort(published_at: :desc)
      |> Ash.Query.limit(5)
      |> Ash.read!()

    currently_reading =
      Weakty.MediaLogs.MediaLog
      |> Ash.Query.filter(media_type == :book and status == :consuming and public == true)
      |> Ash.Query.sort(date_started: :desc)
      |> Ash.Query.limit(1)
      |> Ash.read!()
      |> List.first()

    recent_tils =
      Weakty.Tils.Til
      |> Ash.Query.filter(public == true)
      |> Ash.Query.sort(published_at: :desc)
      |> Ash.Query.limit(5)
      |> Ash.read!()

    render(conn, :home,
      posts: posts,
      currently_reading: currently_reading,
      recent_tils: recent_tils
    )
  end
end
