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
import {
  Select, SelectTrigger, SelectContent, SelectItem, SelectValue,
} from "@/components/ui/select"
import { Plus, Zap, MoreHorizontal, Pencil, Trash2, Search } from "lucide-react"
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

const MEDIA_TYPES = ["book", "music", "film", "tv", "comic", "game"] as const
const STATUSES    = ["want_to_consume", "consuming", "consumed"] as const

type MediaType = typeof MEDIA_TYPES[number]
type Status    = typeof STATUSES[number]

interface MediaLogRecord {
  id: string
  title: string
  creator: string
  media_type: MediaType
  status: Status
  rating: number | null
  date_finished: string
  date_consumed: string
  date_started: string
  public: boolean
  thumbnail_url: string
  external_url: string
}

interface MediaLogForm {
  title: string
  creator: string
  media_type: MediaType
  status: Status
  rating: string
  date_finished: string
  date_consumed: string
  date_started: string
  date_published: string
  public: boolean
  thumbnail_url: string
  external_url: string
}

interface SearchResult {
  external_id: string
  type: string
  title: string
  creator: string
  year: string
  thumbnail_url: string | null
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

const TYPE_FILTERS = [
  { label: "All",   value: "" },
  { label: "Book",  value: "book" },
  { label: "Music", value: "music" },
  { label: "Film",  value: "film" },
  { label: "TV",    value: "tv" },
  { label: "Comic", value: "comic" },
  { label: "Game",  value: "game" },
]

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

function Stars({ rating }: { rating: number | null }) {
  if (!rating) return <span className="text-muted-foreground">—</span>
  const full = Math.round(rating)
  return <span className="text-sm">{"★".repeat(full)}{"☆".repeat(5 - full)}</span>
}

function formatDate(str: string | null) {
  if (!str) return "—"
  return new Date(str).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" })
}

const EMPTY_FORM: MediaLogForm = {
  title: "", creator: "", media_type: "book", status: "want_to_consume",
  rating: "", date_finished: "", date_consumed: "", date_started: "",
  date_published: "", public: true, thumbnail_url: "", external_url: "",
}

function recordToForm(r: MediaLogRecord): MediaLogForm {
  return {
    title: r.title ?? "",
    creator: r.creator ?? "",
    media_type: r.media_type ?? "book",
    status: r.status ?? "want_to_consume",
    rating: r.rating != null ? String(r.rating) : "",
    date_finished: r.date_finished ?? "",
    date_consumed: r.date_consumed ?? "",
    date_started: r.date_started ?? "",
    date_published: "",
    public: r.public ?? true,
    thumbnail_url: r.thumbnail_url ?? "",
    external_url: r.external_url ?? "",
  }
}

function formToPayload(f: MediaLogForm) {
  return {
    title: f.title.trim(),
    creator: f.creator.trim() || null,
    media_type: f.media_type,
    status: f.status,
    rating: f.rating ? parseInt(f.rating, 10) : null,
    date_finished: f.date_finished || null,
    date_consumed: f.date_consumed || null,
    date_started: f.date_started || null,
    public: f.public,
    thumbnail_url: f.thumbnail_url.trim() || null,
    external_url: f.external_url.trim() || null,
  }
}

// ─── MediaLogFormDialog ───────────────────────────────────────────────────────

interface MediaLogFormDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  initial?: MediaLogRecord | null
  prefill?: Partial<MediaLogForm>
  onSaved: () => void
}

function MediaLogFormDialog({ open, onOpenChange, initial, prefill, onSaved }: MediaLogFormDialogProps) {
  const isEdit = !!initial
  const [form, setForm] = useState<MediaLogForm>(
    initial ? recordToForm(initial) : { ...EMPTY_FORM, ...prefill }
  )
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const handleOpenChange = (open: boolean) => {
    if (open) {
      setForm(initial ? recordToForm(initial) : { ...EMPTY_FORM, ...prefill })
      setError(null)
    }
    onOpenChange(open)
  }

  const set = (key: keyof MediaLogForm, value: any) =>
    setForm(f => ({ ...f, [key]: value }))

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setSaving(true)
    setError(null)
    try {
      const payload = formToPayload(form)
      if (isEdit) {
        await pb.collection("media_logs").update(initial!.id, payload)
        toast.success("Media log updated")
      } else {
        await pb.collection("media_logs").create(payload)
        toast.success("Media log created")
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
      <DialogContent className="max-w-lg max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{isEdit ? "Edit media log" : "New media log"}</DialogTitle>
        </DialogHeader>
        <form onSubmit={handleSubmit} className="space-y-3 pt-2">
          <div className="grid grid-cols-2 gap-3">
            <div className="col-span-2 space-y-1.5">
              <Label>Title</Label>
              <Input value={form.title} onChange={e => set("title", e.target.value)} required autoFocus />
            </div>
            <div className="space-y-1.5">
              <Label>Creator</Label>
              <Input value={form.creator} onChange={e => set("creator", e.target.value)} placeholder="Author / Artist / Director" />
            </div>
            <div className="space-y-1.5">
              <Label>Type</Label>
              <Select value={form.media_type} onValueChange={v => set("media_type", v)}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {MEDIA_TYPES.map(t => <SelectItem key={t} value={t}>{t}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>Status</Label>
              <Select value={form.status} onValueChange={v => set("status", v)}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  {STATUSES.map(s => <SelectItem key={s} value={s}>{s.replace(/_/g, " ")}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>Rating (1–5)</Label>
              <Input
                type="number" min={1} max={5}
                value={form.rating} onChange={e => set("rating", e.target.value)}
                placeholder="—"
              />
            </div>
            <div className="space-y-1.5">
              <Label>Date started</Label>
              <Input type="date" value={form.date_started} onChange={e => set("date_started", e.target.value)} />
            </div>
            <div className="space-y-1.5">
              <Label>Date finished</Label>
              <Input type="date" value={form.date_finished} onChange={e => set("date_finished", e.target.value)} />
            </div>
            <div className="space-y-1.5">
              <Label>Date consumed</Label>
              <Input type="date" value={form.date_consumed} onChange={e => set("date_consumed", e.target.value)} />
            </div>
            <div className="col-span-2 space-y-1.5">
              <Label>Thumbnail URL</Label>
              <Input value={form.thumbnail_url} onChange={e => set("thumbnail_url", e.target.value)} placeholder="https://…" />
            </div>
            <div className="col-span-2 space-y-1.5">
              <Label>External URL</Label>
              <Input value={form.external_url} onChange={e => set("external_url", e.target.value)} placeholder="https://…" />
            </div>
          </div>
          <div className="flex items-center gap-2">
            <Checkbox id="ml-public" checked={form.public} onCheckedChange={c => set("public", !!c)} />
            <Label htmlFor="ml-public">Public</Label>
          </div>
          {error && <p className="text-sm text-destructive">{error}</p>}
          <DialogFooter>
            <DialogClose render={<Button type="button" variant="outline" />}>Cancel</DialogClose>
            <Button type="submit" disabled={saving}>
              {saving ? "Saving…" : isEdit ? "Save changes" : "Create"}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

// ─── MediaSearchDialog ────────────────────────────────────────────────────────

interface MediaSearchDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  onSelect: (prefill: Partial<MediaLogForm>) => void
}

const SEARCH_TYPES = [
  { label: "Book",  value: "book" },
  { label: "Comic", value: "comic" },
  { label: "Music", value: "music" },
  { label: "Movie", value: "movie" },
  { label: "TV",    value: "tv" },
]

function MediaSearchDialog({ open, onOpenChange, onSelect }: MediaSearchDialogProps) {
  const [searchType, setSearchType] = useState("book")
  const [query, setQuery] = useState("")
  const [results, setResults] = useState<SearchResult[]>([])
  const [loading, setLoading] = useState(false)
  const [searched, setSearched] = useState(false)

  const handleOpenChange = (open: boolean) => {
    if (!open) {
      setQuery("")
      setResults([])
      setSearched(false)
    }
    onOpenChange(open)
  }

  const handleSearch = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!query.trim()) return
    setLoading(true)
    setSearched(true)
    try {
      const res = await fetch(
        `/api/admin/search?q=${encodeURIComponent(query.trim())}&type=${searchType}`
      )
      if (!res.ok) throw new Error(`Search failed: ${res.status}`)
      const data: SearchResult[] = await res.json()
      setResults(data)
    } catch (err: any) {
      toast.error(err?.message ?? "Search failed")
      setResults([])
    } finally {
      setLoading(false)
    }
  }

  const handleSelect = (r: SearchResult) => {
    const mediaType = (MEDIA_TYPES as readonly string[]).includes(r.type)
      ? (r.type as MediaType)
      : "book"
    onSelect({
      title: r.title,
      creator: r.creator,
      thumbnail_url: r.thumbnail_url ?? "",
      media_type: mediaType,
    })
    handleOpenChange(false)
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>Quick Add — Search</DialogTitle>
          <DialogDescription>
            Search for a title to pre-fill the media log form.
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSearch} className="space-y-3">
          <div className="flex flex-wrap gap-1.5">
            {SEARCH_TYPES.map(t => (
              <button
                key={t.value}
                type="button"
                onClick={() => setSearchType(t.value)}
                className={[
                  "px-3 py-1 rounded-md text-sm font-medium transition-colors",
                  searchType === t.value
                    ? "bg-primary text-primary-foreground"
                    : "bg-muted text-muted-foreground hover:bg-muted/80",
                ].join(" ")}
              >
                {t.label}
              </button>
            ))}
          </div>
          <div className="flex gap-2">
            <Input
              value={query}
              onChange={e => setQuery(e.target.value)}
              placeholder="Search title…"
              autoFocus
              className="flex-1"
            />
            <Button type="submit" disabled={loading}>
              <Search className="size-4" />
            </Button>
          </div>
        </form>

        <div className="space-y-1 max-h-72 overflow-y-auto">
          {loading ? (
            Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="flex gap-3 items-center p-2">
                <Skeleton className="h-12 w-9 rounded shrink-0" />
                <div className="space-y-1 flex-1">
                  <Skeleton className="h-3.5 w-48" />
                  <Skeleton className="h-3 w-32" />
                </div>
              </div>
            ))
          ) : searched && results.length === 0 ? (
            <p className="text-center py-8 text-muted-foreground text-sm">No results found.</p>
          ) : results.map((r, i) => (
            <button
              key={i}
              onClick={() => handleSelect(r)}
              className="w-full flex gap-3 items-start p-2 rounded-md hover:bg-muted text-left transition-colors"
            >
              {r.thumbnail_url ? (
                <img
                  src={r.thumbnail_url}
                  alt={r.title}
                  className="h-12 w-9 object-cover rounded shrink-0"
                />
              ) : (
                <div className="h-12 w-9 bg-muted rounded shrink-0" />
              )}
              <div className="min-w-0">
                <p className="text-sm font-medium leading-tight truncate">{r.title}</p>
                <p className="text-xs text-muted-foreground truncate">
                  {[r.creator, r.year].filter(Boolean).join(" · ")}
                </p>
              </div>
            </button>
          ))}
        </div>
      </DialogContent>
    </Dialog>
  )
}

// ─── MediaPage ────────────────────────────────────────────────────────────────

export default function MediaPage() {
  const queryClient = useQueryClient()
  const [typeFilter, setTypeFilter] = useState("")
  const [formOpen, setFormOpen] = useState(false)
  const [editItem, setEditItem] = useState<MediaLogRecord | null>(null)
  const [deleteItem, setDeleteItem] = useState<MediaLogRecord | null>(null)
  const [deleting, setDeleting] = useState(false)
  const [searchOpen, setSearchOpen] = useState(false)
  const [prefill, setPrefill] = useState<Partial<MediaLogForm>>({})

  const { data, isLoading } = useQuery({
    queryKey: ["media", typeFilter],
    queryFn: () =>
      pb.collection("media_logs").getList(1, 500, {
        filter: typeFilter ? `media_type='${typeFilter}'` : undefined,
        sort: "-date_consumed",
        fields: "id,title,creator,media_type,status,date_finished,date_consumed,date_started,public,rating,thumbnail_url,external_url",
      }),
  })

  const items = data?.items ?? []

  const invalidate = useCallback(() => {
    queryClient.invalidateQueries({ queryKey: ["media"] })
  }, [queryClient])

  const openCreate = () => {
    setEditItem(null)
    setPrefill({})
    setFormOpen(true)
  }

  const openEdit = (item: MediaLogRecord) => {
    setEditItem(item)
    setFormOpen(true)
  }

  const handleSearchSelect = (newPrefill: Partial<MediaLogForm>) => {
    setEditItem(null)
    setPrefill(newPrefill)
    setFormOpen(true)
  }

  const handleDelete = async () => {
    if (!deleteItem) return
    setDeleting(true)
    try {
      await pb.collection("media_logs").delete(deleteItem.id)
      queryClient.invalidateQueries({ queryKey: ["media"] })
      toast.success("Deleted")
    } catch (err: any) {
      toast.error(err?.message ?? "Delete failed")
    } finally {
      setDeleting(false)
      setDeleteItem(null)
    }
  }

  return (
    <div className="p-6 space-y-4 text-foreground">
      <div className="flex flex-wrap gap-4 items-center">
        <FilterBar filters={TYPE_FILTERS} active={typeFilter} onChange={setTypeFilter} />
        <div className="flex-1" />
        <div className="flex gap-2">
          <Button size="sm" variant="outline" onClick={() => setSearchOpen(true)}>
            <Zap className="size-3.5 mr-1" />
            Quick Add
          </Button>
          <Button size="sm" variant="secondary" onClick={openCreate}>
            <Plus className="size-3.5 mr-1" />
            New
          </Button>
        </div>
      </div>

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
              <TableHead className="w-10" />
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              Array.from({ length: 8 }).map((_, i) => (
                <TableRow key={i}>
                  {Array.from({ length: 7 }).map((_, j) => (
                    <TableCell key={j}><Skeleton className="h-4 w-full" /></TableCell>
                  ))}
                </TableRow>
              ))
            ) : items.length === 0 ? (
              <TableRow>
                <TableCell colSpan={7} className="text-center py-12 text-muted-foreground">
                  No media logs found.
                </TableCell>
              </TableRow>
            ) : items.map(m => (
              <TableRow key={m.id} className="hover:bg-muted/50">
                <TableCell className="font-medium">{m.title}</TableCell>
                <TableCell className="text-muted-foreground">{m.creator || "—"}</TableCell>
                <TableCell>
                  <Badge variant="outline" className="capitalize">{m.media_type}</Badge>
                </TableCell>
                <TableCell>
                  <Badge
                    variant={m.status === "consumed" ? "default" : "secondary"}
                    className="capitalize"
                  >
                    {String(m.status).replace(/_/g, " ")}
                  </Badge>
                </TableCell>
                <TableCell><Stars rating={m.rating as number | null} /></TableCell>
                <TableCell className="text-muted-foreground text-sm">
                  {formatDate((m.date_finished || m.date_consumed) as string)}
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
                      <DropdownMenuItem onClick={() => openEdit(m as unknown as MediaLogRecord)}>
                        <Pencil className="size-3.5 mr-2" />
                        Edit
                      </DropdownMenuItem>
                      <DropdownMenuItem
                        variant="destructive"
                        onClick={() => setDeleteItem(m as unknown as MediaLogRecord)}
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
        <p className="text-xs text-muted-foreground">{items.length} record{items.length !== 1 ? "s" : ""}</p>
      )}

      <MediaLogFormDialog
        open={formOpen}
        onOpenChange={setFormOpen}
        initial={editItem}
        prefill={prefill}
        onSaved={invalidate}
      />

      <MediaSearchDialog
        open={searchOpen}
        onOpenChange={setSearchOpen}
        onSelect={handleSearchSelect}
      />

      <Dialog open={!!deleteItem} onOpenChange={open => !open && setDeleteItem(null)}>
        <DialogContent showCloseButton={false}>
          <DialogHeader>
            <DialogTitle>Delete media log?</DialogTitle>
            <DialogDescription>
              &ldquo;{deleteItem?.title}&rdquo; will be permanently deleted.
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
