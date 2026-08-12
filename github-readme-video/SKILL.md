---
name: github-readme-video
description: >
  Embed a video (mp4/mov/webm) that actually autoplays/controls inline on a
  GitHub README or any GitHub markdown page — not just a clickable download
  link. Use this whenever the user wants to add a demo video, screen
  recording, or GIF-like clip to a README, wiki page, issue, or PR
  description on github.com OR any GitHub Enterprise Server instance, or
  asks things like "이 영상 README에 재생되게 넣을 수 있어?", "how do I get a
  video to play in my README", "release에 올린 mp4가 링크로만 뜨는데 왜 재생이
  안 되지", or reports that a committed/raw/release-hosted video only shows
  up as a plain link instead of a player. Also trigger if the user is about
  to commit a video file into the repo tree and link it by relative path —
  that approach silently fails to render, so intercept it early.
---

# Embedding a playable video in GitHub markdown

## The one fact that explains everything

GitHub's markdown renderer only wraps a URL in a native `<video controls>`
player when that URL points at **GitHub's own attachment storage** — a URL
shaped like:

```
https://github.com/user-attachments/assets/<uuid>
```

(or the older, still-valid form `https://user-images.githubusercontent.com/...`,
or a repo-scoped `https://github.com/<owner>/<repo>/assets/<id>/<uuid>`). On a
GitHub Enterprise Server instance, the same thing happens under that
instance's own hostname, e.g. `https://github.gmarket.com/user-attachments/assets/<uuid>`.

**Nothing else gets this treatment, regardless of file extension.** A raw git
blob URL, a `releases/download/...` asset URL, a `raw.githubusercontent.com`
URL, or any third-party host — all become a plain `<a href>` link. The
renderer isn't looking at whether the file is a video; it's matching the URL
against its own storage host. This is why "I uploaded the mp4 as a release
asset and linked it" doesn't play, and it doesn't matter if you re-encode it
as `.mov` or `.webm` instead — the host is what's checked, not the container.

GIFs are a different code path entirely: they're images, not videos, so
`![alt](path/to/file.gif)` renders and autoplays from *any* host, including a
plain relative path to a file committed in the repo. If the goal is a short
looping preview rather than a real video with audio/seek controls, a GIF
sidesteps this whole problem — mention that as an alternative when it fits.

## How to actually get an attachment-storage URL

There is exactly one supported way in: **drop the file into a GitHub web
text box that accepts attachments** — a new issue body, a PR/issue comment,
a PR description, a discussion post, or the in-browser file editor for a
markdown file. All of these upload through the same attachment pipeline.

1. Open any such text box on the target GitHub instance (github.com, or the
   org's GitHub Enterprise Server — same mechanism, just a different host).
   A throwaway "New issue" page on the target repo is the lowest-friction
   choice; you never have to submit it.
2. Drag the local video file directly onto the text area (or use its
   "Attach files" / paperclip control if the box has one).
3. Wait for the upload progress to finish. GitHub inserts a bare URL on its
   own line into the text box automatically — that URL *is* the deliverable.
4. Copy that URL out. **You do not need to save or submit the issue/comment.**
   The upload already landed in GitHub's storage the moment it finished; the
   draft container is just where the URL happened to get typed. Discard the
   draft (navigate away, don't submit) once you have the URL.
5. Paste that URL **alone, on its own line**, into the target markdown file —
   no `![]()`, no `<video>` tag, just the bare URL. GitHub's renderer detects
   it and swaps in a real `<video controls muted>` player, sourcing the
   actual bytes from a separate signed/tokenized storage URL under the hood.
6. Commit and push the markdown file as usual.

### If you (the agent) have a real browser tool at hand

If there's a browser-automation tool with genuine mouse/keyboard/file-drop
capability and the user is already logged into the target GitHub host, you
can drive step 1–4 yourself: open the "new issue" URL, drop the file, read
the resulting URL out of the text box, then close the tab without
submitting. Confirm with the user which repo/host to use first.

Do **not** try to fake this by synthesizing a `drop`/`paste` DOM event via
raw JavaScript injection (e.g. building a `File` from a base64 Blob and
dispatching a `DragEvent`). It looks plausible but is unreliable in
practice — headless JS execution against a real browser tab is often
flaky for this specific action, and even when the script runs, GitHub's
upload handler doesn't always accept a synthetic drop the same way it
accepts a real OS-level drag. If a scripted attempt fails or the browser
tool can't reliably execute JS in the tab, stop and just ask the human to
do the literal drag-and-drop themselves — it takes them seconds and is the
only path that's actually guaranteed to work.

## Verify before you trust it

Don't eyeball the rendered page and hope. Render the exact markdown through
GitHub's own markdown API and check for a `<video` tag in the output —
this catches a wrong URL shape (e.g. a release-asset URL that looks similar
but isn't the attachment-storage form) before it goes out.

```bash
scripts/check_video_render.sh <host> <owner/repo> <path/to/markdown-file>
```

`host` is `github.com` or a GHES hostname like `github.gmarket.com`. The
script pulls the file's current committed content via `gh api`, POSTs it to
that host's `/markdown` endpoint with `mode=gfm`, and reports whether a
`<video` element shows up in the result. Run it after every push that
touches a video embed — it's the fast, certain way to know it worked instead
of refreshing the repo page and squinting.

## Gotchas

- **Size limits apply.** Attachment uploads (video) are capped per-file —
  commonly up to 100 MB depending on the plan/instance, sometimes less on
  older GHES versions. If an upload silently fails or errors out, that's the
  first thing to check; re-encoding/trimming the clip is the fix, not
  retrying the same file.
- **Private repos**: the attachment inherits the access control of wherever
  it was uploaded from — uploading via a private repo's issue box keeps the
  asset gated the same way. Uploading from an unrelated public repo when the
  target is private can leak the video publicly, so upload from a text box
  that lives in (or has equivalent access to) the target repo.
- **This is host-agnostic.** The exact same mechanism works on github.com
  and on any GitHub Enterprise Server instance — only the hostname changes.
  Don't assume it's a github.com-only feature.
