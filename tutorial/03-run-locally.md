# Step 3 — Run it locally with pixi

**Goal:** run the `copy` task with pixi and confirm it works before containerizing.

## 3.1 Create a test file

```bash
echo "hello pixitainer" > input.txt
```

## 3.2 Run the task

```bash
pixi run copy input.txt output.txt
```

You should see:

```
✨ Pixi task (copy): python copy.py input.txt output.txt
Copied input.txt -> output.txt
```

## 3.3 Verify and clean up

```bash
cat output.txt        # → hello pixitainer
rm -f input.txt output.txt
```

Your project works. Now you're ready to freeze it into a container.

---

## Exercises

**Exercise 3.1** — Fill in the missing word. You run a pixi task with `pixi ____ <task>`:

<details>
<summary>Show answer</summary>

`run`

```bash
pixi run copy input.txt output.txt
```

</details>

**Exercise 3.2** — Fill in the missing word. The `copy` task takes two arguments: the source and the ____:

<details>
<summary>Show answer</summary>

`destination` (or `dest`)

```bash
pixi run copy input.txt output.txt
#                    source     destination
```

</details>

**Exercise 3.3** — Fill in the missing word. To check the copied file's contents, you use `____ output.txt`:

<details>
<summary>Show answer</summary>

`cat`

```bash
cat output.txt
```

</details>

---

**← Back:** [Step 2 — Create the project](02-create-project.md) · **Next:** [Step 4 — Containerize with Apptainer](04-containerize-apptainer.md) →
