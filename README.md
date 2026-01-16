# Pixitainer

Pixi is cool, apptainer is cool, let's make them both work togerther !

## Why ?

Singularity/apptainer is very used in bioinformatics, it's at the hearth of analyses pipelines, but it's a headache to put in place.
In another hand, pixi is fast, easy to use but it's not a container and so harder to keep intact for a long period of time.
The idea behind pixitainer is to put a pixi environment into a apptainer container, so you can freeze your fast pace working environment into a container easily !

## How ?
The best thing to do will be to add this way as a [pixi extension](https://pixi.sh/latest/integration/extensions/introduction/), so we just have to type `pixi container` and some option and tada !
For now, there is the `pixitainer.def` with ideas how to make it work.
Here I have an example of use of `pixitainer.def` for a [DNA assembler project](https://github.com/MickaelCQ/RaMiLass.git) during my master.

TODO:
- [x] Receipe that works.
- [x] Pixi package that I can add as a extension.
- [x] Adding options to the extension.
- [ ] Documentation and testings.
- [ ] Publish
- [ ] Go back to step 3 until WW3, messia'h or death of the internet

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

