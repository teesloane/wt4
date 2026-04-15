import { useState, useCallback } from "react"
import { useQuery, useQueryClient } from "@tanstack/react-query"
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Skeleton } from "@/components/ui/skeleton"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Checkbox } from "@/components/ui/checkbox"
import { Plus, MoreHorizontal, Pencil, Trash2, ImageIcon, X } from "lucide-react"
import pb from "@/lib/pb"
import { toast } from "sonner"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogClose,
} from "@/components/ui/dialog"

// Auto-generate a slug from a name string.
function toSlug(name: string) {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
}

interface TagRecord {
  id: string
  name: string
  slug: string
  public: boolean
  featured_image: string
}

interface TagFormState {
  name: string
  slug: string
  public: boolean
}

const EMPTY_FORM: TagFormState = { name: "", slug: "", public: false }

function tagImageUrl(tag: TagRecord, thumb = "100x100") {
  if (!tag.id || !tag.featured_image) return null
  return `/api/files/tags/${tag.id}/${tag.featured_image}?thumb=${thumb}`
}

interface TagFormDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  initial?: TagRecord | null
  onSaved: () => void
}

function TagFormDialog({ open, onOpenChange, initial, onSaved }: TagFormDialogProps) {
  const isEdit = !!initial
  const [form, setForm] = useState<TagFormState>(
    initial ? { name: initial.name, slug: initial.slug, public: initial.public } : EMPTY_FORM
  )
  const [stagedFile, setStagedFile] = useState<File | null>(null)
  const [stagedPreview, setStagedPreview] = useState<string | null>(null)
  const [clearImage, setClearImage] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleOpenChange = (open: boolean) => {
    if (open) {
      setForm(initial ? { name: initial.name, slug: initial.slug, public: initial.public } : EMPTY_FORM)
      setStagedFile(null)
      setStagedPreview(null)
      setClearImage(false)
      setError(null)
    }
    onOpenChange(open)
  }

  const handleNameChange = (name: string) => {
    setForm(f => ({ ...f, name, slug: isEdit ? f.slug : toSlug(name) }))
  }

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    setStagedFile(file)
    setStagedPreview(URL.createObjectURL(file))
    setClearImage(false)
  }

  const handleClearImage = () => {
    setStagedFile(null)
    setStagedPreview(null)
    setClearImage(true)
  }

  const existingImageUrl = initial ? tagImageUrl(initial) : null
  const showExistingImage = isEdit && initial?.featured_image && !clearImage && !stagedPreview

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setSaving(true)
    setError(null)
    try {
      const formData = new FormData()
      formData.append("name", form.name.trim())
      formData.append("slug", form.slug.trim() || toSlug(form.name.trim()))
      formData.append("public", String(form.public))

      if (stagedFile) {
        formData.append("featured_image", stagedFile)
      } else if (clearImage && initial?.featured_image) {
        formData.append("featured_image-", initial.featured_image)
      }

      if (isEdit) {
        await pb.collection("tags").update(initial!.id, formData)
        toast.success("Tag updated")
      } else {
        await pb.collection("tags").create(formData)
        toast.success("Tag created")
      }
      onSaved()
      onOpenChange(false)
    } catch (err: any) {
      setError(err?.message ?? "Save failed")
    } finally {
      setSaving(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{isEdit ? "Edit tag" : "New tag"}</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="space-y-4 pt-2">
          <div className="space-y-1.5">
            <Label htmlFor="tag-name">Name</Label>
            <Input
              id="tag-name"
              value={form.name}
              onChange={e => handleNameChange(e.target.value)}
              required
              autoFocus
            />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="tag-slug">Slug</Label>
            <Input
              id="tag-slug"
              value={form.slug}
              onChange={e => setForm(f => ({ ...f, slug: e.target.value }))}
              placeholder="auto-generated"
              className="font-mono text-sm"
            />
          </div>
          <div className="flex items-center gap-2">
            <Checkbox
              id="tag-public"
              checked={form.public}
              onCheckedChange={checked => setForm(f => ({ ...f, public: !!checked }))}
            />
            <Label htmlFor="tag-public">Public</Label>
          </div>

          {/* Image upload */}
          <div className="space-y-2">
            <Label>Image</Label>
            {(showExistingImage || stagedPreview) && (
              <div className="relative w-fit">
                <img
                  src={stagedPreview ?? existingImageUrl!}
                  alt="Tag image"
                  className="h-20 w-20 rounded-md object-cover border"
                />
                <button
                  type="button"
                  onClick={handleClearImage}
                  className="absolute -top-1.5 -right-1.5 bg-background border rounded-full p-0.5 shadow-sm hover:bg-muted transition-colors"
                  title="Remove image"
                >
                  <X className="size-3" />
                </button>
              </div>
            )}
            {!stagedPreview && (
              <label className="flex items-center gap-2 w-fit cursor-pointer">
                <span className="text-xs px-2.5 py-1.5 rounded-md border border-input hover:bg-muted transition-colors flex items-center gap-1.5">
                  <ImageIcon className="size-3" />
                  {showExistingImage ? "Replace" : "Upload image"}
                </span>
                <input
                  type="file"
                  accept="image/*"
                  className="sr-only"
                  onChange={handleFileChange}
                />
              </label>
            )}
            {clearImage && (
              <p className="text-xs text-muted-foreground">Image will be removed on save.</p>
            )}
          </div>

          {error && <p className="text-sm text-destructive">{error}</p>}
          <DialogFooter>
            <DialogClose render={<Button type="button" variant="outline" />}>Cancel</DialogClose>
            <Button type="submit" disabled={saving}>
              {saving ? "Saving…" : isEdit ? "Save changes" : "Create tag"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

export default function TagsPage() {
  const queryClient = useQueryClient()
  const [formOpen, setFormOpen] = useState(false)
  const [editTag, setEditTag] = useState<TagRecord | null>(null)
  const [deleteTag, setDeleteTag] = useState<TagRecord | null>(null)
  const [deleting, setDeleting] = useState(false)

  const { data, isLoading } = useQuery({
    queryKey: ["tags"],
    queryFn: () =>
      pb.collection("tags").getList(1, 500, {
        sort: "name",
        fields: "id,name,slug,public,featured_image",
      }),
  })

  const tags = data?.items ?? []

  const invalidate = useCallback(() => {
    queryClient.invalidateQueries({ queryKey: ["tags"] })
  }, [queryClient])

  const openCreate = () => {
    setEditTag(null)
    setFormOpen(true)
  }

  const openEdit = (tag: TagRecord) => {
    setEditTag(tag)
    setFormOpen(true)
  }

  const handleDelete = async () => {
    if (!deleteTag) return
    setDeleting(true)
    try {
      await pb.collection("tags").delete(deleteTag.id)
      queryClient.invalidateQueries({ queryKey: ["tags"] })
      toast.success("Tag deleted")
    } catch (err: any) {
      toast.error(err?.message ?? "Delete failed")
    } finally {
      setDeleting(false)
      setDeleteTag(null)
    }
  }

  return (
    <div className="p-6 space-y-4 text-foreground">
      <div className="flex items-center justify-end">
        <Button size="sm" variant="secondary" onClick={openCreate}>
          <Plus className="size-3.5 mr-1" />
          New tag
        </Button>
      </div>

      <div className="rounded-md border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Name</TableHead>
              <TableHead>Slug</TableHead>
              <TableHead className="w-24">Public</TableHead>
              <TableHead className="w-10" />
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              Array.from({ length: 6 }).map((_, i) => (
                <TableRow key={i}>
                  <TableCell><Skeleton className="h-4 w-32" /></TableCell>
                  <TableCell><Skeleton className="h-4 w-28" /></TableCell>
                  <TableCell><Skeleton className="h-4 w-14" /></TableCell>
                  <TableCell />
                </TableRow>
              ))
            ) : tags.length === 0 ? (
              <TableRow>
                <TableCell colSpan={4} className="text-center py-12 text-muted-foreground">
                  No tags found.
                </TableCell>
              </TableRow>
            ) : tags.map(tag => (
              <TableRow key={tag.id} className="hover:bg-muted/50">
                <TableCell className="font-medium">{tag.name}</TableCell>
                <TableCell className="text-muted-foreground font-mono text-sm">{tag.slug}</TableCell>
                <TableCell>
                  {tag.public
                    ? <Badge variant="default">Public</Badge>
                    : <Badge variant="secondary">Private</Badge>}
                </TableCell>
                <TableCell onClick={e => e.stopPropagation()}>
                  <DropdownMenu>
                    <DropdownMenuTrigger
                      render={
                        <button className="p-1 rounded hover:bg-muted transition-colors text-muted-foreground" />
                      }
                    >
                      <MoreHorizontal className="size-4" />
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end">
                      <DropdownMenuItem onClick={() => openEdit(tag as unknown as TagRecord)}>
                        <Pencil className="size-3.5 mr-2" />
                        Edit
                      </DropdownMenuItem>
                      <DropdownMenuItem
                        variant="destructive"
                        onClick={() => setDeleteTag(tag as unknown as TagRecord)}
                      >
                        <Trash2 className="size-3.5 mr-2" />
                        Delete
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>

      {!isLoading && (
        <p className="text-xs text-muted-foreground">{tags.length} tag{tags.length !== 1 ? "s" : ""}</p>
      )}

      <TagFormDialog
        open={formOpen}
        onOpenChange={setFormOpen}
        initial={editTag}
        onSaved={invalidate}
      />

      {/* Delete confirmation */}
      <Dialog open={!!deleteTag} onOpenChange={open => !open && setDeleteTag(null)}>
        <DialogContent showCloseButton={false}>
          <DialogHeader>
            <DialogTitle>Delete tag?</DialogTitle>
            <DialogDescription>
              &ldquo;{deleteTag?.name}&rdquo; will be permanently deleted.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <DialogClose render={<Button variant="outline" />}>Cancel</DialogClose>
            <Button variant="destructive" onClick={handleDelete} disabled={deleting}>
              {deleting ? "Deleting…" : "Delete"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
