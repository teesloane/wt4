import { useState } from "react"
import { useQuery, useQueryClient } from "@tanstack/react-query"
import { useNavigate } from "react-router-dom"
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Skeleton } from "@/components/ui/skeleton"
import { Button } from "@/components/ui/button"
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

function formatDate(str: string | null) {
  if (!str) return "—"
  return new Date(str).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" })
}

export default function ProjectsPage() {
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const [deleteProject, setDeleteProject] = useState<{ id: string; title: string } | null>(null)
  const [deleting, setDeleting] = useState(false)

  const { data, isLoading } = useQuery({
    queryKey: ["projects"],
    queryFn: () =>
      pb.collection("projects").getList(1, 500, {
        sort: "-published_at",
        fields: "id,title,slug,status,project_status,public,published_at",
      }),
  })

  const projects = data?.items ?? []

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
        <Button size="sm" variant="secondary" onClick={() => navigate("/projects/new")}>
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
              <TableRow
                key={p.id}
                className="cursor-pointer hover:bg-muted/50"
                onClick={() => navigate(`/projects/${p.id}`)}
              >
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
                      <DropdownMenuItem onClick={() => navigate(`/projects/${p.id}`)}>
                        <Pencil className="size-3.5 mr-2" />
                        Edit
                      </DropdownMenuItem>
                      <DropdownMenuItem
                        variant="destructive"
                        onClick={() => setDeleteProject({ id: p.id, title: p.title as string })}
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

      <Dialog open={!!deleteProject} onOpenChange={open => !open && setDeleteProject(null)}>
        <DialogContent showCloseButton={false}>
          <DialogHeader>
            <DialogTitle>Delete project?</DialogTitle>
            <DialogDescription>
              &ldquo;{deleteProject?.title || "Untitled"}&rdquo; will be permanently deleted.
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
