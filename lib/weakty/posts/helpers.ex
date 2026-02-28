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

  def source_path_for_entity(post) do
    case post.post_type do
      :til -> "/til"
      :quote -> "/quotes"
      _ -> "/posts"
    end
  end
end
