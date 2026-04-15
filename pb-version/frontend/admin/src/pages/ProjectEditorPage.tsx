import { useState, useEffect, useRef, useCallback } from "react"
import { useParams, useNavigate, Link } from "react-router-dom"
import { useQuery, useQueryClient } from "@tanstack/react-query"
import { toast } from "sonner"
import { ArrowLeft, PanelRight, ImageIcon, X, Plus, Trash2 } from "lucide-react"
import pb from "@/lib/pb"
import PostEditor from "@/components/editor/PostEditor"
import { Button } from "@/components/ui/button"
import { Separator } from "@/components/ui/separator"
import { Checkbox } from "@/components/ui/checkbox"
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

export interface ProjectData {
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

function Label({ children }: { children: React.ReactNode }) {
  return <label className="block text-xs font-medium text-muted-foreground mb-1">{children}</label>
}

function Field({ children }: { children: React.ReactNode }) {
  return <div className="space-y-1">{children}</div>
}

function SidebarInput({
  value, onChange, placeholder,
}: { value: string; onChange: (v: string) => void; placeholder?: string }) {
  return (
    <input
      value={value}
      onChange={e => onChange(e.target.value)}
      placeholder={placeholder}
      className="w-full px-2 py-1.5 text-sm bg-transparent border border-input rounded-md outline-none focus:border-ring focus:ring-2 focus:ring-ring/30 placeholder:text-muted-foreground/50"
    />
  )
}

function ProjectSidebar({ project, projectId, onChange, saveStatus, onSave, onDelete }: SidebarProps) {
  const featuredInputRef = useRef<HTMLInputElement>(null)
  const contentInputRef = useRef<HTMLInputElement>(null)
  const [uploadingFeatured, setUploadingFeatured] = useState(false)
  const [uploadingContent, setUploadingContent] = useState(false)

  const handleFeaturedChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file || !projectId) return
    setUploadingFeatured(true)
    try {
      const fd = new FormData()
      fd.append("featured_image", file)
      await pb.collection("projects").update(projectId, fd)
      onChange({ featured_image: file.name })
      toast.success("Featured image uploaded")
    } catch (err: any) {
      toast.error(err?.message ?? "Upload failed")
    } finally {
      setUploadingFeatured(false)
    }
  }

  const handleClearFeatured = async () => {
    if (!projectId || !project.featured_image) return
    try {
      await pb.collection("projects").update(projectId, { "featured_image-": [project.featured_image] })
      onChange({ featured_image: null })
    } catch (err: any) {
      toast.error(err?.message ?? "Remove failed")
    }
  }

  const handleContentImagesChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files
    if (!files || !projectId) return
    setUploadingContent(true)
    try {
      const fd = new FormData()
      for (const f of Array.from(files)) fd.append("content_images", f)
      const updated = await pb.collection("projects").update(projectId, fd)
      onChange({ content_images: updated.content_images ?? [] })
      toast.success(`${files.length} image${files.length > 1 ? "s" : ""} uploaded`)
    } catch (err: any) {
      toast.error(err?.message ?? "Upload failed")
    } finally {
      setUploadingContent(false)
      if (contentInputRef.current) contentInputRef.current.value = ""
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
          <button
            onClick={onSave}
            disabled={saveStatus === "saving"}
            className="flex-1 text-xs px-2.5 py-1 rounded-md bg-primary text-primary-foreground hover:bg-primary/90 disabled:opacity-50 transition-colors"
          >
            {saveStatus === "saving" ? "Saving…" : saveStatus === "saved" ? "Saved ✓" : "Save"}
          </button>
          {projectId && (
            <button
              onClick={onDelete}
              className="text-xs px-2.5 py-1 rounded-md border border-destructive text-destructive hover:bg-destructive hover:text-destructive-foreground transition-colors"
            >
              <Trash2 className="size-3.5" />
            </button>
          )}
        </div>

        <Separator />

        {/* Metadata */}
        <Field>
          <Label>Slug</Label>
          <SidebarInput
            value={project.slug}
            onChange={v => onChange({ slug: v })}
            placeholder="auto-generated"
          />
        </Field>
        <Field>
          <Label>Excerpt</Label>
          <SidebarInput
            value={project.excerpt}
            onChange={v => onChange({ excerpt: v })}
            placeholder="Short description…"
          />
        </Field>

        <Separator />

        <Field>
          <Label>Publish status</Label>
          <Select value={project.status} onValueChange={v => onChange({ status: v })}>
            <SelectTrigger className="h-8 text-sm"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="draft">Draft</SelectItem>
              <SelectItem value="published">Published</SelectItem>
            </SelectContent>
          </Select>
        </Field>

        <Field>
          <Label>Project status</Label>
          <Select value={project.project_status} onValueChange={v => onChange({ project_status: v })}>
            <SelectTrigger className="h-8 text-sm"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="ongoing">Ongoing</SelectItem>
              <SelectItem value="hiatus">Hiatus</SelectItem>
              <SelectItem value="completed">Completed</SelectItem>
            </SelectContent>
          </Select>
        </Field>

        <div className="flex items-center gap-2">
          <Checkbox
            id="proj-public"
            checked={project.public}
            onCheckedChange={c => onChange({ public: !!c })}
          />
          <label htmlFor="proj-public" className="text-sm cursor-pointer">Public</label>
        </div>

        <Separator />

        <Field>
          <Label>Start date</Label>
          <DatePicker value={project.start_date} onChange={v => onChange({ start_date: v })} />
        </Field>
        <Field>
          <Label>End date</Label>
          <DatePicker value={project.end_date} onChange={v => onChange({ end_date: v })} />
        </Field>

        <Separator />

        {/* Featured image */}
        <Field>
          <Label>Featured image</Label>
          {featuredThumb && (
            <div className="relative w-full mb-2">
              <img src={featuredThumb} alt="Featured" className="w-full rounded-md object-cover border max-h-36" />
              <button
                type="button"
                onClick={handleClearFeatured}
                className="absolute top-1 right-1 bg-background/80 border rounded-full p-0.5 shadow hover:bg-muted transition-colors"
              >
                <X className="size-3" />
              </button>
            </div>
          )}
          {projectId ? (
            <label className="flex items-center gap-1.5 w-fit cursor-pointer">
              <span className="text-xs px-2 py-1 rounded border border-input hover:bg-muted transition-colors flex items-center gap-1.5">
                <ImageIcon className="size-3" />
                {uploadingFeatured ? "Uploading…" : featuredThumb ? "Replace" : "Upload"}
              </span>
              <input ref={featuredInputRef} type="file" accept="image/*" className="sr-only"
                onChange={handleFeaturedChange} disabled={uploadingFeatured} />
            </label>
          ) : (
            <p className="text-xs text-muted-foreground">Save first to upload images</p>
          )}
        </Field>

        <Separator />

        {/* Content images */}
        <Field>
          <Label>Content images</Label>
          {project.content_images.length > 0 && (
            <div className="space-y-1.5 mb-2">
              {project.content_images.map(filename => {
                const url = projectId ? fileUrl("projects", projectId, filename) : null
                return (
                  <div key={filename} className="flex items-center gap-2 group">
                    {url && <img src={url} alt={filename} className="h-7 w-7 rounded object-cover border shrink-0" />}
                    <span className="text-xs text-muted-foreground truncate flex-1 min-w-0">{filename}</span>
                    <button
                      type="button"
                      onClick={() => handleRemoveContentImage(filename)}
                      className="opacity-0 group-hover:opacity-100 p-0.5 rounded hover:bg-muted text-muted-foreground transition-all"
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
              <span className="text-xs px-2 py-1 rounded border border-input hover:bg-muted transition-colors flex items-center gap-1.5">
                <Plus className="size-3" />
                {uploadingContent ? "Uploading…" : "Add images"}
              </span>
              <input ref={contentInputRef} type="file" accept="image/*" multiple className="sr-only"
                onChange={handleContentImagesChange} disabled={uploadingContent} />
            </label>
          ) : (
            <p className="text-xs text-muted-foreground">Save first to upload images</p>
          )}
        </Field>

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
  const [saveStatus, setSaveStatus] = useState<"idle" | "saving" | "saved" | "error">("idle")
  const [sidebarOpen, setSidebarOpen] = useState(true)
  const [slugManuallyEdited, setSlugManuallyEdited] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)

  const saveTimerRef = useRef<ReturnType<typeof setTimeout>>(undefined)
  const fallbackSlugRef = useRef(`project-${Date.now()}`)

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
    slug: data.slug.trim() || fallbackSlugRef.current,
    excerpt: data.excerpt.trim() || null,
    markdown: data.markdown,
    status: data.status,
    project_status: data.project_status,
    public: data.public,
    start_date: data.start_date || null,
    end_date: data.end_date || null,
  }), [])

  const save = useCallback(async (data: ProjectData, currentId: string | null) => {
    if (!data.title && !data.markdown) return null
    setSaveStatus("saving")
    try {
      let record
      if (currentId) {
        record = await pb.collection("projects").update(currentId, buildPayload(data))
      } else {
        record = await pb.collection("projects").create(buildPayload(data))
        setProjectId(record.id)
        navigate(`/projects/${record.id}`, { replace: true })
        toast.success("Project created")
      }
      setSaveStatus("saved")
      queryClient.invalidateQueries({ queryKey: ["projects"] })
      setTimeout(() => setSaveStatus("idle"), 2000)
      return record
    } catch (err: any) {
      setSaveStatus("error")
      toast.error(err?.message ?? "Save failed")
      return null
    }
  }, [buildPayload, navigate, queryClient])

  const scheduleSave = useCallback((data: ProjectData, currentId: string | null) => {
    if (data.status !== "draft") return
    clearTimeout(saveTimerRef.current)
    setSaveStatus("saving")
    saveTimerRef.current = setTimeout(() => save(data, currentId), 1500)
  }, [save])

  const updateProject = useCallback((updates: Partial<ProjectData>) => {
    setProject(prev => {
      const next = { ...prev, ...updates }
      scheduleSave(next, projectId)
      return next
    })
  }, [scheduleSave, projectId])

  const handleContentChange = useCallback((markdown: string) => {
    setProject(prev => {
      const next = { ...prev, markdown }
      scheduleSave(next, projectId)
      return next
    })
  }, [scheduleSave, projectId])

  const ensureProjectExists = useCallback(async (): Promise<string | null> => {
    if (projectId) return projectId
    const data = project
    if (!data.title && !data.markdown) return null
    const record = await pb.collection("projects").create({ ...buildPayload(data), status: "draft" })
    setProjectId(record.id)
    navigate(`/projects/${record.id}`, { replace: true })
    toast.success("Project created")
    return record.id
  }, [projectId, project, buildPayload, navigate])

  const handleManualSave = useCallback(async () => {
    clearTimeout(saveTimerRef.current)
    await save(project, projectId)
  }, [save, project, projectId])

  const handleDelete = useCallback(async () => {
    if (!projectId) return
    try {
      await pb.collection("projects").delete(projectId)
      queryClient.invalidateQueries({ queryKey: ["projects"] })
      toast.success("Project deleted")
      navigate("/projects")
    } catch (err: any) {
      toast.error(err?.message ?? "Delete failed")
    }
  }, [projectId, queryClient, navigate])

  if (!isNew && isLoading) {
    return <div className="flex items-center justify-center h-full text-muted-foreground text-sm">Loading…</div>
  }

  return (
    <div className="flex flex-col h-full">
      {/* Top bar */}
      <div className="flex items-center gap-3 px-4 h-11 border-b shrink-0">
        <Link
          to="/projects"
          className="flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground transition-colors"
        >
          <ArrowLeft className="size-3.5" />
          Projects
        </Link>
        <span className="text-muted-foreground/40">·</span>
        <span className="text-xs text-muted-foreground">
          {saveStatus === "saving" && "Saving…"}
          {saveStatus === "saved" && "Saved"}
          {saveStatus === "error" && "Save failed"}
          {saveStatus === "idle" && (projectId ? "All changes saved" : "Unsaved")}
        </span>
        <div className="flex-1" />
        <button
          onClick={handleManualSave}
          className="text-xs px-2.5 py-1 rounded-md bg-primary text-primary-foreground hover:bg-primary/90 transition-colors"
        >
          Save
        </button>
        <button
          onClick={() => setSidebarOpen(o => !o)}
          className="p-1.5 rounded-md hover:bg-muted transition-colors text-muted-foreground"
          title="Toggle sidebar"
        >
          <PanelRight className="size-4" />
        </button>
      </div>

      {/* Body */}
      <div className="flex flex-1 min-h-0">
        {/* Editor area */}
        <div className="flex-1 flex flex-col min-w-0 overflow-auto max-w-3xl mx-auto mt-8">
          <div className="px-12 pt-10 pb-2">
            <input
              type="text"
              placeholder="Project title"
              value={project.title}
              onChange={e => updateProject({ title: e.target.value })}
              className="w-full text-3xl font-bold bg-transparent border-none outline-none placeholder:text-muted-foreground/40 text-foreground"
            />
          </div>
          <div className="flex-1 px-12 pb-12">
            <PostEditor
              content={project.markdown}
              onChange={handleContentChange}
              postId={projectId}
              ensurePostExists={ensureProjectExists}
              collection="projects"
            />
          </div>

          {/* Danger zone */}
          {projectId && (
            <div className="px-12 pb-12 pt-4 border-t border-dashed border-border/50">
              <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
                <button
                  onClick={() => setDeleteDialogOpen(true)}
                  className="text-xs text-muted-foreground/50 hover:text-destructive transition-colors"
                >
                  Delete this project…
                </button>
                <DialogContent showCloseButton={false}>
                  <DialogHeader>
                    <DialogTitle>Delete project?</DialogTitle>
                    <DialogDescription>
                      This cannot be undone. The project will be permanently deleted.
                    </DialogDescription>
                  </DialogHeader>
                  <DialogFooter>
                    <DialogClose render={<Button variant="outline" />}>Cancel</DialogClose>
                    <Button variant="destructive" onClick={handleDelete}>Delete</Button>
                  </DialogFooter>
                </DialogContent>
              </Dialog>
            </div>
          )}
        </div>

        {/* Sidebar */}
        {sidebarOpen && (
          <ProjectSidebar
            project={project}
            projectId={projectId}
            onChange={updates => setProject(p => ({ ...p, ...updates }))}
            saveStatus={saveStatus}
            onSave={handleManualSave}
            onDelete={() => setDeleteDialogOpen(true)}
          />
        )}
      </div>
    </div>
  )
}
