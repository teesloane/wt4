ghost importer

Posts live in a json file and are nested in json like so: db > data > posts, which is an array of objects that look like below:

```json
{
"id": "68e86c136f444c0001352752",
            "uuid": "1d284f17-9f03-49f1-a72d-dfaaa2691c15",
            "title": "About",
            "slug": "about",
            "mobiledoc": null,
            "lexical": "{\"root\":{\"children\":[{\"children\":[{\"detail\":0,\"format\":0,\"mode\":\"normal\",\"style\":\"\",\"text\":\"Hello. I'm Ty. I'm grateful you are here. Thank you for coming by. \",\"type\":\"extended-text\",\"version\":1}],\"direction\":\"ltr\",\"format\":\"\",\"indent\":0,\"type\":\"paragraph\",\"version\":1},{\"children\":[{\"detail\":0,\"format\":0,\"mode\":\"normal\",\"style\":\"\",\"text\":\"This site is where I share my writing and projects I'm working on. I do this because it makes me uncomfortable, and somewhere inside me, I believe this is a \",\"type\":\"extended-text\",\"version\":1},{\"detail\":0,\"format\":2,\"mode\":\"normal\",\"style\":\"\",\"text\":\"good thing\",\"type\":\"extended-text\",\"version\":1},{\"detail\":0,\"format\":0,\"mode\":\"normal\",\"style\":\"\",\"text\":\". \",\"type\":\"extended-text\",\"version\":1}],\"direction\":\"ltr\",\"format\":\"\",\"indent\":0,\"type\":\"paragraph\",\"version\":1},{\"children\":[{\"detail\":0,\"format\":0,\"mode\":\"normal\",\"style\":\"\",\"text\":\"Everything on this site is made by me, by hand. All writing, images, illustrations, photographs et al, unless noted otherwise. \",\"type\":\"extended-text\",\"version\":1}],\"direction\":\"ltr\",\"format\":\"\",\"indent\":0,\"type\":\"paragraph\",\"version\":1},{\"children\":[{\"detail\":0,\"format\":0,\"mode\":\"normal\",\"style\":\"\",\"text\":\"If any of this resonates with you, say hello (weakty [at] fastmail.com) and let me know, or subscribe in the header for an e-mail update every now and then.\",\"type\":\"extended-text\",\"version\":1}],\"direction\":\"ltr\",\"format\":\"\",\"indent\":0,\"type\":\"paragraph\",\"version\":1},{\"children\":[{\"detail\":0,\"format\":0,\"mode\":\"normal\",\"style\":\"\",\"text\":\"Thank you for reading.\",\"type\":\"extended-text\",\"version\":1}],\"direction\":\"ltr\",\"format\":\"\",\"indent\":0,\"type\":\"paragraph\",\"version\":1},{\"children\":[],\"direction\":\"ltr\",\"format\":\"\",\"indent\":0,\"type\":\"paragraph\",\"version\":1}],\"direction\":\"ltr\",\"format\":\"\",\"indent\":0,\"type\":\"root\",\"version\":1}}",
            "html": "<p>Hello. I'm Ty. I'm grateful you are here. Thank you for coming by. </p><p>This site is where I share my writing and projects I'm working on. I do this because it makes me uncomfortable, and somewhere inside me, I believe this is a <em>good thing</em>. </p><p>Everything on this site is made by me, by hand. All writing, images, illustrations, photographs et al, unless noted otherwise. </p><p>If any of this resonates with you, say hello (weakty [at] fastmail.com) and let me know, or subscribe in the header for an e-mail update every now and then.</p><p>Thank you for reading.</p>",
            "comment_id": "68e86c136f444c0001352752",
            "plaintext": "Hello. I'm Ty. I'm grateful you are here. Thank you for coming by.\n\nThis site is where I share my writing and projects I'm working on. I do this because it makes me uncomfortable, and somewhere inside me, I believe this is a good thing.\n\nEverything on this site is made by me, by hand. All writing, images, illustrations, photographs et al, unless noted otherwise.\n\nIf any of this resonates with you, say hello (weakty [at] fastmail.com) and let me know, or subscribe in the header for an e-mail update every now and then.\n\nThank you for reading.",
            "feature_image": null,
            "featured": 0,
            "type": "page",
            "status": "published",
            "locale": null,
            "visibility": "public",
            "email_recipient_filter": "all",
            "created_at": "2025-10-10T02:14:43.000Z",
            "updated_at": "2026-01-10T02:42:30.000Z",
            "published_at": "2025-10-10T02:14:43.000Z",
            "custom_excerpt": null,
            "codeinjection_head": null,
            "codeinjection_foot": null,
            "custom_template": null,
            "canonical_url": null,
            "newsletter_id": null,
            "show_title_and_feature_image": 1
}


```
