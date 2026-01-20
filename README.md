# Pixitainer

Pixi is cool, Apptainer is cool, let's make them both work together !

## Why ...

### pixi ?

Pixi is a fast, easy and fun to use tool that allows you to manage multiple dependencies in multiple environment very easily.
It has a great support either by its developers or community on [discord](https://discord.gg/A94bgPENFD).

### using containers ?

Singularity/Apptainer is very used in bioinformatics, it's at the hearth of analyzes pipelines, but it's a headache to put in place.
In another hand, pixi is fast, easy to use, but it's not a container and so harder to keep intact for a long period of time.
The idea behind pixitainer is to put a pixi environment into an Apptainer container, so you can freeze your fast pace working environment into a container easily !

### Apptainer ?

Apptainer is more the "public library" version of the software, while Singularity is more like a "corporate bookstore."
Because Apptainer is hosted by the Linux Foundation, it is designed specifically for the scientific community to ensure that your research code remains free, accessible and without being tied to a private company’s profit goals.

## How ?
The best thing to do will be to add this way as a [pixi extension](https://pixi.sh/latest/integration/extensions/introduction/), so we just have to type `pixi container` and some option and tada !
For now, there is the `pixitainer.def` with ideas how to make it work.
Here I have an example of use of `pixitainer.def` for a [short reads assembler project](https://github.com/MickaelCQ/RaMiLass.git) during my master.

TODO:
- [x] Receipe that works.
- [x] Pixi package that I can add as an extension.
- [x] Adding options to the extension.
- [ ] Documentation and testings.
- [ ] Publish
- [ ] Go back to step 3 until WW3, messiah or death of the internet

# Known problems

## Pathing is... strange?

When launching a command in the pixi shell, the `cwd` of tasks will be changed into the one of the pixi workplace (`PIXI_PROJECT_ROOT`).

Let's create a task
```yaml
[tasks]
make_dir = 'mkdir testdir'
```
If you run this task, it's going to create `$PIXI_PROJECT_ROOT/testdir` and not `$INIT_CWD/testdir`.
What you want is to run pixi in the `INIT_CWD` so take the time to change your `./something` to `$INIT_CWD/something`.

## Read-only file system (os error 30)

This is related to the previous problem: pixi is using `PIXI_PROJECT_ROOT` as the `cwd`. 
It's going to try to write in `/opt/conf` wich is not allowed because the sif image is in read only.

To fix it, replace your `mkdir test` byt `mkdir $INIT_CWD/test`.

# How to install (dev)
> WARNING! This is a very early version of pixitainer, use at your own risk !

0. Install pixi
```bash
curl -fsSL https://pixi.sh/install.sh | sh
```

1. Install rattler
```bash
pixi global install rattler-build
```

2. Clone this repo
```bash
git clone https://github.com/RaphaelRibes/pixitainer.git
cd pixitainer
```

3. Build the pixitainer extension
```bash
rattler-build build --recipe recipe.yaml --output-dir $(pwd -P)/output
```

4. Install the pixitainer extension
```bash
pixi global install pixitainer --channel $(pwd -P)/output --channel conda-forge
```

It's easier to use this for now
```bash
export PATH=$PWD:$PATH
```
