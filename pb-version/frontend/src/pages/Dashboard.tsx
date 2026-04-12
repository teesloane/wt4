import { useQueries } from "@tanstack/react-query"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"
import pb from "@/lib/pb"

type PostRow = { id: string; status: string; post_type: string }

function useStats() {
  const [posts, links, tags, media] = useQueries({
    queries: [
      {
        queryKey: ["stat", "all-posts"],
        queryFn: () => pb.collection("posts").getFullList<PostRow>({ fields: "id,status,post_type" }),
      },
      {
        queryKey: ["stat", "links"],
        queryFn: () => pb.collection("links").getList(1, 1, { fields: "id" }),
      },
      {
        queryKey: ["stat", "tags"],
        queryFn: () => pb.collection("tags").getList(1, 1, { fields: "id" }),
      },
      {
        queryKey: ["stat", "media"],
        queryFn: () => pb.collection("media_logs").getList(1, 1, { fields: "id" }),
      },
    ],
  })

  const allPosts = posts.data ?? []
  const counts = {
    published: allPosts.filter(p => p.status === "published").length,
    drafts:    allPosts.filter(p => p.status === "draft").length,
    tils:      allPosts.filter(p => p.post_type === "til").length,
    quotes:    allPosts.filter(p => p.post_type === "quote").length,
    links:     links.data?.totalItems,
    tags:      tags.data?.totalItems,
    media:     media.data?.totalItems,
  }

  return { counts, isLoading: posts.isLoading || links.isLoading || tags.isLoading || media.isLoading }
}

const STATS = [
  { key: "published", label: "Published" },
  { key: "drafts",    label: "Drafts" },
  { key: "tils",      label: "TILs" },
  { key: "quotes",    label: "Quotes" },
  { key: "links",     label: "Links" },
  { key: "tags",      label: "Tags" },
  { key: "media",     label: "Media" },
] as const

export default function Dashboard() {
  const { counts, isLoading } = useStats()

  return (
    <div className="p-6 space-y-6 text-foreground">
      <div>
        <h2 className="text-lg font-semibold mb-4">Overview</h2>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
          {STATS.map(s => (
            <Card key={s.key}>
              <CardHeader className="pb-1 pt-4 px-4">
                <CardTitle className="text-xs font-medium uppercase tracking-wider">
                  {s.label}
                </CardTitle>
              </CardHeader>
              <CardContent className="px-4 pb-4">
                {isLoading ? (
                  <Skeleton className="h-8 w-12" />
                ) : (
                  <p className="text-3xl font-bold tabular-nums">
                    {counts[s.key] ?? "—"}
                  </p>
                )}
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </div>
  )
}
