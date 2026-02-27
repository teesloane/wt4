defmodule Weakty.Tils.Changes.ConvertMarkdownToHtml do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    body = Ash.Changeset.get_attribute(changeset, :body)
    html = Ash.Changeset.get_attribute(changeset, :html)

    should_convert? = body && (!html || Ash.Changeset.changing_attribute?(changeset, :body))

    if should_convert? do
      case MDEx.to_html(body) do
        {:ok, html_output} ->
          Ash.Changeset.force_change_attribute(changeset, :html, html_output)
        {:error, _} ->
          changeset
      end
    else
      changeset
    end
  end
end
