import { useState, useEffect, useRef, useCallback } from "react"
import { useParams, useNavigate, Link } from "react-router-dom"
import { useQuery, useQueryClient } from "@tanstack/react-query"
import { toast } from "sonner"
import { ArrowLeft, PanelRight } from "lucide-react"
import pb from "@/lib/pb"
import PostEditor from "@/components/editor/PostEditor"
import PostSidebar from "@/components/editor/PostSidebar"
import { slugify } from "@/lib/utils"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogClose,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"

export interface PostData {
  id?: string
  title: string
  slug: string
  markdown: string
  excerpt: string
  post_type: string
  status: string
  featured: boolean
  published_at: string
  attribution: string
  attribution_url: string
  tags: string[]
  featured_image: string | null
}

const EMPTY_POST: PostData = {
  title: "",
  slug: "",
  markdown: "",
  excerpt: "",
  post_type: "post",
  status: "draft",
  featured: false,
  published_at: "",
  attribution: "",
  attribution_url: "",
  tags: [],
  featured_image: null,
}

export default function PostEditorPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const isNew = id === "new"

  const [post, setPost] = useState<PostData>(EMPTY_POST)
  const [postId, setPostId] = useState<string | null>(isNew ? null : (id ?? null))
  const [saveStatus, setSaveStatus] = useState<"idle" | "saving" | "saved" | "error">("idle")
  const [sidebarOpen, setSidebarOpen] = useState(true)
  const [slugManuallyEdited, setSlugManuallyEdited] = useState(false)
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)

  // Fetch existing post
  const { data: fetchedPost, isLoading } = useQuery({
    queryKey: ["post", postId],
    queryFn: () => pb.collection("posts").getOne(postId!),
    enabled: !!postId && !isNew,
  })

  // Populate form when post loads
  useEffect(() => {
    if (!fetchedPost) return
    setPost({
      id: fetchedPost.id,
      title: fetchedPost.title ?? "",
      slug: fetchedPost.slug ?? "",
      markdown: fetchedPost.markdown ?? "",
      excerpt: fetchedPost.excerpt ?? "",
      post_type: fetchedPost.post_type ?? "post",
      status: fetchedPost.status ?? "draft",
      featured: fetchedPost.featured ?? false,
      published_at: fetchedPost.published_at
        ? fetchedPost.published_at.slice(0, 16) // datetime-local format
        : "",
      attribution: fetchedPost.attribution ?? "",
      attribution_url: fetchedPost.attribution_url ?? "",
      tags: fetchedPost.expand?.tags?.map((t: any) => t.id) ?? fetchedPost.tags ?? [],
      featured_image: fetchedPost.featured_image ?? null,
    })
    setSlugManuallyEdited(true) // Don't auto-generate slug for existing posts
  }, [fetchedPost])

  // Auto-generate slug from title for new posts
  useEffect(() => {
    if (!isNew || slugManuallyEdited) return
    setPost(p => ({ ...p, slug: slugify(p.title) }))
  }, [post.title, isNew, slugManuallyEdited])

  const saveTimerRef = useRef<ReturnType<typeof setTimeout>>(undefined)
  // Stable fallback slug for untitled posts — generated once per editor session
  const fallbackSlugRef = useRef(`untitled-${Date.now()}`)

  const buildPayload = useCallback((data: PostData) => {
    const title = data.title.trim() || "Untitled"
    const slug = data.slug.trim() || fallbackSlugRef.current
    const payload: Record<string, any> = {
      title,
      slug,
      markdown: data.markdown,
      excerpt: data.excerpt,
      post_type: data.post_type,
      status: data.status,
      featured: data.featured,
      attribution: data.attribution,
      attribution_url: data.attribution_url,
      tags: data.tags,
    }
    if (data.published_at) {
      payload.published_at = new Date(data.published_at).toISOString()
    } else {
      payload.published_at = null
    }
    return payload
  }, [])

  // After saving, remove any content_images that are no longer referenced in the markdown.
  // PocketBase supports `'field-': ['filename']` to delete specific files from a multi-file field.
  const syncContentImages = useCallback(async (
    pid: string,
    markdown: string,
    savedImages: string[],
  ) => {
    if (!savedImages.length) return
    // Extract filenames of images that ARE referenced in the markdown
    const regex = /!\[.*?\]\(([^)]+)\)/g
    const referencedUrls = new Set<string>()
    let m: RegExpExecArray | null
    while ((m = regex.exec(markdown)) !== null) {
      referencedUrls.add(m[1])
    }
    // A content_image is "in use" if its filename appears in any image URL
    const toRemove = savedImages.filter(filename => {
      return ![...referencedUrls].some(url => url.includes(filename))
    })
    if (!toRemove.length) return
    await pb.collection("posts").update(pid, { "content_images-": toRemove })
  }, [])

  const save = useCallback(async (data: PostData, currentPostId: string | null) => {
    if (!data.title && !data.markdown) return null
    setSaveStatus("saving")
    try {
      let record
      if (currentPostId) {
        record = await pb.collection("posts").update(currentPostId, buildPayload(data))
      } else {
        record = await pb.collection("posts").create(buildPayload(data))
        setPostId(record.id)
        navigate(`/posts/${record.id}`, { replace: true })
        toast.success("Draft created")
      }
      setSaveStatus("saved")
      queryClient.invalidateQueries({ queryKey: ["posts"] })
      setTimeout(() => setSaveStatus("idle"), 2000)
      // Sync content_images: remove any no longer referenced in the markdown
      const savedImages = (record.content_images ?? []) as string[]
      syncContentImages(record.id, data.markdown, savedImages)
      return record
    } catch (err: any) {
      setSaveStatus("error")
      toast.error(err?.message ?? "Save failed")
      return null
    }
  }, [buildPayload, navigate, queryClient, syncContentImages])

  const scheduleSave = useCallback((data: PostData, currentPostId: string | null) => {
    if (data.status !== "draft") return
    clearTimeout(saveTimerRef.current)
    setSaveStatus("saving") // Optimistic
    saveTimerRef.current = setTimeout(() => {
      save(data, currentPostId)
    }, 1500)
  }, [save])

  const updatePost = useCallback((updates: Partial<PostData>) => {
    setPost(prev => {
      const next = { ...prev, ...updates }
      scheduleSave(next, postId)
      return next
    })
  }, [scheduleSave, postId])

  const handleContentChange = useCallback((markdown: string) => {
    setPost(prev => {
      const next = { ...prev, markdown }
      scheduleSave(next, postId)
      return next
    })
  }, [scheduleSave, postId])

  // Ensure we have a post ID before uploading images
  const ensurePostExists = useCallback(async (): Promise<string | null> => {
    if (postId) return postId
    const data = post
    if (!data.title && !data.markdown) return null
    const record = await pb.collection("posts").create({
      ...buildPayload(data),
      status: "draft",
    })
    setPostId(record.id)
    navigate(`/posts/${record.id}`, { replace: true })
    toast.success("Draft created")
    return record.id
  }, [postId, post, buildPayload, navigate])

  const handleManualSave = useCallback(async () => {
    clearTimeout(saveTimerRef.current)
    await save(post, postId)
  }, [save, post, postId])

  const handleDelete = useCallback(async () => {
    if (!postId) return
    try {
      await pb.collection("posts").delete(postId)
      queryClient.invalidateQueries({ queryKey: ["posts"] })
      toast.success("Post deleted")
      navigate("/posts")
    } catch (err: any) {
      toast.error(err?.message ?? "Delete failed")
    }
  }, [postId, queryClient, navigate])

  if (!isNew && isLoading) {
    return (
      <div className="flex items-center justify-center h-full text-muted-foreground text-sm">
        Loading…
      </div>
    )
  }

  return (
    <div className="flex flex-col h-full">
      {/* Top bar */}
      <div className="flex items-center gap-3 px-4 h-11 border-b shrink-0">
        <Link
          to="/posts"
          className="flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground transition-colors"
        >
          <ArrowLeft className="size-3.5" />
          Posts
        </Link>
        <span className="text-muted-foreground/40">·</span>
        <span className="text-xs text-muted-foreground">
          {saveStatus === "saving" && "Saving…"}
          {saveStatus === "saved" && "Saved"}
          {saveStatus === "error" && "Save failed"}
          {saveStatus === "idle" && (postId ? "All changes saved" : "Unsaved")}
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
          {/* Title */}
          <div className="px-12 pt-10 pb-2">
            <input
              type="text"
              placeholder="Title"
              value={post.title}
              onChange={e => updatePost({ title: e.target.value })}
              className="w-full text-3xl font-bold bg-transparent border-none outline-none placeholder:text-muted-foreground/40 text-foreground"
            />
          </div>

          {/* TipTap editor */}
          <div className="flex-1 px-12 pb-12">
            <PostEditor
              content={post.markdown}
              onChange={handleContentChange}
              postId={postId}
              ensurePostExists={ensurePostExists}
            />
          </div>

          {/* Danger zone */}
          {postId && (
            <div className="px-12 pb-12 pt-4 border-t border-dashed border-border/50">
              <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
                <button
                  onClick={() => setDeleteDialogOpen(true)}
                  className="text-xs text-muted-foreground/50 hover:text-destructive transition-colors"
                >
                  Delete this post…
                </button>
                <DialogContent showCloseButton={false}>
                  <DialogHeader>
                    <DialogTitle>Delete post?</DialogTitle>
                    <DialogDescription>
                      This cannot be undone. The post will be permanently deleted.
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
          <PostSidebar
            post={post}
            postId={postId}
            onChange={updatePost}
            onSlugEdit={() => setSlugManuallyEdited(true)}
          />
        )}
      </div>
    </div>
  )
}
