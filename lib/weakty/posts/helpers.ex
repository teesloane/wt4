defmodule Weakty.Posts.Helpers do
  @moduledoc """
  Helper functions for Post resource
  """

  @doc """
  Returns excerpt if present, otherwise returns markdown.
  Used for entity sync to prioritize excerpt over full markdown content.
  """
  def content_for_entity(post) do
    post.excerpt || post.markdown
  end
end
