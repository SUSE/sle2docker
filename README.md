sle2docker is a convenience tool which creates SUSE Linux Enterprise images for
[Docker](http://docker.com).

The tool relies on [KIWI](https://github.com/openSUSE/kiwi) and Docker itself
to build the images.

Packages can be fetched either from Novell Customer Center (NCC) or from a local
Subscription Management Tool (SMT).

Using DVD sources is currently unsupported.

# Requirements

Ruby is required to execute the sle2docker program.

Docker must be running on the system and the user invoking sle2docker must
have the rights to interact with it.

# Installation

sle2docker can be installed from rpm packages using zypper or using the
gem utility.

Note well: when installing sle2docker using gem use the following command:

```
sudo gem install --no-format-exec sle2docker
```

Otherwise the `sle2docker` binary will be prefixed with the ruby version you
have installed (eg: the binary on SLE12 would be called `sle2docker.ruby2.1`).

# How it works

The sle2docker gem comes with a set of supported SLE templates. These are KIWI
source files which are filled with the informations provided by the user at
runtime.

The image creation happens inside of
[this](https://registry.hub.docker.com/u/opensuse/kiwi/)
Docker image. This has to be done because on recent systems (like SLE12) KIWI
cannot create SLE11 images. That happens because building a SLE11 systems
requires the `db45-utils` package to be installed on the host system; this
package is obsolete and is not available on SLE12.

The Docker image used by sle2docker is based on openSUSE and it's freely
downloadable from the [Docker Hub](https://registry.hub.docker.com/). The image
is built using Docker's build system by starting from the
[official openSUSE image](https://registry.hub.docker.com/_/opensuse/).
The `Dockerfile` used to create this image can be found inside of
[this](https://github.com/openSUSE/docker-containers) repository.

sle2docker automatically fetches the `opensuse/kiwi` image if not found on the
system.

# Usage

To build a template just use the following command:

```
sle2docker <template name>
```

A list of the available templates can be obtained by running:

```
sle2docker -l
```

By default sle2docker assumes packages are going to be fetched from NCC, hence
it will ask for NCC's credentials.

It's possible to use a local SMT instance by using the `-s` option:

```
sle2docker -s <smt server> <path_to_template_dir>
```

This will assume your SMT instance does not require authentication and serves
its contents over HTTPS.

The `-u <username>` and the `-p <password>` options can be used to specify
the credentials required to access the remote repositories.
To retrieve contents over HTTP use the `--disable-https` option.

For more details consult the output of `sle2docker --help`.

# License

sle2docker is released under the MIT license.
