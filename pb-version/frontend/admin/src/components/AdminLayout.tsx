import { Outlet, useLocation } from "react-router-dom"
import { TooltipProvider } from "@/components/ui/tooltip"
import { SidebarProvider, SidebarInset, SidebarTrigger } from "@/components/ui/sidebar"
import { Separator } from "@/components/ui/separator"
import { AppSidebar } from "@/components/app-sidebar"

const TITLES: Record<string, string> = {
  "/": "Dashboard",
  "/posts": "Posts",
  "/tags": "Tags",
  "/entities": "Entities",
  "/media": "Media",
  "/projects": "Projects",
}

export default function AdminLayout() {
  const { pathname } = useLocation()
  const title = pathname.startsWith("/posts/")
    ? "Editor"
    : (TITLES[pathname] ?? "Admin")

  return (
    <TooltipProvider>
      <SidebarProvider>
        <AppSidebar />
        <SidebarInset>
          <header className="flex h-12 shrink-0 items-center gap-2 border-b px-4">
            <SidebarTrigger className="-ml-1" />
            <Separator orientation="vertical" className="mx-2 h-4" />
            <span className="text-sm font-medium">{title}</span>
          </header>
          <div className="flex flex-col flex-1 overflow-auto">
            <Outlet />
          </div>
        </SidebarInset>
      </SidebarProvider>
    </TooltipProvider>
  )
}
