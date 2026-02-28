defmodule WeaktyWeb.FormHelpers do
  @moduledoc """
  Shared helper functions for admin form LiveViews.
  """

  @doc """
  Filters a list of all tag names by a search input, excluding already-selected tags.
  Returns up to 8 matching suggestions.
  """
  def suggest_tags("", _all_tags, _current), do: []
  def suggest_tags(input, all_tags, current) do
    q = String.downcase(input)
    all_tags
    |> Enum.filter(fn t -> String.contains?(String.downcase(t), q) and t not in current end)
    |> Enum.take(8)
  end
end
