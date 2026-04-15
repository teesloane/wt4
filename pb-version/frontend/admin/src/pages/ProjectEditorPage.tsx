import { useState, useEffect, useCallback, useRef } from "react"
import { useParams, useNavigate, Link } from "react-router-dom"
import { useQuery, useQueryClient } from "@tanstack/react-query"
import { toast } from "sonner"
import { ArrowLeft, ImageIcon, X, Plus, Trash2 } from "lucide-react"
import pb from "@/lib/pb"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Checkbox } from "@/components/ui/checkbox"
import { Separator } from "@/components/ui/separator"
import { Textarea } from "@/components/ui/textarea"
import {
  Select, SelectTrigger, SelectContent, SelectItem, SelectValue,
} from "@/components/ui/select"
import DatePicker from "@/components/editor/DatePicker"
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

interface ProjectData {
  title: string
  slug: string
  excerpt: string
  markdown: string
  status: string
  project_status: string
  public: boolean
  start_date: string
  end_date: string
  featured_image: string | null
  content_images: string[]
}

const EMPTY: ProjectData = {
  title: "", slug: "", excerpt: "", markdown: "",
  status: "draft", project_status: "ongoing",
  public: false, start_date: "", end_date: "",
  featured_image: null, content_images: [],
}

function toSlug(s: string) {
  return s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
}

function fileUrl(collection: string, recordId: string, filename: string, thumb?: string) {
  if (!filename) return null
  const q = thumb ? `?thumb=${thumb}` : ""
  return `/api/files/${collection}/${recordId}/${filename}${q}`
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────

interface SidebarProps {
  project: ProjectData
  projectId: string | null
  onChange: (updates: Partial<ProjectData>) => void
  saveStatus: "idle" | "saving" | "saved" | "error"
  onSave: () => void
  onDelete: () => void
}

function ProjectSidebar({ project, projectId, onChange, saveStatus, onSave, onDelete }: SidebarProps) {
  const fileInputRef = useRef<HTMLInputElement>(null)
  const contentImagesInputRef = useRef<HTMLInputElement>(null)
  const [uploadingFeatured, setUploadingFeatured] = useState(false)
  const [uploadingContent, setUploadingContent] = useState(false)

  const handleFeaturedImageChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file || !projectId) return
    setUploadingFeatured(true)
    try {
      const formData = new FormData()
      formData.append("featured_image", file)
      await pb.collection("projects").update(projectId, formData)
      onChange({ featured_image: file.name })
      toast.success("Featured image uploaded")
    } catch (err: any) {
      toast.error(err?.message ?? "Upload failed")
    } finally {
      setUploadingFeatured(false)
    }
  }

  const handleClearFeaturedImage = async () => {
    if (!projectId || !project.featured_image) return
    try {
      await pb.collection("projects").update(projectId, { "featured_image-": [project.featured_image] })
      onChange({ featured_image: null })
      toast.success("Image removed")
    } catch (err: any) {
      toast.error(err?.message ?? "Remove failed")
    }
  }

  const handleContentImagesChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files
    if (!files || !projectId) return
    setUploadingContent(true)
    try {
      const formData = new FormData()
      for (const file of Array.from(files)) {
        formData.append("content_images", file)
      }
      const updated = await pb.collection("projects").update(projectId, formData)
      onChange({ content_images: updated.content_images ?? [] })
      toast.success(`${files.length} image${files.length > 1 ? "s" : ""} uploaded`)
    } catch (err: any) {
      toast.error(err?.message ?? "Upload failed")
    } finally {
      setUploadingContent(false)
      if (contentImagesInputRef.current) contentImagesInputRef.current.value = ""
    }
  }

  const handleRemoveContentImage = async (filename: string) => {
    if (!projectId) return
    try {
      await pb.collection("projects").update(projectId, { "content_images-": [filename] })
      onChange({ content_images: project.content_images.filter(f => f !== filename) })
    } catch (err: any) {
      toast.error(err?.message ?? "Remove failed")
    }
  }

  const featuredThumb = projectId && project.featured_image
    ? fileUrl("projects", projectId, project.featured_image, "400x0")
    : null

  return (
    <aside className="w-72 shrink-0 border-l bg-background overflow-y-auto">
      <div className="p-4 space-y-4">

        {/* Save / Delete */}
        <div className="flex gap-2">
          <Button
            size="sm"
            className="flex-1"
            onClick={onSave}
            disabled={saveStatus === "saving"}
          >
            {saveStatus === "saving" ? "Saving…" : saveStatus === "saved" ? "Saved ✓" : "Save"}
          </Button>
          {projectId && (
            <Button size="sm" variant="destructive" onClick={onDelete}>
              <Trash2 className="size-3.5" />
            </Button>
          )}
        </div>

        <Separator />

        {/* Status */}
        <div className="space-y-1.5">
          <Label className="text-xs text-muted-foreground uppercase tracking-wide">Publish status</Label>
          <Select value={project.status} onValueChange={v => onChange({ status: v })}>
            <SelectTrigger className="h-8 text-sm"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="draft">Draft</SelectItem>
              <SelectItem value="published">Published</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div className="space-y-1.5">
          <Label className="text-xs text-muted-foreground uppercase tracking-wide">Project status</Label>
          <Select value={project.project_status} onValueChange={v => onChange({ project_status: v })}>
            <SelectTrigger className="h-8 text-sm"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="ongoing">Ongoing</SelectItem>
              <SelectItem value="hiatus">Hiatus</SelectItem>
              <SelectItem value="completed">Completed</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div className="flex items-center gap-2">
          <Checkbox
            id="proj-public"
            checked={project.public}
            onCheckedChange={c => onChange({ public: !!c })}
          />
          <Label htmlFor="proj-public" className="text-sm">Public</Label>
        </div>

        <Separator />

        {/* Dates */}
        <div className="space-y-1.5">
          <Label className="text-xs text-muted-foreground uppercase tracking-wide">Start date</Label>
          <DatePicker value={project.start_date} onChange={v => onChange({ start_date: v })} />
        </div>
        <div className="space-y-1.5">
          <Label className="text-xs text-muted-foreground uppercase tracking-wide">End date</Label>
          <DatePicker value={project.end_date} onChange={v => onChange({ end_date: v })} />
        </div>

        <Separator />

        {/* Featured image */}
        <div className="space-y-2">
          <Label className="text-xs text-muted-foreground uppercase tracking-wide">Featured image</Label>
          {featuredThumb && (
            <div className="relative w-full">
              <img
                src={featuredThumb}
                alt="Featured"
                className="w-full rounded-md object-cover border max-h-40"
              />
              <button
                type="button"
                onClick={handleClearFeaturedImage}
                className="absolute top-1 right-1 bg-background/80 border rounded-full p-0.5 shadow hover:bg-muted transition-colors"
                title="Remove"
              >
                <X className="size-3" />
              </button>
            </div>
          )}
          {projectId ? (
            <label className="flex items-center gap-1.5 w-fit cursor-pointer">
              <span className="text-xs px-2.5 py-1.5 rounded-md border border-input hover:bg-muted transition-colors flex items-center gap-1.5">
                <ImageIcon className="size-3" />
                {uploadingFeatured ? "Uploading…" : featuredThumb ? "Replace" : "Upload"}
              </span>
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                className="sr-only"
                onChange={handleFeaturedImageChange}
                disabled={uploadingFeatured}
              />
            </label>
          ) : (
            <p className="text-xs text-muted-foreground">Save first to upload images</p>
          )}
        </div>

        <Separator />

        {/* Content images */}
        <div className="space-y-2">
          <Label className="text-xs text-muted-foreground uppercase tracking-wide">Content images</Label>
          {project.content_images.length > 0 && (
            <div className="space-y-1.5">
              {project.content_images.map(filename => {
                const url = projectId ? fileUrl("projects", projectId, filename) : null
                return (
                  <div key={filename} className="flex items-center gap-2 group">
                    {url && (
                      <img
                        src={url}
                        alt={filename}
                        className="h-8 w-8 rounded object-cover border shrink-0"
                      />
                    )}
                    <span className="text-xs text-muted-foreground truncate flex-1 min-w-0">{filename}</span>
                    <button
                      type="button"
                      onClick={() => handleRemoveContentImage(filename)}
                      className="opacity-0 group-hover:opacity-100 p-0.5 rounded hover:bg-muted transition-all text-muted-foreground hover:text-foreground"
                      title="Remove"
                    >
                      <X className="size-3" />
                    </button>
                  </div>
                )
              })}
            </div>
          )}
          {projectId ? (
            <label className="flex items-center gap-1.5 w-fit cursor-pointer">
              <span className="text-xs px-2.5 py-1.5 rounded-md border border-input hover:bg-muted transition-colors flex items-center gap-1.5">
                <Plus className="size-3" />
                {uploadingContent ? "Uploading…" : "Add images"}
              </span>
              <input
                ref={contentImagesInputRef}
                type="file"
                accept="image/*"
                multiple
                className="sr-only"
                onChange={handleContentImagesChange}
                disabled={uploadingContent}
              />
            </label>
          ) : (
            <p className="text-xs text-muted-foreground">Save first to upload images</p>
          )}
        </div>

      </div>
    </aside>
  )
}

// ─── ProjectEditorPage ────────────────────────────────────────────────────────

export default function ProjectEditorPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const isNew = id === "new"

  const [project, setProject] = useState<ProjectData>(EMPTY)
  const [projectId, setProjectId] = useState<string | null>(isNew ? null : (id ?? null))
  // useQuery needs string | undefined, not null
  const queryId = projectId ?? undefined
  const [saveStatus, setSaveStatus] = useState<"idle" | "saving" | "saved" | "error">("idle")
  const [slugManuallyEdited, setSlugManuallyEdited] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)

  const { data: fetched, isLoading } = useQuery({
    queryKey: ["project", projectId],
    queryFn: () => pb.collection("projects").getOne(projectId!),
    enabled: !!projectId && !isNew,
  })

  useEffect(() => {
    if (!fetched) return
    setProject({
      title: fetched.title ?? "",
      slug: fetched.slug ?? "",
      excerpt: fetched.excerpt ?? "",
      markdown: fetched.markdown ?? "",
      status: fetched.status ?? "draft",
      project_status: fetched.project_status ?? "ongoing",
      public: fetched.public ?? false,
      start_date: fetched.start_date ?? "",
      end_date: fetched.end_date ?? "",
      featured_image: fetched.featured_image ?? null,
      content_images: fetched.content_images ?? [],
    })
    setSlugManuallyEdited(true)
  }, [fetched])

  // Auto-generate slug for new projects
  useEffect(() => {
    if (!isNew || slugManuallyEdited) return
    setProject(p => ({ ...p, slug: toSlug(p.title) }))
  }, [project.title, isNew, slugManuallyEdited])

  const buildPayload = useCallback((data: ProjectData) => ({
    title: data.title.trim() || "Untitled",
    slug: data.slug.trim() || toSlug(data.title.trim()) || `project-${Date.now()}`,
    excerpt: data.excerpt.trim() || null,
    markdown: data.markdown,
    status: data.status,
    project_status: data.project_status,
    public: data.public,
    start_date: data.start_date || null,
    end_date: data.end_date || null,
  }), [])

  const save = useCallback(async () => {
    setSaveStatus("saving")
    try {
      let record
      if (projectId) {
        record = await pb.collection("projects").update(projectId, buildPayload(project))
      } else {
        record = await pb.collection("projects").create(buildPayload(project))
        setProjectId(record.id)
        navigate(`/projects/${record.id}`, { replace: true })
        toast.success("Project created")
      }
      setSaveStatus("saved")
      queryClient.invalidateQueries({ queryKey: ["projects"] })
      setTimeout(() => setSaveStatus("idle"), 2000)
    } catch (err: any) {
      setSaveStatus("error")
      toast.error(err?.message ?? "Save failed")
    }
  }, [project, projectId, buildPayload, navigate, queryClient])

  const handleDelete = async () => {
    if (!projectId) return
    try {
      await pb.collection("projects").delete(projectId)
      queryClient.invalidateQueries({ queryKey: ["projects"] })
      toast.success("Project deleted")
      navigate("/projects")
    } catch (err: any) {
      toast.error(err?.message ?? "Delete failed")
    }
  }

  if (!isNew && isLoading) {
    return <div className="p-6 text-muted-foreground text-sm">Loading…</div>
  }

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center gap-3 border-b px-4 py-2 shrink-0">
        <Link
          to="/projects"
          className="p-1 rounded hover:bg-muted transition-colors text-muted-foreground"
        >
          <ArrowLeft className="size-4" />
        </Link>
        <span className="text-sm font-medium text-muted-foreground">
          {isNew ? "New project" : (project.title || "Untitled")}
        </span>
        {saveStatus === "saved" && (
          <span className="text-xs text-muted-foreground ml-auto">Saved ✓</span>
        )}
        {saveStatus === "error" && (
          <span className="text-xs text-destructive ml-auto">Save failed</span>
        )}
      </div>

      {/* Body */}
      <div className="flex flex-1 overflow-hidden">
        {/* Editor area */}
        <div className="flex-1 overflow-y-auto p-6 space-y-4">
          <Input
            value={project.title}
            onChange={e => setProject(p => ({ ...p, title: e.target.value }))}
            placeholder="Project title"
            className="text-2xl font-semibold h-auto py-2 border-none shadow-none px-0 focus-visible:ring-0 placeholder:text-muted-foreground/40"
          />
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1">
              <Label className="text-xs text-muted-foreground">Slug</Label>
              <Input
                value={project.slug}
                onChange={e => {
                  setSlugManuallyEdited(true)
                  setProject(p => ({ ...p, slug: e.target.value }))
                }}
                placeholder="auto-generated"
                className="font-mono text-sm h-8"
              />
            </div>
            <div className="space-y-1">
              <Label className="text-xs text-muted-foreground">Excerpt</Label>
              <Input
                value={project.excerpt}
                onChange={e => setProject(p => ({ ...p, excerpt: e.target.value }))}
                placeholder="Short description…"
                className="h-8"
              />
            </div>
          </div>
          <div className="space-y-1">
            <Label className="text-xs text-muted-foreground">Content (markdown)</Label>
            <Textarea
              value={project.markdown}
              onChange={e => setProject(p => ({ ...p, markdown: e.target.value }))}
              placeholder="# Project description…"
              className="font-mono text-sm min-h-[400px] resize-y"
            />
          </div>
        </div>

        {/* Sidebar */}
        <ProjectSidebar
          project={project}
          projectId={projectId}
          onChange={updates => setProject(p => ({ ...p, ...updates }))}
          saveStatus={saveStatus}
          onSave={save}
          onDelete={() => setDeleteDialogOpen(true)}
        />
      </div>

      {/* Delete confirmation */}
      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent showCloseButton={false}>
          <DialogHeader>
            <DialogTitle>Delete project?</DialogTitle>
            <DialogDescription>
              &ldquo;{project.title || "Untitled"}&rdquo; will be permanently deleted.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <DialogClose render={<Button variant="outline" />}>Cancel</DialogClose>
            <Button variant="destructive" onClick={handleDelete}>Delete</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
