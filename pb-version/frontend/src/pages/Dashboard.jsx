import { useQueries } from "@tanstack/react-query"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"
import pb from "@/lib/pb"

const statQueries = [
  { key: "posts",     label: "Posts",    fn: () => pb.collection("posts").getList(1, 1, { filter: "post_type='post'",    fields: "id" }) },
  { key: "published", label: "Published",fn: () => pb.collection("posts").getList(1, 1, { filter: "status='published'",  fields: "id" }) },
  { key: "drafts",    label: "Drafts",   fn: () => pb.collection("posts").getList(1, 1, { filter: "status='draft'",      fields: "id" }) },
  { key: "tils",      label: "TILs",     fn: () => pb.collection("posts").getList(1, 1, { filter: "post_type='til'",     fields: "id" }) },
  { key: "quotes",    label: "Quotes",   fn: () => pb.collection("posts").getList(1, 1, { filter: "post_type='quote'",   fields: "id" }) },
  { key: "links",     label: "Links",    fn: () => pb.collection("links").getList(1, 1,  {                               fields: "id" }) },
  { key: "tags",      label: "Tags",     fn: () => pb.collection("tags").getList(1, 1,   {                               fields: "id" }) },
  { key: "media",     label: "Media",    fn: () => pb.collection("media_logs").getList(1, 1, {                           fields: "id" }) },
]

export default function Dashboard() {
  const results = useQueries({
    queries: statQueries.map(s => ({
      queryKey: ["stat", s.key],
      queryFn: s.fn,
    })),
  })

  return (
    <div className="p-6 space-y-6">
      <div>
        <h2 className="text-lg font-semibold mb-4">Overview</h2>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
          {statQueries.map((s, i) => {
            const result = results[i]
            return (
              <Card key={s.key}>
                <CardHeader className="pb-1 pt-4 px-4">
                  <CardTitle className="text-xs font-medium text-muted-foreground uppercase tracking-wider">
                    {s.label}
                  </CardTitle>
                </CardHeader>
                <CardContent className="px-4 pb-4">
                  {result.isLoading ? (
                    <Skeleton className="h-8 w-12" />
                  ) : (
                    <p className="text-3xl font-bold tabular-nums">
                      {result.data?.totalItems ?? "—"}
                    </p>
                  )}
                </CardContent>
              </Card>
            )
          })}
        </div>
      </div>
    </div>
  )
}
