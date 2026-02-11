defmodule Weakty.Projects.Changes.ConvertMarkdownToHtml do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    markdown = Ash.Changeset.get_attribute(changeset, :markdown)
    html = Ash.Changeset.get_attribute(changeset, :html)

    # Only convert if we have markdown and either:
    # 1. No HTML is set (for creates)
    # 2. Markdown is being changed (for updates)
    should_convert? = markdown && (!html || Ash.Changeset.changing_attribute?(changeset, :markdown))

    if should_convert? do
      case Earmark.as_html(markdown) do
        {:ok, html_output, _} ->
          Ash.Changeset.force_change_attribute(changeset, :html, html_output)
        {:error, _, _} ->
          changeset
      end
    else
      changeset
    end
  end
end
