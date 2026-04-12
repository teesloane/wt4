import { createContext, useContext, useEffect, useState } from "react"

const ThemeProviderContext = createContext({ theme: "system", setTheme: () => null })

export function ThemeProvider({ children, defaultTheme = "dark", storageKey = "weakty-admin-theme", ...props }) {
  const [theme, setTheme] = useState(() => localStorage.getItem(storageKey) || defaultTheme)

  useEffect(() => {
    const root = window.document.documentElement
    root.classList.remove("light", "dark")
    if (theme === "system") {
      root.classList.add(window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
    } else {
      root.classList.add(theme)
    }
  }, [theme])

  return (
    <ThemeProviderContext.Provider
      value={{
        theme,
        setTheme: (t) => { localStorage.setItem(storageKey, t); setTheme(t) },
      }}
      {...props}
    >
      {children}
    </ThemeProviderContext.Provider>
  )
}

export const useTheme = () => useContext(ThemeProviderContext)
