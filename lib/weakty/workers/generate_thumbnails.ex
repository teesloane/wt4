defmodule Weakty.Workers.GenerateThumbnails do
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl true
  def perform(%Oban.Job{args: %{"source_path" => source_path, "uuid" => uuid}}) do
    case Weakty.ImageProcessor.generate_thumbnails(source_path, uuid) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
