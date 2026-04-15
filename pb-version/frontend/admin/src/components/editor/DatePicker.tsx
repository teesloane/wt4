import { useState } from "react"
import { format, parseISO } from "date-fns"
import { CalendarIcon, XIcon } from "lucide-react"
import { cn } from "@/lib/utils"
import { buttonVariants } from "@/components/ui/button"
import { Calendar } from "@/components/ui/calendar"
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover"

interface Props {
  // ISO date string "YYYY-MM-DD" or ""
  value: string
  onChange: (value: string) => void
  placeholder?: string
}

function formatDisplay(value: string, placeholder: string): string {
  if (!value) return placeholder
  try {
    return format(parseISO(value), "d MMM yyyy")
  } catch {
    return value
  }
}

export default function DatePicker({ value, onChange, placeholder = "Pick a date" }: Props) {
  const [open, setOpen] = useState(false)

  const selected = value ? parseISO(value) : undefined

  const handleDaySelect = (day: Date | undefined) => {
    onChange(day ? format(day, "yyyy-MM-dd") : "")
    setOpen(false)
  }

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger
        className={cn(
          buttonVariants({ variant: "outline" }),
          "w-full justify-start font-normal text-sm",
          !value && "text-muted-foreground"
        )}
      >
        <CalendarIcon className="size-3.5 mr-2 shrink-0" />
        {formatDisplay(value, placeholder)}
        {value && (
          <button
            type="button"
            onClick={e => { e.stopPropagation(); onChange(""); setOpen(false) }}
            className="ml-auto p-0.5 rounded hover:bg-muted text-muted-foreground hover:text-foreground transition-colors"
            title="Clear"
          >
            <XIcon className="size-3" />
          </button>
        )}
      </PopoverTrigger>
      <PopoverContent className="w-auto p-0" align="start">
        <Calendar
          mode="single"
          selected={selected}
          onSelect={handleDaySelect}
          autoFocus
        />
      </PopoverContent>
    </Popover>
  )
}
