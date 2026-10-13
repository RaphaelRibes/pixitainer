# Step 3 — Run it locally with pixi

**Goal:** run the `thumb` task with pixi and confirm it works before containerizing.

## 3.1 Create a test image

Any image will do — a photo, a screenshot. Or generate a small one:

```bash
echo 'x' > /dev/null   # no-op; use any real image you have
```

If you don't have one handy, grab an open image:

```bash
curl -o photo.png https://picsum.photos/320/200
```

## 3.2 Run the task

```bash
pixi run thumb -w 100 photo.png small.png
```

You should see:

```
✨ Pixi task (thumb): python thumb.py -w 100 photo.png small.png
photo.png (99x62) -> small.png
```

## 3.3 Verify and clean up

```bash
file small.png        # → PNG image data, 99 x 62
rm -f small.png
```

Your project works. Now you're ready to freeze it into a container.

---

**← Back:** [Step 2 — Create the project](02-create-project.md) · **Next:** [Step 4 — Containerize with Apptainer](04-containerize-apptainer.md) →
