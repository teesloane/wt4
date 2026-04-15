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
import { Textarea } from "@/components/ui/textarea"
import {
  Select, SelectTrigger, SelectContent, SelectItem, SelectValue,
} from "@/components/ui/select"
import { Plus, MoreHorizontal, Pencil, Trash2 } from "lucide-react"
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

// ─── Types ────────────────────────────────────────────────────────────────────

const STATUSES         = ["draft", "published"] as const
const PROJECT_STATUSES = ["ongoing", "hiatus", "completed"] as const

type PublishStatus  = typeof STATUSES[number]
type ProjectStatus  = typeof PROJECT_STATUSES[number]

interface ProjectRecord {
  id: string
  title: string
  slug: string
  excerpt: string
  markdown: string
  status: PublishStatus
  project_status: ProjectStatus
  public: boolean
  published_at: string
  start_date: string
  end_date: string
}

interface ProjectForm {
  title: string
  slug: string
  excerpt: string
  markdown: string
  status: PublishStatus
  project_status: ProjectStatus
  public: boolean
  start_date: string
  end_date: string
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function toSlug(s: string) {
  return s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
}

function formatDate(str: string | null) {
  if (!str) return "—"
  return new Date(str).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" })
}

const EMPTY_FORM: ProjectForm = {
  title: "", slug: "", excerpt: "", markdown: "",
  status: "draft", project_status: "ongoing",
  public: false, start_date: "", end_date: "",
}

function recordToForm(r: ProjectRecord): ProjectForm {
  return {
    title: r.title ?? "",
    slug: r.slug ?? "",
    excerpt: r.excerpt ?? "",
    markdown: r.markdown ?? "",
    status: r.status ?? "draft",
    project_status: r.project_status ?? "ongoing",
    public: r.public ?? false,
    start_date: r.start_date ?? "",
    end_date: r.end_date ?? "",
  }
}

// ─── ProjectFormDialog ────────────────────────────────────────────────────────

interface ProjectFormDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  initial?: ProjectRecord | null
  onSaved: () => void
}

function ProjectFormDialog({ open, onOpenChange, initial, onSaved }: ProjectFormDialogProps) {
  const isEdit = !!initial
  const [form, setForm] = useState<ProjectForm>(initial ? recordToForm(initial) : EMPTY_FORM)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleOpenChange = (open: boolean) => {
    if (open) {
      setForm(initial ? recordToForm(initial) : EMPTY_FORM)
      setError(null)
    }
    onOpenChange(open)
  }

  const set = (key: keyof ProjectForm, value: any) =>
    setForm(f => ({ ...f, [key]: value }))

  const handleTitleChange = (title: string) => {
    setForm(f => ({
      ...f,
      title,
      slug: isEdit ? f.slug : toSlug(title),
    }))
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setSaving(true)
    setError(null)
    try {
      const payload = {
        title: form.title.trim(),
        slug: form.slug.trim() || toSlug(form.title.trim()),
        excerpt: form.excerpt.trim() || null,
        markdown: form.markdown,
        status: form.status,
        project_status: form.project_status,
        public: form.public,
        start_date: form.start_date || null,
        end_date: form.end_date || null,
      }
      if (isEdit) {
        await pb.collection("projects").update(initial!.id, payload)
        toast.success("Project updated")
      } else {
        await pb.collection("projects").create(payload)
        toast.success("Project created")
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
      <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{isEdit ? "Edit project" : "New project"}</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="space-y-3 pt-2">
          <div className="grid grid-cols-2 gap-3">
            <div className="col-span-2 space-y-1.5">
              <Label>Title</Label>
              <Input
                value={form.title}
                onChange={e => handleTitleChange(e.target.value)}
                required
                autoFocus
              />
            </div>
            <div className="space-y-1.5">
              <Label>Slug</Label>
              <Input
                value={form.slug}
                onChange={e => set("slug", e.target.value)}
                placeholder="auto-generated"
                className="font-mono text-sm"
              />
            </div>
            <div className="space-y-1.5">
              <Label>Status</Label>
              <Select value={form.status} onValueChange={v => set("status", v)}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {STATUSES.map(s => <SelectItem key={s} value={s}>{s}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>Project status</Label>
              <Select value={form.project_status} onValueChange={v => set("project_status", v)}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {PROJECT_STATUSES.map(s => <SelectItem key={s} value={s}>{s}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>Start date</Label>
              <Input type="date" value={form.start_date} onChange={e => set("start_date", e.target.value)} />
            </div>
            <div className="space-y-1.5">
              <Label>End date</Label>
              <Input type="date" value={form.end_date} onChange={e => set("end_date", e.target.value)} />
            </div>
            <div className="col-span-2 space-y-1.5">
              <Label>Excerpt</Label>
              <Input value={form.excerpt} onChange={e => set("excerpt", e.target.value)} placeholder="Short description…" />
            </div>
            <div className="col-span-2 space-y-1.5">
              <Label>Content (markdown)</Label>
              <Textarea
                value={form.markdown}
                onChange={e => set("markdown", e.target.value)}
                rows={8}
                className="font-mono text-sm resize-y"
                placeholder="# Project description…"
              />
            </div>
          </div>
          <div className="flex items-center gap-2">
            <Checkbox id="proj-public" checked={form.public} onCheckedChange={c => set("public", !!c)} />
            <Label htmlFor="proj-public">Public</Label>
          </div>
          {error && <p className="text-sm text-destructive">{error}</p>}
          <DialogFooter>
            <DialogClose render={<Button type="button" variant="outline" />}>Cancel</DialogClose>
            <Button type="submit" disabled={saving}>
              {saving ? "Saving…" : isEdit ? "Save changes" : "Create project"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

// ─── ProjectsPage ─────────────────────────────────────────────────────────────

export default function ProjectsPage() {
  const queryClient = useQueryClient()
  const [formOpen, setFormOpen] = useState(false)
  const [editProject, setEditProject] = useState<ProjectRecord | null>(null)
  const [deleteProject, setDeleteProject] = useState<ProjectRecord | null>(null)
  const [deleting, setDeleting] = useState(false)

  const { data, isLoading } = useQuery({
    queryKey: ["projects"],
    queryFn: () =>
      pb.collection("projects").getList(1, 500, {
        sort: "-published_at",
        fields: "id,title,slug,status,project_status,public,published_at,start_date,end_date",
      }),
  })

  const projects = data?.items ?? []

  const invalidate = useCallback(() => {
    queryClient.invalidateQueries({ queryKey: ["projects"] })
  }, [queryClient])

  const openCreate = () => {
    setEditProject(null)
    setFormOpen(true)
  }

  const openEdit = (p: ProjectRecord) => {
    setEditProject(p)
    setFormOpen(true)
  }

  const handleDelete = async () => {
    if (!deleteProject) return
    setDeleting(true)
    try {
      await pb.collection("projects").delete(deleteProject.id)
      queryClient.invalidateQueries({ queryKey: ["projects"] })
      toast.success("Project deleted")
    } catch (err: any) {
      toast.error(err?.message ?? "Delete failed")
    } finally {
      setDeleting(false)
      setDeleteProject(null)
    }
  }

  return (
    <div className="p-6 space-y-4 text-foreground">
      <div className="flex items-center justify-end">
        <Button size="sm" variant="secondary" onClick={openCreate}>
          <Plus className="size-3.5 mr-1" />
          New project
        </Button>
      </div>

      <div className="rounded-md border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Title</TableHead>
              <TableHead className="w-28">Status</TableHead>
              <TableHead className="w-28">Project</TableHead>
              <TableHead className="w-20">Public</TableHead>
              <TableHead className="w-36">Published</TableHead>
              <TableHead className="w-10" />
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              Array.from({ length: 6 }).map((_, i) => (
                <TableRow key={i}>
                  {Array.from({ length: 6 }).map((_, j) => (
                    <TableCell key={j}><Skeleton className="h-4 w-full" /></TableCell>
                  ))}
                </TableRow>
              ))
            ) : projects.length === 0 ? (
              <TableRow>
                <TableCell colSpan={6} className="text-center py-12 text-muted-foreground">
                  No projects found.
                </TableCell>
              </TableRow>
            ) : projects.map(p => (
              <TableRow key={p.id} className="hover:bg-muted/50">
                <TableCell className="font-medium">{p.title}</TableCell>
                <TableCell>
                  <Badge variant={p.status === "published" ? "default" : "secondary"} className="capitalize">
                    {p.status}
                  </Badge>
                </TableCell>
                <TableCell>
                  <Badge variant="outline" className="capitalize">{p.project_status}</Badge>
                </TableCell>
                <TableCell>
                  {p.public
                    ? <Badge variant="default">Yes</Badge>
                    : <Badge variant="secondary">No</Badge>}
                </TableCell>
                <TableCell className="text-muted-foreground text-sm">
                  {formatDate(p.published_at as string)}
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
                      <DropdownMenuItem onClick={() => openEdit(p as unknown as ProjectRecord)}>
                        <Pencil className="size-3.5 mr-2" />
                        Edit
                      </DropdownMenuItem>
                      <DropdownMenuItem
                        variant="destructive"
                        onClick={() => setDeleteProject(p as unknown as ProjectRecord)}
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
        <p className="text-xs text-muted-foreground">{projects.length} project{projects.length !== 1 ? "s" : ""}</p>
      )}

      <ProjectFormDialog
        open={formOpen}
        onOpenChange={setFormOpen}
        initial={editProject}
        onSaved={invalidate}
      />

      <Dialog open={!!deleteProject} onOpenChange={open => !open && setDeleteProject(null)}>
        <DialogContent showCloseButton={false}>
          <DialogHeader>
            <DialogTitle>Delete project?</DialogTitle>
            <DialogDescription>
              &ldquo;{deleteProject?.title}&rdquo; will be permanently deleted.
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
