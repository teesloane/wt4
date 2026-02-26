defmodule Weakty.ObanJob do
  use Ecto.Schema
  @compile {:no_warn_undefined, Oban}

  @primary_key {:id, :integer, autogenerate: false}
  schema "oban_jobs" do
    field :state, :string
    field :queue, :string
    field :worker, :string
    field :args, :map
    field :errors, {:array, :map}, default: []
    field :attempt, :integer
    field :max_attempts, :integer
    field :inserted_at, :utc_datetime_usec
    field :scheduled_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec
  end

  def insert(changeset), do: Oban.insert(changeset)
  def cancel(id), do: Oban.cancel_job(id)
end
