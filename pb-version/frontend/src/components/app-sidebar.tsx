import { NavLink, useMatch } from "react-router-dom"
import {
  LayoutDashboardIcon,
  FileTextIcon,
  TagIcon,
  NetworkIcon,
  LibraryIcon,
  CommandIcon,
} from "lucide-react"
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarGroup,
  SidebarGroupLabel,
  SidebarGroupContent,
} from "@/components/ui/sidebar"
import { NavUser } from "@/components/nav-user"
import pb from "@/lib/pb"

const navItems = [
  { title: "Dashboard", url: "/", icon: LayoutDashboardIcon, end: true },
  { title: "Posts",     url: "/posts",    icon: FileTextIcon },
  { title: "Tags",      url: "/tags",     icon: TagIcon },
  { title: "Entities",  url: "/entities", icon: NetworkIcon },
  { title: "Media",     url: "/media",    icon: LibraryIcon },
]

function NavItem({ item }) {
  const Icon = item.icon
  const match = useMatch({ path: item.url, end: item.end ?? false })
  return (
    <SidebarMenuItem>
      <SidebarMenuButton
        tooltip={item.title}
        isActive={!!match}
        render={<NavLink to={item.url} />}
      >
        <Icon />
        <span>{item.title}</span>
      </SidebarMenuButton>
    </SidebarMenuItem>
  )
}

export function AppSidebar({ ...props }) {
  const record = pb.authStore.record
  const user = {
    name: record?.email?.split("@")[0] ?? "admin",
    email: record?.email ?? "",
    avatar: "",
  }

  return (
    <Sidebar collapsible="offcanvas" {...props}>
      <SidebarHeader>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton
              className="data-[slot=sidebar-menu-button]:p-1.5!"
              render={<NavLink to="/" />}
            >
              <CommandIcon className="size-5!" />
              <span className="text-base font-semibold">Weakty</span>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>

      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupLabel>Content</SidebarGroupLabel>
          <SidebarGroupContent>
            <SidebarMenu>
              {navItems.map(item => (
                <NavItem key={item.url} item={item} />
              ))}
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>
      </SidebarContent>

      <SidebarFooter>
        <NavUser user={user} />
      </SidebarFooter>
    </Sidebar>
  )
}
