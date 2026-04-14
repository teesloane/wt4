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
  { label: "Book",    value: "book" },
  { label: "Music",   value: "music" },
  { label: "Film",    value: "film" },
  { label: "TV",      value: "tv" },
  { label: "Comic",   value: "comic" },
  { label: "Game",    value: "game" },
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

function Stars({ rating }) {
  if (!rating) return <span className="text-muted-foreground">—</span>
  const full = Math.round(rating)
  return <span className="text-sm">{"★".repeat(full)}{"☆".repeat(5 - full)}</span>
}

function formatDate(str) {
  if (!str) return "—"
  return new Date(str).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" })
}

export default function MediaPage() {
  const [type, setType] = useState("")

  const { data, isLoading } = useQuery({
    queryKey: ["media", type],
    queryFn: () =>
      pb.collection("media_logs").getList(1, 500, {
        filter: type ? `media_type='${type}'` : undefined,
        sort: "-date_consumed",
        fields: "id,title,creator,media_type,status,date_finished,date_consumed,public,rating",
      }),
  })

  const items = data?.items ?? []

  return (
    <div className="p-6 space-y-4 text-foreground">
      <FilterBar filters={TYPE_FILTERS} active={type} onChange={setType} />

      <div className="rounded-md border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Title</TableHead>
              <TableHead>Creator</TableHead>
              <TableHead className="w-24">Type</TableHead>
              <TableHead className="w-28">Status</TableHead>
              <TableHead className="w-28">Rating</TableHead>
              <TableHead className="w-36">Date</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              Array.from({ length: 8 }).map((_, i) => (
                <TableRow key={i}>
                  {Array.from({ length: 6 }).map((_, j) => (
                    <TableCell key={j}><Skeleton className="h-4 w-full" /></TableCell>
                  ))}
                </TableRow>
              ))
            ) : items.length === 0 ? (
              <TableRow>
                <TableCell colSpan={6} className="text-center py-12 text-muted-foreground">
                  No media logs found.
                </TableCell>
              </TableRow>
            ) : items.map(m => (
              <TableRow key={m.id} className="cursor-pointer hover:bg-muted/50">
                <TableCell className="font-medium">{m.title}</TableCell>
                <TableCell className="text-muted-foreground">{m.creator || "—"}</TableCell>
                <TableCell><Badge variant="outline" className="capitalize">{m.media_type}</Badge></TableCell>
                <TableCell>
                  <Badge variant={m.status === "consumed" ? "default" : "secondary"} className="capitalize">
                    {m.status}
                  </Badge>
                </TableCell>
                <TableCell><Stars rating={m.rating} /></TableCell>
                <TableCell className="text-muted-foreground text-sm">
                  {formatDate(m.date_finished || m.date_consumed)}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>

      {!isLoading && (
        <p className="text-xs text-muted-foreground">{items.length} record{items.length !== 1 ? "s" : ""}</p>
      )}
    </div>
  )
}
