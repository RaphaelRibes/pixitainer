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
- [ ] Pixi package that I can add as a plugin.
- [ ] Adding options to the plugin.
- [ ] Modular receipe ?
- [ ] Publish and go back to step 3 until WW3, messia'h or death of the internet

# Common problem

> ERROR  : Failed to create mount namespace: mount namespace requires privileges, check Apptainer installation

This problems appears on ubuntu systems, you have to check 2 things:

- If `sysctl kernel.unprivileged_userns_clone` returns `kernel.unprivileged_userns_clone = 0`, type `sudo sysctl -w kernel.unprivileged_userns_clone=1`
- If `sysctl kernel.apparmor_restrict_unprivileged_userns` returns `kernel.apparmor_restrict_unprivileged_userns = 1`, type `sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0`
