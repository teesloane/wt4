import { useQuery } from "@tanstack/react-query"
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Skeleton } from "@/components/ui/skeleton"
import pb from "@/lib/pb"

export default function TagsPage() {
  const { data, isLoading } = useQuery({
    queryKey: ["tags"],
    queryFn: () =>
      pb.collection("tags").getList(1, 500, {
        sort: "name",
        fields: "id,name,slug,public",
      }),
  })

  const tags = data?.items ?? []

  return (
    <div className="p-6 space-y-4 text-foreground">
      <div className="rounded-md border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Name</TableHead>
              <TableHead>Slug</TableHead>
              <TableHead className="w-24">Public</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              Array.from({ length: 6 }).map((_, i) => (
                <TableRow key={i}>
                  <TableCell><Skeleton className="h-4 w-32" /></TableCell>
                  <TableCell><Skeleton className="h-4 w-28" /></TableCell>
                  <TableCell><Skeleton className="h-4 w-14" /></TableCell>
                </TableRow>
              ))
            ) : tags.length === 0 ? (
              <TableRow>
                <TableCell colSpan={3} className="text-center py-12 text-muted-foreground">
                  No tags found.
                </TableCell>
              </TableRow>
            ) : tags.map(tag => (
              <TableRow key={tag.id} className="cursor-pointer hover:bg-muted/50">
                <TableCell className="font-medium">{tag.name}</TableCell>
                <TableCell className="text-muted-foreground font-mono text-sm">{tag.slug}</TableCell>
                <TableCell>
                  {tag.public
                    ? <Badge variant="default">Public</Badge>
                    : <Badge variant="secondary">Private</Badge>}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
      {!isLoading && (
        <p className="text-xs text-muted-foreground">{tags.length} tag{tags.length !== 1 ? "s" : ""}</p>
      )}
    </div>
  )
}
