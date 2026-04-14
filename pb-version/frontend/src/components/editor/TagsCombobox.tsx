import { useState } from "react"
import { useMutation, useQueryClient } from "@tanstack/react-query"
import { CheckIcon, ChevronsUpDownIcon, XIcon, PlusIcon, LoaderIcon } from "lucide-react"
import { cn, slugify } from "@/lib/utils"
import { buttonVariants } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command"
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover"
import pb from "@/lib/pb"

interface Tag {
  id: string
  name: string
}

interface Props {
  allTags: Tag[]
  selectedIds: string[]
  onChange: (ids: string[]) => void
}

export default function TagsCombobox({ allTags, selectedIds, onChange }: Props) {
  const [open, setOpen] = useState(false)
  const [search, setSearch] = useState("")
  const queryClient = useQueryClient()

  const createTag = useMutation({
    mutationFn: (name: string) =>
      pb.collection("tags").create({ name, slug: slugify(name) }) as Promise<Tag>,
    onSuccess: (tag) => {
      queryClient.invalidateQueries({ queryKey: ["tags"] })
      onChange([...selectedIds, tag.id])
      setSearch("")
    },
  })

  const toggle = (id: string) => {
    onChange(
      selectedIds.includes(id)
        ? selectedIds.filter(t => t !== id)
        : [...selectedIds, id]
    )
  }

  const remove = (id: string) => onChange(selectedIds.filter(t => t !== id))

  const selectedTags = allTags.filter(t => selectedIds.includes(t.id))

  const filtered = allTags.filter(t =>
    t.name.toLowerCase().includes(search.toLowerCase())
  )

  console.log("filtered is ", filtered)

  const trimmedSearch = search.trim()
  const canCreate =
    trimmedSearch.length > 0 &&
    !allTags.some(t => t.name.toLowerCase() === trimmedSearch.toLowerCase())

  return (
    <div className="space-y-1.5">
      <Popover open={open} onOpenChange={setOpen}>
        <PopoverTrigger
          className={cn(
            buttonVariants({ variant: "outline" }),
            "h-auto min-h-8 w-full justify-between font-normal hover:bg-transparent"
          )}
        >
          <div className="flex flex-wrap items-center gap-1 text-left">
            {selectedTags.length > 0 ? (
              selectedTags.map(tag => (
                <Badge key={tag.id} variant="outline" className="rounded-sm gap-1 pr-0.5">
                  <span>{tag.name}</span>
                  <span
                    role="button"
                    tabIndex={0}
                    onKeyDown={e => e.key === "Enter" && (e.stopPropagation(), remove(tag.id))}
                    onClick={e => {
                      e.stopPropagation()
                      remove(tag.id)
                    }}
                    className="inline-flex items-center rounded-sm hover:bg-muted px-0.5 cursor-pointer"
                  >
                    <XIcon className="size-3" />
                  </span>
                </Badge>
              ))
            ) : (
              <span className="text-muted-foreground text-sm">Add tags…</span>
            )}
          </div>
          <ChevronsUpDownIcon className="size-3.5 shrink-0 text-muted-foreground/70 ml-1" />
        </PopoverTrigger>

        <PopoverContent className="w-(--anchor-width) p-0" sideOffset={4}>
          <Command shouldFilter={false}>
            <CommandInput
              placeholder="Search or create…"
              value={search}
              onValueChange={setSearch}
              // Press Enter to create when no match exists
              onKeyDown={e => {
                if (e.key === "Enter" && canCreate && !createTag.isPending) {
                  e.preventDefault()
                  createTag.mutate(trimmedSearch)
                }
              }}
            />
            <CommandList>
              {filtered.length === 0 && !canCreate && (
                <CommandEmpty>No tags found.</CommandEmpty>
              )}
              {filtered.length > 0 && (
                <CommandGroup>
                  {filtered.map(tag => (
                    <CommandItem
                      key={tag.id}
                      value={tag.id}
                      onSelect={() => toggle(tag.id)}
                      data-checked={selectedIds.includes(tag.id)}
                    >
                      <span className="truncate">{tag.name}</span>
                    </CommandItem>
                  ))}
                </CommandGroup>
              )}
            </CommandList>
          </Command>

          {/* Create button lives outside cmdk to avoid event conflicts with base-ui Popover */}
          {canCreate && (
            <div className="border-t p-1">
              <button
                type="button"
                disabled={createTag.isPending}
                // onMouseDown instead of onClick: prevents blur/close race condition
                onMouseDown={e => {
                  e.preventDefault()
                  createTag.mutate(trimmedSearch)
                }}
                className="w-full flex items-center gap-1.5 px-2 py-1.5 text-sm rounded-sm hover:bg-muted text-muted-foreground hover:text-foreground transition-colors disabled:opacity-50"
              >
                {createTag.isPending
                  ? <LoaderIcon className="size-3.5 animate-spin" />
                  : <PlusIcon className="size-3.5" />
                }
                Create &ldquo;{trimmedSearch}&rdquo;
              </button>
            </div>
          )}
        </PopoverContent>
      </Popover>
    </div>
  )
}
