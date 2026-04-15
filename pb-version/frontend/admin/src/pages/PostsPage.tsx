import { useState, useCallback } from "react"
import { useQuery, useQueryClient } from "@tanstack/react-query"
import { useNavigate } from "react-router-dom"
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Skeleton } from "@/components/ui/skeleton"
import { Button } from "@/components/ui/button"
import { Plus, MoreHorizontal, Trash2 } from "lucide-react"
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

const TYPE_FILTERS = [
  { label: "All",     value: "" },
  { label: "Post",    value: "post" },
  { label: "TIL",     value: "til" },
  { label: "Quote",   value: "quote" },
  { label: "Update",  value: "update" },
  { label: "Fiction", value: "fiction" },
]

const STATUS_FILTERS = [
  { label: "All",       value: "" },
  { label: "Published", value: "published" },
  { label: "Draft",     value: "draft" },
]

function buildFilter(type: string, status: string) {
  const parts: string[] = []
  if (type)   parts.push(`post_type='${type}'`)
  if (status) parts.push(`status='${status}'`)
  return parts.join(" && ") || undefined
}

function FilterBar({ filters, active, onChange }: {
  filters: { label: string; value: string }[]
  active: string
  onChange: (v: string) => void
}) {
  return (
    <div className="flex flex-wrap gap-1.5">
      {filters.map(f => (
        <button
          key={f.value}
          onClick={() => onChange(f.value)}
          className={[
            "px-3 py-1 rounded-md text-sm font-medium transition-colors",
            active === f.value
              ? "bg-primary text-primary-foreground"
              : "bg-muted text-muted-foreground hover:bg-muted/80",
          ].join(" ")}
        >
          {f.label}
        </button>
      ))}
    </div>
  )
}

function formatDate(str: string | null) {
  if (!str) return "—"
  return new Date(str).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" })
}

export default function PostsPage() {
  const [type, setType] = useState("")
  const [status, setStatus] = useState("")
  const [postToDelete, setPostToDelete] = useState<{ id: string; title: string } | null>(null)
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const handleDelete = useCallback(async () => {
    if (!postToDelete) return
    try {
      await pb.collection("posts").delete(postToDelete.id)
      queryClient.invalidateQueries({ queryKey: ["posts"] })
      toast.success("Post deleted")
    } catch (err: any) {
      toast.error(err?.message ?? "Delete failed")
    } finally {
      setPostToDelete(null)
    }
  }, [postToDelete, queryClient])

  const { data, isLoading } = useQuery({
    queryKey: ["posts", type, status],
    queryFn: () =>
      pb.collection("posts").getList(1, 500, {
        filter: buildFilter(type, status),
        sort: "-published_at",
        fields: "id,title,post_type,status,published_at",
      }),
  })

  const posts = data?.items ?? []

  return (
    <div className="p-6 space-y-4 text-foreground">
      <div className="flex flex-wrap gap-4 items-center">
        <FilterBar filters={TYPE_FILTERS}   active={type}   onChange={setType} />
        <div className="w-px bg-border self-stretch" />
        <FilterBar filters={STATUS_FILTERS} active={status} onChange={setStatus} />
        <div className="flex-1" />
        <Button size="sm" variant={"secondary"}  onClick={() => navigate("/posts/new")}>
          <Plus className="size-3.5 mr-1" />
          New post
        </Button>
      </div>

      <div className="rounded-md border">
        <Table className="">
          <TableHeader>
            <TableRow>
              <TableHead>Title</TableHead>
              <TableHead className="w-24">Type</TableHead>
              <TableHead className="w-28">Status</TableHead>
              <TableHead className="w-36">Date</TableHead>
              <TableHead className="w-10" />
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              Array.from({ length: 8 }).map((_, i) => (
                <TableRow key={i}>
                  <TableCell><Skeleton className="h-4 w-48" /></TableCell>
                  <TableCell><Skeleton className="h-4 w-16" /></TableCell>
                  <TableCell><Skeleton className="h-4 w-20" /></TableCell>
                  <TableCell><Skeleton className="h-4 w-24" /></TableCell>
                  <TableCell />
                </TableRow>
              ))
            ) : posts.length === 0 ? (
              <TableRow>
                <TableCell colSpan={5} className="text-center py-12 text-muted-foreground">
                  No posts found.
                </TableCell>
              </TableRow>
            ) : posts.map(post => (
              <TableRow
                key={post.id}
                className="cursor-pointer hover:bg-muted/50"
                onClick={() => navigate(`/posts/${post.id}`)}
              >
                <TableCell className="font-medium">
                  {post.title || <span className="text-muted-foreground italic">Untitled</span>}
                </TableCell>
                <TableCell>
                  <Badge variant="outline" className="capitalize">{post.post_type}</Badge>
                </TableCell>
                <TableCell>
                  <Badge variant={post.status === "published" ? "default" : "secondary"}>
                    {post.status}
                  </Badge>
                </TableCell>
                <TableCell className="text-muted-foreground text-sm">
                  {formatDate(post.published_at)}
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
                      <DropdownMenuItem
                        variant="destructive"
                        onClick={() => setPostToDelete({ id: post.id, title: post.title })}
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
        <p className="text-xs text-muted-foreground">{posts.length} record{posts.length !== 1 ? "s" : ""}</p>
      )}

      <Dialog open={!!postToDelete} onOpenChange={open => !open && setPostToDelete(null)}>
        <DialogContent showCloseButton={false}>
          <DialogHeader>
            <DialogTitle>Delete post?</DialogTitle>
            <DialogDescription>
              &ldquo;{postToDelete?.title || "Untitled"}&rdquo; will be permanently deleted.
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
