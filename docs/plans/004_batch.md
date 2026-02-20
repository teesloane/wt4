Here is a list of work that I would like to be done on this application. For each set of tasks grouped by markdown headings, I would like you to create a new work tree with a new branch to do the work. The work in each section here is fairly isolated and will hopefully not conflict too much with the other work, but that's why I want you to use git worktrees.

If you hit the maximum usage for the day, don't start using extra credits and instead just stop working and we'll resume later.


## Better form UI.

Right now, a lot of the forms for creating resources like the new media log form or creating a new post, they have a single line perform. I think that some of these forms could be grouped into one line. So for example, looking at the new media form, the author and the media type and the status could all be one line. Even the same with date started, date finished, and date published. But we should make sure that it reverts to being on a single line when using mobile.

If you're trying to find the files, begin by looking for anything named form.ex. Please note that the post form is already pretty good because it's already been separated to the right panel of the view. But please still look through any places where we could make it so that forms aren't on a single line per field.


## Getting tags working.

Right now, every resource should be able to have tags. You'll notice that, for example, the links resource has a LinkTag table in that domain and the idea being that it should be joined to the tags table allowing a link to have a tag and a tag to be assignable to it.

However, my end desired result is that a user should be able to look at a tag such as cycling and see all content across posts, projects, links, media that have the tag cycling.

I think this might be called having a polymorphic table, but right now, the way things are structured, each resource has a tag table that will connect to the tags table. So you'll have link tag, project tag, post tag. This could work, but I'm wondering if there's a better way to go about it. Maybe we don't need to have the joins through table, but probably we do. Another thing to note is that whenever we create a resource, we also create an entity which allows me to have an entity of everything that's been created as a list. And then I can filter through it and search it. And I want tags to go into those too. I think right now those tags are stored as JSON on the entity. 

As it stands, forms across resources have a tags field that allows you to create multiple tags, but when it goes to time to actually create the resource, the tag doesn't get created with it.

## Image Uploading

Currently image uploading doesn't work. Start with trying to fix the form for posts. Adding a feature image upload through the form should attach it to the record in the database and should display the file as well as move it into the static directory so that it shows up when we actually go and look at the post.

## Newsletters

I want you to build a newsletter feature similar to what Ghost has. This means:
- I should be able to have multiple newsletters (So that means a new table. Newsletters should have a name, a start date, and end date because they might end, A description for the purpose they serve. )
- Then I suppose there needs to be an "issues" table. Sort of like for each newsletter you send out of a specific type, it needs to be in its own table. So they'll link by the ID to the newsletter parent. So it's like "newsletter" is called "newsletter A" and then there's going to be "issue 1" for "newsletter A".
- When I publish a post, I should have the option of sending it as a newsletter.
- Create a newsletters route for admin where I can manage my list of newsletters and their form fields.
- There is a sign-up form on my website that collects recipients so I'll need a new table for that.
- Also create an admin route and view for displaying people who have signed up for a newsletter. It should have the user's name when they signed up and for which newsletter, I guess.
- Having a backend in place that can connect to an email sending service would be best, but I don't know which one I want to use yet. So having just like an adapter behavior pattern set up and that I can plug in what I want to use when I'm ready.

## Import media from obsidian

I've added a directory of markdown files for books that I've read. Each of them have a yaml front matter with information about the book, like the title, the publisher, my rating, when I started and when I finished it. Some of the yaml varies from file to file, but mostly that they follow the same format. I'd like for you to scan through this directory of files, unify the differences in the yaml and create a script that can ingest these files and add them to the media log database specifically for books.

The files can be found here: docs/plans/books/*
