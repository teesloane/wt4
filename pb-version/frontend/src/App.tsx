import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ThemeProvider } from './components/theme-provider'
import AuthGuard from './components/AuthGuard'
import AdminLayout from './components/AdminLayout'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import PostsPage from './pages/PostsPage'
import TagsPage from './pages/TagsPage'
import EntitiesPage from './pages/EntitiesPage'
import MediaPage from './pages/MediaPage'

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
            <Route path="tags"     element={<TagsPage />} />
            <Route path="entities" element={<EntitiesPage />} />
            <Route path="media"    element={<MediaPage />} />
          </Route>
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
    </ThemeProvider>
  )
}
