import { createContext, useContext, useEffect, useState } from "react"

const ThemeProviderContext = createContext({ theme: "system", setTheme: () => null })

export function ThemeProvider({ children, defaultTheme = "dark", storageKey = "weakty-admin-theme", ...props }) {
  const [theme, setTheme] = useState(() => localStorage.getItem(storageKey) || defaultTheme)

  useEffect(() => {
    const root = window.document.documentElement

    function applyTheme(t: string) {
      root.classList.remove("light", "dark")
      if (t === "system") {
        root.classList.add(window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
      } else {
        root.classList.add(t)
      }
    }

    applyTheme(theme)

    if (theme === "system") {
      const mq = window.matchMedia("(prefers-color-scheme: dark)")
      const handler = () => applyTheme("system")
      mq.addEventListener("change", handler)
      return () => mq.removeEventListener("change", handler)
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
