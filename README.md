# ls2
Life Sciences Software

# Overview
The Life Sciences Software (LS2) project aims to normalize and automate the build of software packages across multiple technologies.

## Components
LS2 is a collection of open source components:

* We use [EasyBuild](https://easybuilders.github.io/easybuild) to compile software packages and provide reproducibility.
* EasyBuild uses Environment Modules to manage software packages, and LS2 uses [Lmod](https://github.com/TACC/Lmod) to provide Environment Modules.
* LS2 can produce [Docker](https://www.docker.com) containers with one or more software packages.
* LS2 uses [Ubuntu](https://www.ubuntu.com) as its primary platform, and creates Docker containers based on Ubuntu containers. Note that EasyBuild uses CentOS as their primary platform, and extending LS2 to CentOS would likely be pretty easy.

## LS2 Architecture
This is the hierarchy of LS2 containers:

Name/Repo | FROM | Reason | Notes
--- | --- | --- | ---
<https://github.com/FredHutch/ls2_ubuntu> | ubuntu | simple 'freeze' of the public ubuntu container | OS pkgs added: bash, curl, git
<https://github.com/FredHutch/ls2_lmod> | ls2_ubuntu | Adding Lmod | OS pkgs added: lua
<https://github.com/FredHutch/ls2_easybuild> | ls2_lmod | Adding EasyBuild | OS pkgs added: python
<https://github.com/FredHutch/ls2_easybuild_toolchain> | ls2_easybuild | Adding EasyBuild toolchain(s) | OS pkgs added: libibverbs-dev, lib6c-dev, bzip2, unzip, make, xz-utils, awscli
<https://github.com/FredHutch/ls2> | ls2_easybuild_toolchain | This 'demo' repo | does not produce a container directly
<https://github.com/FredHutch/ls2_r> | ls2_easybuild_toolchain | Our 'R' build | easy_update.py, custom easyconfigs
<https://github.com/FredHutch/ls2_python> | ls2_easybuild_toolchain | Our 'Python' build | easy_update.py, custom easyconfigs

### Tags
In general, tagging goes: `fredhutch/ls2_<package name>:<package version>[_<date>]`

Ex: `fredhutch/ls2_r:3.4.3` or `fredhutch/ls2_ubuntu:16.04_20180118`

Package versions should generally be the released version, and use the optional 'date' area for private sub-versions.

Git repos should be tagged. Container images should be pushed to Dockerhub. Tags should match.

## Container Architecture
* default user 'neo' (UID 500, GID 500) /home/neo
* ls2 scripts are installed in /ls2
* Lmod and EasyBuild are installed into /app
* EasyConfigs from repo are copied into /app/fh_easyconfigs
* sources are copied and downloaded into /app/sources
* EasyBuild is run in a single 'RUN' command to reduce container layer size:
  * installs specified OS packages
  * runs EasyBuild
  * uninstalls specified OS packages (not always all of them)

## Use Cases

### Create a container
The initial reason for LS2 is to create Docker containers with EasyBuilt software packages to mirror those available on our HPC systems. We realize that containerizing common software packages will be key in leveraging many new technologies like AWS Batch.

The intention is to install a single software package in each container and use multiple LS2 containers in sequence to achieve a pipeline.

Having the same software packages compiled in the same ways as we have deployed to our traditional HPC cluster enables users to focus on pipeline building and not software troubleshooting when moving to different compute methods.

### EasyBuild testing
Building or updating an EasyConfig can be time-consuming. Many existing technologies help to automated the `docker build` process, so LS2 opens these up to EasyBuild. Even if you run EasyBuild traditionally to deploy built packages to a private directory or shared software archive, you can test those EasyConfigs in an LS2 build to ensure your production build will be successful.

As we are building in a container with minimal installed packages, it is easy to find OS dependencies that are unstated in EasyConfigs. Some examples of this range from pkg-config (a default package in CentOS but not Ubuntu) to utilities like unzip and bzip2. Some dependencies are intentional like OpenSSL (better to pull presumably-updated OS packages than possibly stale EasyBuild packages) and some are easy to miss when you are building in a non-minimal OS (ex: make is not present in the foss-n toolchains).

### Manage a traditional archive
We use EasyBuild to install software packages onto an NFS volume. This volume is then shared to our HPC and other systems to enable software package use on those platforms. LS2 can still be used to deploy packages in this way by mounting the NFS volume into the container and performing a build. This process isolates the EasyConfig development process from your live package archive or volume.

# HOWTO
There are two sections here. First case covers building an existing or new EasyConfig, and the second covers using a built container to deploy a software package to an existing software archive or volume.

## Building...
Steps to build a new LS2 container are pretty straight-forward, but assume some knowledge of EasyBuild, Lmod, and Docker.

### Existing easyconfigs
If you are wanting to build an existing easyconfig (from the EasyBuild [easyconfig repo](https://github.com/easybuilders/easybuild--easyconfigs), you can do so without any file editing:

1. clone the FredHutch/ls2 repo
1. run `docker build . --tag [ls2_]<eb_pkg_name>:<eb_pkg_ver> --build-arg EB_NAME=<eb_file_name_without_dot_eb> (this will build the container)
1. run `docker push <tag>` if you want your container image in Dockerhub (ensure you are logged in to Dockerhub by running `docker login`)

### Custom easyconfigs
If you want to customize the config (edit the .eb file) then copy this repo (taken from [these instructions](https://help.github.com/articles/duplicating-a-repository/)):
1. github.com: create a new repo in github and do not pre-populate with README.md - this should get you the 'Quick setup' page
1. cli: `git clone --bare https://github.com/FredHutch/ls2.git` (or `git clone --bare ssh://git@github.com/FredHutch/ls2.git`)
1. cli: `cd ls2.git`
1. edit README.md
1. cli: `git push --mirror https://github.com/<new repo URL.git>`
1. cli: `cd ..`
1. cli: `rm -rf ls2.git`
1. cli: `git clone <new_repo>`
1. cli: `cd <new_repo>`
1. Add required EasyConfig files that are not in the EasyBuild repo to /easyconfigs in new repo
1. Add sources to the sources/ folder of the repo (for sources <50MB in size that cannot easily be downloaded)
1. Add URLs to sources/download_sources.sh to download sources during `docker build` (for larger sources, perhaps placed in the cloud for easier download ex: java)
1. If you need additional OS package, edit the Dockerfile to adjust the following:
  * INSTALL_OS_PKGS - these packages will be installed (by root) prior to running EasyBuild
  * UNINSTALL_OS_PKGS - these packages will be uninstalled at the end of running EasyBuild
1. Run `docker build . --tag [ls2_]<eb_pkg_name>:<eb_pkg_ver>`
1. Run `docker push ls2_<eb_pkg_name>:<eb_pkg_ver>`  (ensure you are logged in to Dockerhub by running `docker login`)

## Deploy new software packge to /app (our NFS software archive)
We keep our deployed software package on an NFS volume that we mount at /app on our systems (can you guess why LS2 builds into /app rather than .local in the container?). In order to use your recently build LS2 software package container to deploy the same package into our /app NFS volume, use these steps:

1. Complete above steps to produce a successful container with your software package
1. Run that container with our package deploy location mapped in to /app like this: `docker run -ti --rm --user root -v /app:/app -e OUT_UID=${UID} -e OUT_GID=<outside GID=158372> fredhutch/ls2_<eb_pkg_name>:<eb_pkg_ver> /bin/bash /ls2/deploy.sh`

The steps above will use the container you just built, but will re-build the easyconfig and all dependencies into the "real" /app, using Lmod, EasyBuild, and dependent packages from the "real" /app.

Note that this overrides the Lmod in the container, so if version parity is important to you, you'll always want to keep your /app Lmod in sync with the LS2 Lmod. You can deploy Lmod to /app using the [LS2 Lmod repo](https://github.com/FredHutch/ls2_lmod).

Details: take a look into the scritps, but this procedure re-runs the build step from the Dockerfile as root in order to install/uninstall OS packages, and adjusts the uid/gid to match your deployment outside the container.
