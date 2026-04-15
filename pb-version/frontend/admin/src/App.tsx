import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ThemeProvider } from './components/theme-provider'
import { Toaster } from './components/ui/sonner'
import AuthGuard from './components/AuthGuard'
import AdminLayout from './components/AdminLayout'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import PostsPage from './pages/PostsPage'
import PostEditorPage from './pages/PostEditorPage'
import TagsPage from './pages/TagsPage'
import EntitiesPage from './pages/EntitiesPage'
import MediaPage from './pages/MediaPage'
import ProjectsPage from './pages/ProjectsPage'
import ProjectEditorPage from './pages/ProjectEditorPage'

const queryClient = new QueryClient()

export default function App() {
  return (
    <ThemeProvider defaultTheme="system" storageKey="weakty-admin-theme">
    <QueryClientProvider client={queryClient}>
      <BrowserRouter basename="/admin">
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route element={<AuthGuard><AdminLayout /></AuthGuard>}>
            <Route index element={<Dashboard />} />
            <Route path="posts"    element={<PostsPage />} />
            <Route path="posts/:id" element={<PostEditorPage />} />
            <Route path="tags"     element={<TagsPage />} />
            <Route path="entities" element={<EntitiesPage />} />
            <Route path="media"    element={<MediaPage />} />
            <Route path="projects" element={<ProjectsPage />} />
            <Route path="projects/:id" element={<ProjectEditorPage />} />
          </Route>
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
      <Toaster richColors />
    </ThemeProvider>
  )
}
