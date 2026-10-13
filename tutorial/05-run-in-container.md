# Step 5 — Run the task in the container

**Goal:** run the `thumb` task from the `.sif` image, exactly like you ran it with pixi.

## 5.1 Run the task

```bash
apptainer run -f --bind "$PWD:/work" thumb.sif thumb -w 100 /work/photo.png /work/small.png
```

You should see:

```
✨ Pixi task (thumb): python thumb.py -w 100 /work/photo.png /work/small.png
/work/photo.png (99x62) -> /work/small.png
```

## 5.2 Verify and clean up

```bash
file small.png        # → PNG image data, 99 x 62
rm -f small.png
```

Your pixi environment is now running **inside a container**. The same `thumb.sif` will run identically on any machine with Apptainer — that's the whole point.

---

*Expected output assumes `photo.png` is 320×200 like the one from Step 3. If your own image has different dimensions, the numbers in the output will differ — that's fine.*

**← Back:** [Step 4 — Containerize](04-containerize-apptainer.md) · **Next:** [Step 6 — The pathing gotcha](06-pathing.md) →
