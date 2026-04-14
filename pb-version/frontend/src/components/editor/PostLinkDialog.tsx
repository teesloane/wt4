import { useState } from "react"
import { useQuery } from "@tanstack/react-query"
import { Search } from "lucide-react"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import pb from "@/lib/pb"

export interface PostLink {
  id: string
  title: string
  slug: string
  post_type: string
}

interface Props {
  open: boolean
  onClose: () => void
  onSelect: (post: PostLink) => void
}

const TYPE_PATHS: Record<string, string> = {
  post: "/posts",
  fiction: "/posts",
  page: "",
  til: "/til",
  quote: "/quotes",
  update: "/now",
  process: "/posts",
}

export function postUrl(post: PostLink): string {
  const base = TYPE_PATHS[post.post_type] ?? "/posts"
  return base ? `${base}/${post.slug}` : `/${post.slug}`
}

export default function PostLinkDialog({ open, onClose, onSelect }: Props) {
  const [search, setSearch] = useState("")

  const { data } = useQuery({
    queryKey: ["posts-search", search],
    queryFn: async () => {
      const result = await pb.collection("posts").getList(1, 20, {
        filter: search
          ? `title~"${search}" || slug~"${search}"`
          : undefined,
        sort: "-published_at",
        fields: "id,title,slug,post_type",
      })
      return result
    },
    enabled: open,
  })

  const posts = (data?.items ?? []) as unknown as PostLink[]

  return (
    <Dialog open={open} onOpenChange={(o: boolean) => !o && onClose()}>
      <DialogContent className="max-w-m h-96">
        <DialogHeader className="">
          <DialogTitle className="">Link to post</DialogTitle>
        </DialogHeader>
        <div className="relative">
          <Search className="absolute left-2.5 top-2 size-3.5 text-muted-foreground" />
          <input
            autoFocus
            type="text"
            placeholder="Search posts…"
            value={search}
            onChange={e => setSearch(e.target.value)}
            className="w-full pl-8 pr-3 py-1.5 text-sm bg-muted/50 border border-input rounded-md outline-none focus:border-ring focus:ring-2 focus:ring-ring/30"
          />
        </div>
        <div className="max-h-64 overflow-y-auto -mx-2">
          {posts.length === 0 ? (
            <p className="text-sm text-muted-foreground text-center py-6">No posts found</p>
          ) : (
            posts.map(post => (
              <button
                key={post.id}
                onClick={() => onSelect(post)}
                className="w-full text-left px-3 py-2 rounded-md hover:bg-muted transition-colors flex items-center gap-2"
              >
                <span className="text-xs text-muted-foreground w-14 shrink-0 capitalize">
                  {post.post_type}
                </span>
                <span className="text-sm truncate">{post.title || "(untitled)"}</span>
              </button>
            ))
          )}
        </div>
      </DialogContent>
    </Dialog>
  )
}
