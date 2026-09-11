# Voca artwork and design direction

Generation mode: built-in image_gen (ChatGPT Image 2 requested in each generation prompt). Original SVG icon and all UI illustrations are authored as vector/HTML/CSS, as requested. No Cool Dock images were copied.

Palette: warm paper #f2f1ed, ink #151814, forest #325a43, sage #bccdae, limestone #d9d8cf. Typography: Inter, tight large centered headlines; restrained sentence-case support text. Layout: floating centered navigation; full-width valley with glass desktop, original note and pill, framing rocks; sequential walkthrough; three small feature illustrations; founder-style sarcastic quote; one lifetime offer; FAQ; closing brand moment. The scenic desktop is the primary visual statement, adapted directly to the brief rather than using a generic dashboard.

The reference was inspected live. Hero heading was 80 px; rock layers measured 500 px desktop, 206 px mobile, based on 1764×2560 image dimensions. Voca uses original 1024×1536 rock art at those same display widths. Its radius is independently tuned for a soft localized reveal; exact foliage detail differs because it is original artwork.

Assets:
- public/assets/landscape.webp (PNG master alongside)
- public/assets/rock.webp (PNG master alongside)
- public/assets/rock-foliage.webp (PNG master alongside)
- public/assets/voca-icon.svg (original flat vector, not a generated bitmap)

Final prompt set:
## Landscape

Use ChatGPT Image 2. Use case: photorealistic-natural. Create an original high quality widescreen 1536x1024 scenic background for a premium Mac app landing page. Quiet rolling olive-green hills in a misty valley, warm early morning sunlight from left, distant layered mountains, soft ivory pale grey sky occupying upper 55 percent of the image, low grasses in lower foreground. Soft desaturated sage and warm cream palette, editorial landscape photograph with subtle dreamlike tranquility. Center valley open for UI overlay. No rocks in foreground, no plants above horizon, no people, no buildings, no text, no interface, no watermark. Landscape only. The sky should fade to flat #f2f1ed at top.

## Bare rock

Use ChatGPT Image 2. Asset type: transparent photorealistic cutout for a website. A single large vertically elongated weathered pale grey limestone rock formation, irregular craggy edges, small holes and wonderful tactile eroded stone texture, subtle warm morning sunlight from upper left, shadow side on right. Natural sculptural organic silhouette, wider at base, slightly leaning left, full isolated object entirely in frame, front view. No ground, no background, no plants, no moss. True transparent alpha background. Portrait 1024x1536 composition, rock fills 90 percent height and 80 percent width. No text or watermark.

## Foliage overlay

Use ChatGPT Image 2. Edit this rock for an exactly aligned hover-reveal website layer. Keep the original rock silhouette, rock position, camera, size, lighting and each stone detail EXACTLY unchanged. Add dense small delicate photorealistic maidenhair ferns, tiny clover leaves, moss and fine creeping vines growing organically from cracks across the rock surface. Individual fern fronds about 40-90 pixels long within this 1024-wide image, leaves 5-12 pixels, so plants are small relative to stone. Green foliage covers about 50 percent of rock, scattered evenly from top to bottom. Keep uncovered stone identical. Remove any background completely; actual transparent alpha, no gradients, no glow, no shadow outside rock, no black background. Same exact 1024x1536 frame. No text.

## Foliage alpha cleanup

Remove the grey and white checkerboard backdrop from this image. This is a background extraction task. Output actual TRANSPARENT pixels (PNG RGBA alpha=0) surrounding the rock and foliage. Do not draw a checkerboard, do not draw a grid, do not add a background. Preserve the rock and every leaf EXACTLY in place. Do not crop or move or relight anything. Exact same canvas dimensions 1024x1536. Just remove all background.


