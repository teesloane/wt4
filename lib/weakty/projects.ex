defmodule Weakty.Projects do
  use Ash.Domain, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Weakty.Projects.Project
    resource Weakty.Projects.ProjectTag
  end
end
