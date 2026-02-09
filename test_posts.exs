# Quick test script to verify Posts resource works
# Run with: mix run test_posts.exs

alias Weakty.Posts.Post
alias Weakty.Accounts.User

# Get or create a test user
user = case Ash.read(User, limit: 1) do
  {:ok, [user | _]} -> user
  _ ->
    IO.puts("No users found. Please create a user first.")
    System.halt(1)
end

# Create a test post
{:ok, post} = Post.create_post(%{
  title: "My First Post",
  markdown: "# Hello World\n\nThis is my first post written in **markdown**!",
  excerpt: "An introduction to my first post",
  featured_image: "https://example.com/image.jpg",
  status: :draft,
  user_id: user.id
})

IO.puts("✅ Created draft post: #{post.title}")
IO.puts("   Slug: #{post.slug}")
IO.puts("   Status: #{post.status}")

# Publish the post
{:ok, published_post} = Post.publish_post(post)
IO.puts("✅ Published post at: #{published_post.published_at}")

# List all posts
{:ok, all_posts} = Post.list_posts()
IO.puts("✅ Total posts: #{length(all_posts)}")

# List published posts
{:ok, published_posts} = Post.list_published_posts()
IO.puts("✅ Published posts: #{length(published_posts)}")

# List drafts
{:ok, drafts} = Post.list_drafts()
IO.puts("✅ Draft posts: #{length(drafts)}")

IO.puts("\n🎉 Posts feature is working correctly!")
