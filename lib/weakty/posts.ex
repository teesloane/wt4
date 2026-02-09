defmodule Weakty.Posts do
  use Ash.Domain, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Weakty.Posts.Post
    resource Weakty.Posts.PostTag
  end
end
