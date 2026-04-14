import { useState } from "react"
import type { Editor } from "@tiptap/react"
import {
  Bold, Italic, Code, Link2, List, ListOrdered,
  Heading2, Heading3, Quote, Minus, Link as LinkIcon,
} from "lucide-react"
import PostLinkDialog, { postUrl } from "./PostLinkDialog"

interface Props {
  editor: Editor | null
}

interface ToolbarButtonProps {
  onClick: () => void
  active?: boolean
  title: string
  children: React.ReactNode
}

function Btn({ onClick, active, title, children }: ToolbarButtonProps) {
  return (
    <button
      type="button"
      onClick={onClick}
      title={title}
      className={[
        "p-1.5 rounded transition-colors",
        active
          ? "bg-muted text-foreground"
          : "text-muted-foreground hover:text-foreground hover:bg-muted/60",
      ].join(" ")}
    >
      {children}
    </button>
  )
}

function Divider() {
  return <div className="w-px h-4 bg-border mx-0.5" />
}

export default function EditorToolbar({ editor }: Props) {
  const [postLinkOpen, setPostLinkOpen] = useState(false)

  if (!editor) return null

  const setLink = () => {
    const url = window.prompt("URL:", editor.getAttributes("link").href ?? "")
    if (url === null) return // cancelled
    if (url === "") {
      editor.chain().focus().unsetLink().run()
      return
    }
    editor.chain().focus().setLink({ href: url }).run()
  }

  return (
    <>
      <div className="flex items-center gap-0.5 py-1 mb-2 border-b sticky top-0 bg-background z-10 flex-wrap">
        <Btn
          onClick={() => editor.chain().focus().toggleHeading({ level: 2 }).run()}
          active={editor.isActive("heading", { level: 2 })}
          title="Heading 2"
        >
          <Heading2 className="size-3.5" />
        </Btn>
        <Btn
          onClick={() => editor.chain().focus().toggleHeading({ level: 3 }).run()}
          active={editor.isActive("heading", { level: 3 })}
          title="Heading 3"
        >
          <Heading3 className="size-3.5" />
        </Btn>

        <Divider />

        <Btn
          onClick={() => editor.chain().focus().toggleBold().run()}
          active={editor.isActive("bold")}
          title="Bold (⌘B)"
        >
          <Bold className="size-3.5" />
        </Btn>
        <Btn
          onClick={() => editor.chain().focus().toggleItalic().run()}
          active={editor.isActive("italic")}
          title="Italic (⌘I)"
        >
          <Italic className="size-3.5" />
        </Btn>
        <Btn
          onClick={() => editor.chain().focus().toggleCode().run()}
          active={editor.isActive("code")}
          title="Inline code"
        >
          <Code className="size-3.5" />
        </Btn>

        <Divider />

        <Btn
          onClick={() => editor.chain().focus().toggleBulletList().run()}
          active={editor.isActive("bulletList")}
          title="Bullet list"
        >
          <List className="size-3.5" />
        </Btn>
        <Btn
          onClick={() => editor.chain().focus().toggleOrderedList().run()}
          active={editor.isActive("orderedList")}
          title="Numbered list"
        >
          <ListOrdered className="size-3.5" />
        </Btn>
        <Btn
          onClick={() => editor.chain().focus().toggleBlockquote().run()}
          active={editor.isActive("blockquote")}
          title="Blockquote"
        >
          <Quote className="size-3.5" />
        </Btn>

        <Divider />

        <Btn onClick={setLink} active={editor.isActive("link")} title="Add link">
          <Link2 className="size-3.5" />
        </Btn>
        <Btn onClick={() => setPostLinkOpen(true)} title="Link to another post">
          <LinkIcon className="size-3.5" />
        </Btn>

        <Divider />

        <Btn
          onClick={() => editor.chain().focus().setHorizontalRule().run()}
          title="Horizontal rule"
        >
          <Minus className="size-3.5" />
        </Btn>
      </div>

      <PostLinkDialog
        open={postLinkOpen}
        onClose={() => setPostLinkOpen(false)}
        onSelect={(post) => {
          const url = postUrl(post)
          const label = post.title || post.slug
          // Insert as a proper link node (not raw markdown text)
          editor
            .chain()
            .focus()
            .insertContent({
              type: "text",
              marks: [{ type: "link", attrs: { href: url, target: null, class: "post-link" } }],
              text: label,
            })
            .run()
          setPostLinkOpen(false)
        }}
      />
    </>
  )
}
