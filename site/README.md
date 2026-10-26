# WallLoop website

The product page for WallLoop, live at **https://wallloop.vercel.app** (and at `wallloop.rivendevs.in`
once that domain is connected). The Riven site links to it through its short link `/wallloop`, which
redirects here, the same way `/clareo` reaches Clareo.

It follows Riven's design system (`rivendevs-site/design.md` and `skills.md`): Riven's dark neutrals,
Instrument Sans with one Instrument Serif italic word per heading, DM Mono labels, the 1240 px grid,
radii, motion tokens, the nav capsule, the orbit hero and film grain. Like every Riven product, it
keeps its own accent: WallLoop rose `#FF5C8A`, used where Riven uses orange (one accent fill and one
glow per viewport, black text on accent buttons).

## Files

| Path | What it is |
| --- | --- |
| `index.html` | The whole page: hero, app illustration, features, how it works, energy and privacy, lock screen note, requirements, FAQ, download, footer |
| `styles.css` | Design tokens as CSS custom properties, components and scroll-driven entrances |
| `main.js` | About 7 KB of vanilla JS: download link, nav state, hero tilt, inner parallax, card spotlight, mobile menu |
| `assets/` | `favicon.svg`, `icon-512.png` / `.webp`, `icon-1024.png`, `apple-touch-icon.png`, `og.png` (1200 × 630) |
| `tools/` | `render-assets.sh` renders the PNGs from the app's own brand code (`Sources/Design`) |

There is no build step and no dependencies. Fonts load from Google Fonts with `display=swap`.

## The download link

Every download button gets its address from one constant at the top of `main.js`:

```js
const DOWNLOAD_URL = "https://github.com/johnbosco-j/WallLoop/releases/latest/download/WallLoop.dmg";
```

GitHub serves that URL from the newest release as long as each release attaches a file named exactly
`WallLoop.dmg`. **It only works while the GitHub repository is public**; for a private repository,
point the constant at a DMG hosted elsewhere (for example in this folder or on the Riven domain).

The version line under each button (`v0.1.0 preview · macOS 14+ · Free`) is plain text in
`index.html`; update it with each release, along with the "Version" row under Requirements.

## Preview locally

```bash
python3 -m http.server 4321 --directory site
```

Then open http://127.0.0.1:4321. Check the page at 375 px and 768 px wide, with
**System Settings › Accessibility › Display › Reduce motion** turned on (no rotation, tilt or
parallax; everything still readable), and tab through it with the keyboard.

## Deploy on Vercel

It's deployed as the Vercel project **`wallloop`** (team `johnbosco-06s-projects`), linked to this
repository with **Root Directory** `site`, no framework and no build command. Every push to `main`
that changes `site/` deploys to production automatically; the project's Ignored Build Step
(`git diff --quiet HEAD^ HEAD -- .`) skips pushes that only touch the app.

To use the Riven domain later:

1. In the `wallloop` project, under **Settings › Domains**, add `wallloop.rivendevs.in`.
2. At the domain registrar, add a `CNAME` record for `wallloop` with the value Vercel shows
   (usually `cname.vercel-dns.com`).
3. In the `rivendevs-site` project, change `NEXT_PUBLIC_WALLLOOP_URL` to
   `https://wallloop.rivendevs.in` and redeploy it.

Any static host works the same way: serve the contents of `site/` at the domain root.

## The Riven site redirect

In `rivendevs-site`, `next.config.ts` redirects `/wallloop` to `WALLLOOP_URL`
(default `https://wallloop.<site domain>`, override with `NEXT_PUBLIC_WALLLOOP_URL`), and
`content/products.ts` lists WallLoop with `href: "/wallloop"`. Today `NEXT_PUBLIC_WALLLOOP_URL` is set
to `https://wallloop.vercel.app` in the `rivendevs-site` Vercel project. If the page moves, change
that variable and redeploy the Riven site; nothing here changes.

## Regenerate the images

After changing the logo in `Sources/Design/BrandMark.swift`:

```bash
site/tools/render-assets.sh
```

It compiles the app's `Theme.swift` and `BrandMark.swift` with `tools/SiteAssets.swift`, registers
the bundled fonts, and writes the PNGs (and a WebP copy of the icon if `cwebp` is installed). Keep
`assets/favicon.svg` in step by hand: it draws the same shapes on the same 1024 grid.
