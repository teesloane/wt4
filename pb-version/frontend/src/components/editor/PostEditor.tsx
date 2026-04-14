import { useEditor, EditorContent } from "@tiptap/react"
import StarterKit from "@tiptap/starter-kit"
import Image from "@tiptap/extension-image"
import Placeholder from "@tiptap/extension-placeholder"
import { Markdown } from "tiptap-markdown"
import { useEffect, useRef } from "react"
import { toast } from "sonner"
import pb from "@/lib/pb"
import EditorToolbar from "./EditorToolbar"
import "prosemirror-view/style/prosemirror.css"
import "./editor.css"

interface Props {
  content: string
  onChange: (markdown: string) => void
  postId: string | null
  ensurePostExists: () => Promise<string | null>
}

export default function PostEditor({ content, onChange, postId, ensurePostExists }: Props) {
  const isInitialized = useRef(false)
  const postIdRef = useRef(postId)
  postIdRef.current = postId

  const editor = useEditor({
    extensions: [
      StarterKit.configure({
        // StarterKit v3 includes Link — configure it here
        link: {
          openOnClick: false,
          HTMLAttributes: { rel: "noopener noreferrer" },
        },
      }),
      Image.configure({
        inline: false,
        allowBase64: false,
      }),
      Placeholder.configure({
        placeholder: "Start writing…",
      }),
      Markdown.configure({
        html: false,
        tightLists: true,
        transformCopiedText: true,
        transformPastedText: true,
      }),
    ],
    content: content || "",
    onUpdate: ({ editor }) => {
      // tiptap-markdown attaches getMarkdown() to storage at runtime
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const md = (editor.storage as any).markdown.getMarkdown() as string
      onChange(md)
    },
    editorProps: {
      attributes: {
        class: "focus:outline-none min-h-[400px] text-foreground",
      },
      handleDrop: (view, event, _slice, moved) => {
        if (moved) return false

        const files = event.dataTransfer?.files
        if (!files || files.length === 0) return false

        const imageFiles = Array.from(files).filter(f => f.type.startsWith("image/"))
        if (imageFiles.length === 0) return false

        event.preventDefault()

        // Capture drop coordinates before async work
        const coords = view.posAtCoords({ left: event.clientX, top: event.clientY })

        imageFiles.forEach(async (file) => {
          let pid = postIdRef.current
          if (!pid) {
            pid = await ensurePostExists()
            if (!pid) {
              toast.error("Save the post before uploading images")
              return
            }
          }

          try {
            const formData = new FormData()
            formData.append("content_images", file)
            const updated = await pb.collection("posts").update(pid, formData)

            const images = updated.content_images as string[]
            const filename = images[images.length - 1]
            const url = pb.files.getURL(updated, filename)

            // Use current view state at insertion time (state may have changed during upload)
            const imageNode = view.state.schema.nodes.image.create({ src: url, alt: file.name })
            if (coords) {
              view.dispatch(view.state.tr.insert(coords.pos, imageNode))
            } else {
              view.dispatch(view.state.tr.replaceSelectionWith(imageNode))
            }
          } catch (err: any) {
            toast.error(err?.message ?? "Image upload failed")
          }
        })

        return true
      },
    },
  })

  // Load existing content once when the editor mounts and content arrives
  useEffect(() => {
    if (!editor) return
    if (isInitialized.current) return
    if (!content) return
    isInitialized.current = true
    setTimeout(() => {
      editor.commands.setContent(content)
    }, 0)
  }, [editor, content])

  return (
    <div className="flex flex-col">
      <EditorToolbar editor={editor} />
      <EditorContent editor={editor} />
    </div>
  )
}
