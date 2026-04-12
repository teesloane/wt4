import { useState, useEffect } from 'react'
import { Navigate } from 'react-router-dom'
import pb from '@/lib/pb'

export default function AuthGuard({ children }) {
  const [isValid, setIsValid] = useState(pb.authStore.isValid)

  useEffect(() => {
    // pb.authStore.onChange returns an unsubscribe function
    return pb.authStore.onChange(() => {
      setIsValid(pb.authStore.isValid)
    })
  }, [])

  if (!isValid) {
    return <Navigate to="/login" replace />
  }
  return children
}
