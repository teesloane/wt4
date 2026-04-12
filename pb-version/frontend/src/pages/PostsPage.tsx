import { useState } from "react"
import { useQuery } from "@tanstack/react-query"
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Skeleton } from "@/components/ui/skeleton"
import pb from "@/lib/pb"

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

function buildFilter(type, status) {
  const parts = []
  if (type)   parts.push(`post_type='${type}'`)
  if (status) parts.push(`status='${status}'`)
  return parts.join(" && ") || undefined
}

function FilterBar({ filters, active, onChange }) {
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

function formatDate(str) {
  if (!str) return "—"
  return new Date(str).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" })
}

export default function PostsPage() {
  const [type, setType] = useState("")
  const [status, setStatus] = useState("")

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
      <div className="flex flex-wrap gap-4">
        <FilterBar filters={TYPE_FILTERS}   active={type}   onChange={setType} />
        <div className="w-px bg-border self-stretch" />
        <FilterBar filters={STATUS_FILTERS} active={status} onChange={setStatus} />
      </div>

      <div className="rounded-md border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Title</TableHead>
              <TableHead className="w-24">Type</TableHead>
              <TableHead className="w-28">Status</TableHead>
              <TableHead className="w-36">Date</TableHead>
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
                </TableRow>
              ))
            ) : posts.length === 0 ? (
              <TableRow>
                <TableCell colSpan={4} className="text-center py-12 text-muted-foreground">
                  No posts found.
                </TableCell>
              </TableRow>
            ) : posts.map(post => (
              <TableRow key={post.id} className="cursor-pointer hover:bg-muted/50">
                <TableCell className="font-medium">{post.title || <span className="text-muted-foreground italic">Untitled</span>}</TableCell>
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
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>

      {!isLoading && (
        <p className="text-xs text-muted-foreground">{posts.length} record{posts.length !== 1 ? "s" : ""}</p>
      )}
    </div>
  )
}
