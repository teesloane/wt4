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
  // datetime-local format: "2026-04-13T14:30" or ""
  value: string
  onChange: (value: string) => void
}

function toDatePart(value: string): string {
  return value ? value.split("T")[0] : ""
}

function toTimePart(value: string): string {
  return value ? value.split("T")[1]?.slice(0, 5) ?? "12:00" : "12:00"
}

function formatDisplay(value: string): string {
  if (!value) return "Pick a date"
  try {
    const d = parseISO(value)
    return format(d, "dd MMM yyyy, HH:mm")
  } catch {
    return value
  }
}

export default function DateTimePicker({ value, onChange }: Props) {
  const [open, setOpen] = useState(false)

  const selectedDate = value ? parseISO(value.length === 10 ? value + "T00:00" : value) : undefined
  const timePart = toTimePart(value)
  const datePart = toDatePart(value)

  const handleDaySelect = (day: Date | undefined) => {
    if (!day) return
    const d = format(day, "yyyy-MM-dd")
    onChange(`${d}T${timePart}`)
  }

  const handleTimeChange = (time: string) => {
    if (!datePart) {
      // If no date set, default to today
      const today = format(new Date(), "yyyy-MM-dd")
      onChange(`${today}T${time}`)
    } else {
      onChange(`${datePart}T${time}`)
    }
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
        {formatDisplay(value)}
      </PopoverTrigger>

      <PopoverContent className="w-auto p-0" align="start">
        <Calendar
          mode="single"
          selected={selectedDate}
          onSelect={handleDaySelect}
          autoFocus
        />
        <div className="border-t p-3 flex items-center gap-2">
          <label className="text-xs text-muted-foreground shrink-0">Time</label>
          <input
            type="time"
            value={timePart}
            onChange={e => handleTimeChange(e.target.value)}
            className="flex-1 text-sm bg-transparent border border-input rounded-md px-2 py-1 outline-none focus:border-ring focus:ring-2 focus:ring-ring/30"
          />
          {value && (
            <button
              type="button"
              onClick={() => { onChange(""); setOpen(false) }}
              className="p-1 rounded hover:bg-muted text-muted-foreground hover:text-foreground transition-colors"
              title="Clear date"
            >
              <XIcon className="size-3.5" />
            </button>
          )}
        </div>
      </PopoverContent>
    </Popover>
  )
}
