# Drafts

Drafts is designed for writing new articles or writing when no server connected. There's a new tab for drafts, users can tap to continue editing a draft. A draft can be removed by swipe gesture, or will be removed when posted.

## How it works

When writing new articles, if there's changes in title, content or attachments, an alert of saving as draft will be prompt when closing.

When there's no server connected, users can quick post in drafts.

## Drafts Directory

Drafts are saved under ```[User Documents]/Drafts/[Article UUID]/```, all servers shares.

Inside an article's draft directory:
- draft.json
- draft.html
- attachments

The ```draft.json``` is the codable object of PlanetArticle struct. If the planetID is nil, it means the draft was created when no server connected.