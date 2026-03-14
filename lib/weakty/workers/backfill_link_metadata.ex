defmodule Weakty.Workers.BackfillLinkMetadata do
  use Oban.Worker, queue: :default

  require Logger

  @impl true
  def perform(_job) do
    links = Ash.read!(Weakty.Links.Link, authorize?: false)

    missing =
      Enum.filter(links, fn link -> is_nil(link.og_image) end)

    Logger.info("BackfillLinkMetadata: queuing #{length(missing)} links without OG images")

    Enum.each(missing, fn link ->
      %{"link_id" => link.id}
      |> Weakty.Workers.FetchLinkMetadata.new()
      |> Oban.insert()
    end)

    :ok
  end
end
