import { useQuery } from "@tanstack/react-query"
import { Separator } from "@/components/ui/separator"
import pb from "@/lib/pb"
import type { PostData } from "@/pages/PostEditorPage"
import TagsCombobox from "./TagsCombobox"
import DateTimePicker from "./DateTimePicker"

interface Props {
  post: PostData
  postId: string | null
  onChange: (updates: Partial<PostData>) => void
  onSlugEdit: () => void
}

interface Tag {
  id: string
  name: string
}

function Label({ children }: { children: React.ReactNode }) {
  return (
    <label className="block text-xs font-medium text-muted-foreground mb-1">
      {children}
    </label>
  )
}

function Field({ children }: { children: React.ReactNode }) {
  return <div className="space-y-1">{children}</div>
}

function SidebarInput({
  value,
  onChange,
  placeholder,
  type = "text",
}: {
  value: string
  onChange: (v: string) => void
  placeholder?: string
  type?: string
}) {
  return (
    <input
      type={type}
      value={value}
      onChange={e => onChange(e.target.value)}
      placeholder={placeholder}
      className="w-full px-2 py-1.5 text-sm bg-transparent border border-input rounded-md outline-none focus:border-ring focus:ring-2 focus:ring-ring/30 placeholder:text-muted-foreground/50"
    />
  )
}

function SidebarSelect({
  value,
  onChange,
  options,
}: {
  value: string
  onChange: (v: string) => void
  options: { label: string; value: string }[]
}) {
  return (
    <select
      value={value}
      onChange={e => onChange(e.target.value)}
      className="w-full px-2 py-1.5 text-sm bg-background border border-input rounded-md outline-none focus:border-ring focus:ring-2 focus:ring-ring/30 text-foreground"
    >
      {options.map(o => (
        <option key={o.value} value={o.value}>
          {o.label}
        </option>
      ))}
    </select>
  )
}

function Toggle({
  checked,
  onChange,
  label,
}: {
  checked: boolean
  onChange: (v: boolean) => void
  label: string
}) {
  return (
    <label className="flex items-center justify-between cursor-pointer py-0.5">
      <span className="text-sm text-foreground">{label}</span>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        onClick={() => onChange(!checked)}
        className={[
          "relative inline-flex h-4.5 w-8 shrink-0 rounded-full transition-colors",
          checked ? "bg-primary" : "bg-input",
        ].join(" ")}
      >
        <span
          className={[
            "pointer-events-none inline-block h-3.5 w-3.5 rounded-full bg-white shadow-sm transition-transform mt-0.5",
            checked ? "translate-x-3.5 ml-0.5" : "translate-x-0.5",
          ].join(" ")}
        />
      </button>
    </label>
  )
}

const POST_TYPES = [
  { label: "Post", value: "post" },
  { label: "TIL", value: "til" },
  { label: "Quote", value: "quote" },
  { label: "Update", value: "update" },
  { label: "Fiction", value: "fiction" },
  { label: "Process", value: "process" },
  { label: "Page", value: "page" },
]

const STATUSES = [
  { label: "Draft", value: "draft" },
  { label: "Published", value: "published" },
]

export default function PostSidebar({ post, postId, onChange, onSlugEdit }: Props) {
  const { data: tagsData } = useQuery({
    queryKey: ["tags"],
    queryFn: () => pb.collection("tags").getFullList({ sort: "name", fields: "id,name" }),
  })
  const allTags = (tagsData ?? []) as unknown as Tag[]

  const handleFeaturedImageChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file || !postId) return
    try {
      const formData = new FormData()
      formData.append("featured_image", file)
      await pb.collection("posts").update(postId, formData)
      onChange({ featured_image: file.name })
    } catch {
      // user can retry
    }
  }

  return (
    <aside className="w-72 shrink-0 border-l bg-background overflow-y-auto">
      <div className="p-4 space-y-4">

        {/* Type + Status */}
        <div className="grid grid-cols-2 gap-2">
          <Field>
            <Label>Type</Label>
            <SidebarSelect
              value={post.post_type}
              onChange={v => onChange({ post_type: v })}
              options={POST_TYPES}
            />
          </Field>
          <Field>
            <Label>Status</Label>
            <SidebarSelect
              value={post.status}
              onChange={v => onChange({ status: v })}
              options={STATUSES}
            />
          </Field>
        </div>

        <Separator className="" />

        {/* Slug */}
        <Field>
          <Label>Slug</Label>
          <SidebarInput
            value={post.slug}
            onChange={v => { onSlugEdit(); onChange({ slug: v }) }}
            placeholder="url-slug"
          />
        </Field>

        {/* Published at — shadcn calendar picker */}
        <Field>
          <Label>Publish date</Label>
          <DateTimePicker
            value={post.published_at}
            onChange={v => onChange({ published_at: v })}
          />
        </Field>

        <Separator className="" />

        {/* Toggles */}
        <div className="space-y-1.5">
          <Toggle checked={post.public} onChange={v => onChange({ public: v })} label="Public" />
          <Toggle checked={post.featured} onChange={v => onChange({ featured: v })} label="Featured" />
        </div>

        <Separator className="" />

        {/* Excerpt */}
        <Field>
          <Label>Excerpt</Label>
          <textarea
            value={post.excerpt}
            onChange={e => onChange({ excerpt: e.target.value })}
            placeholder="Short summary…"
            rows={3}
            className="w-full px-2 py-1.5 text-sm bg-transparent border border-input rounded-md outline-none resize-none focus:border-ring focus:ring-2 focus:ring-ring/30 placeholder:text-muted-foreground/50"
          />
        </Field>

        {/* Attribution — only for quotes */}
        {post.post_type === "quote" && (
          <>
            <Separator className="" />
            <Field>
              <Label>Attribution</Label>
              <SidebarInput
                value={post.attribution}
                onChange={v => onChange({ attribution: v })}
                placeholder="Author or source"
              />
            </Field>
            <Field>
              <Label>Attribution URL</Label>
              <SidebarInput
                value={post.attribution_url}
                onChange={v => onChange({ attribution_url: v })}
                placeholder="https://…"
              />
            </Field>
          </>
        )}

        {/* Tags — multi-select combobox with create */}
        <Separator className="" />
        <Field>
          <Label>Tags</Label>
          <TagsCombobox
            allTags={allTags}
            selectedIds={post.tags}
            onChange={ids => onChange({ tags: ids })}
          />
        </Field>

        {/* Featured Image */}
        <Separator className="" />
        <Field>
          <Label>Featured image</Label>
          {post.featured_image && (
            <p className="text-xs text-muted-foreground mb-1 truncate">{post.featured_image}</p>
          )}
          {postId ? (
            <label className="flex items-center gap-2 cursor-pointer">
              <span className="text-xs px-2 py-1 rounded border border-input hover:bg-muted transition-colors">
                {post.featured_image ? "Replace" : "Upload"}
              </span>
              <input
                type="file"
                accept="image/*"
                className="sr-only"
                onChange={handleFeaturedImageChange}
              />
            </label>
          ) : (
            <p className="text-xs text-muted-foreground">Save the post first</p>
          )}
        </Field>

      </div>
    </aside>
  )
}
