defmodule WeaktyWeb.PageController do
  use WeaktyWeb, :controller
  require Ash.Query

  def home(conn, _params) do
    import Ecto.Query

    posts =
      Weakty.Posts.Post
      |> Ash.Query.filter(status == :published and post_type == :post)
      |> Ash.Query.sort(published_at: :desc)
      |> Ash.Query.limit(5)
      |> Ash.read!()

    update =
      Weakty.Posts.Post
      |> Ash.Query.filter(status == :published and post_type == :update)
      |> Ash.Query.sort(published_at: :desc)
      |> Ash.Query.limit(1)
      |> Ash.read!()
      |> List.first()

    currently_reading =
      Weakty.MediaLogs.MediaLog
      |> Ash.Query.filter(media_type == :book and status == :consuming and public == true)
      |> Ash.Query.sort(date_started: :desc)
      |> Ash.read!()


    quotes =
      Weakty.Posts.Post
      |> Ash.Query.filter(status == :published and post_type == :quote)
      |> Ash.read!()

    random_quote = if Enum.empty?(quotes), do: nil, else: Enum.random(quotes)

    recent_fiction =
      Weakty.Posts.Post
      |> Ash.Query.filter(status == :published and post_type == :fiction)
      |> Ash.Query.sort(published_at: :desc)
      |> Ash.Query.limit(1)
      |> Ash.read!()
      |> List.first()

    top_areas =
      from(et in "entity_tags",
        join: t in "tags", on: t.id == et.tag_id,
        where: t.public == true,
        group_by: [t.id, t.name, t.slug],
        select: %{name: t.name, slug: t.slug, count: count(et.id)},
        order_by: [desc: count(et.id)],
        limit: 5
      )
      |> Weakty.Repo.all()

    render(conn, :home,
      posts: posts,
      currently_reading: currently_reading,
      update: update,
      recent_fiction: recent_fiction,
      random_quote: random_quote,
      top_areas: top_areas
    )
  end
end
