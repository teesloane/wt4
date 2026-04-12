import { useState } from "react"
import { useQuery } from "@tanstack/react-query"
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Skeleton } from "@/components/ui/skeleton"
import pb from "@/lib/pb"

const TYPE_FILTERS = [
  { label: "All",       value: "" },
  { label: "Post",      value: "post" },
  { label: "Link",      value: "link" },
  { label: "Media Log", value: "media_log" },
  { label: "Project",   value: "project" },
]

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

export default function EntitiesPage() {
  const [type, setType] = useState("")

  const { data, isLoading } = useQuery({
    queryKey: ["entities", type],
    queryFn: () =>
      pb.collection("entities").getList(1, 500, {
        filter: type ? `entity_type='${type}'` : "",
        sort: "-published_at",
        fields: "id,entity_type,subtype,title,slug,published_at,public",
      }),
  })

  const entities = data?.items ?? []

  return (
    <div className="p-6 space-y-4">
      <FilterBar filters={TYPE_FILTERS} active={type} onChange={setType} />

      <div className="rounded-md border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Title</TableHead>
              <TableHead className="w-28">Type</TableHead>
              <TableHead className="w-24">Subtype</TableHead>
              <TableHead className="w-24">Public</TableHead>
              <TableHead className="w-36">Published</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              Array.from({ length: 8 }).map((_, i) => (
                <TableRow key={i}>
                  <TableCell><Skeleton className="h-4 w-48" /></TableCell>
                  <TableCell><Skeleton className="h-4 w-20" /></TableCell>
                  <TableCell><Skeleton className="h-4 w-16" /></TableCell>
                  <TableCell><Skeleton className="h-4 w-12" /></TableCell>
                  <TableCell><Skeleton className="h-4 w-24" /></TableCell>
                </TableRow>
              ))
            ) : entities.length === 0 ? (
              <TableRow>
                <TableCell colSpan={5} className="text-center py-12 text-muted-foreground">
                  No entities found.
                </TableCell>
              </TableRow>
            ) : entities.map(e => (
              <TableRow key={e.id} className="cursor-pointer hover:bg-muted/50">
                <TableCell className="font-medium">{e.title || <span className="italic text-muted-foreground">Untitled</span>}</TableCell>
                <TableCell><Badge variant="outline" className="capitalize">{e.entity_type}</Badge></TableCell>
                <TableCell className="text-muted-foreground text-sm capitalize">{e.subtype || "—"}</TableCell>
                <TableCell>
                  {e.public
                    ? <Badge variant="default">Yes</Badge>
                    : <Badge variant="secondary">No</Badge>}
                </TableCell>
                <TableCell className="text-muted-foreground text-sm">{formatDate(e.published_at)}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>

      {!isLoading && (
        <p className="text-xs text-muted-foreground">{entities.length} record{entities.length !== 1 ? "s" : ""}</p>
      )}
    </div>
  )
}
