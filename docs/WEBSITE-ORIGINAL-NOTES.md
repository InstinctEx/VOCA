# Active VOCA app

The current application is **[VOCA.app](VOCA.app)**, built from the original FluidVoice source in **[VocaSource](VocaSource/README.md)**. The earlier VocaNative implementation is retired and preserved only as an archive.

---

# Voca

A complete responsive static landing page for Voca, a Mac voice dictation app. Original vector branding, generated scenery, animated mist, a local foliage reveal, a dictation demo, a video placeholder, lifetime pricing, and accessible native dialogs.

## Run

Node.js 20 or newer. No dependencies to install.

```sh
npm run dev
```

Open http://localhost:5173. `PORT=5174 npm run dev` uses a different port.

```sh
npm run check
npm run build
```

Deploy `dist/` to any static host at the domain root. All fonts and artwork are self-hosted; no analytics or external page requests. PNG generation masters stay in `public/assets/` and are excluded from the production build.

## Launch configuration

Edit `config.js`. The €49 lifetime price is a proposed placeholder, pending owner confirmation. Set the real price, checkout URL, downloadable Mac app URL, walkthrough MP4 URL (optional), and support email. Until a checkout is supplied, the purchase button honestly displays a release-pending dialog. It does not pretend to charge or download anything. A download link appears once configured. No app installer or payment backend was supplied with the brief.

The video modal is deliberately a placeholder, as requested. Its interactive-demo button opens a functioning, scripted dictation walkthrough. The page never requests microphone access and does not claim to perform speech recognition.

Before publishing, confirm the app's exact feature set, supported macOS versions, permissions, data handling, and lifetime license terms. Add the real app privacy and seller terms documents; the current privacy dialog only describes this website. Do not add invented certifications or testimonials. Configure the final absolute social preview URL and canonical URL after choosing a production domain.

## Design and motion

- Reference: https://cooldock.app/ (the supplied dock.cool link redirects here). Functional context: https://wisprflow.ai/.
- The screen recording mentioned in the prompt was not available in the workspace. The live reference was inspected instead.
- Inter, self-hosted under the included SIL Open Font License.
- Original flat icon: `public/assets/voca-icon.svg`. Cream voice bars on a forest-green rounded square; repeated in the original dictation pill.
- Generated masters and prompts: `docs/art-direction.md`.
- 500 px desktop / 206 px mobile rock layers match the measured live-reference layer widths. Ferns remain fixed in the image; the pointer moves only a soft 115 px mask (90 px under 809 px). Exact leaf-by-leaf scale cannot be identical when artwork is original.
- The mask is mapped through each rock's inverse transform so the reveal stays under the cursor on the mirrored rock. The previous area vanishes as the pointer moves. No accumulated foliage trails. Pointer leave, scroll, and window blur clear the reveal. Touch devices show bare rock.
- Scenery can be paused; reduced-motion settings disable ambient motion. Demos are user-triggered. Keyboard arrows, Home, and End change walkthrough steps. Native dialogs support Escape and return focus to the trigger.

## Structure

`index.html`: final page copy and semantic markup. `styles.css`: responsive design and motion. `app.js`: interactions. `config.js`: launch inputs. `server.mjs`: local preview. `build.mjs`: static export.

See `docs/walkthrough-storyboard.md` for the replaceable video slot's script and timing.
