[![Build Status](https://travis-ci.org/SUSE/sle2docker.svg)](https://travis-ci.org/SUSE/sle2docker)
[![Code Climate](https://codeclimate.com/github/SUSE/sle2docker/badges/gpa.svg)](https://codeclimate.com/github/SUSE/sle2docker)
[![Test Coverage](https://codeclimate.com/github/SUSE/sle2docker/badges/coverage.svg)](https://codeclimate.com/github/SUSE/sle2docker)


sle2docker is a convenience tool which creates SUSE Linux Enterprise images for
Docker.

The tool takes advantage of pre-built Docker images distributed by SUSE to
create the base Docker image that users can later customize using Docker's
integrated build system. The pre-built images are distributed by SUSE as RPMs.

Previous versions of the tool built the Docker images from KIWI templates
distributed by SUSE. This is still possible, but is deprecated: the recommended
way to operate is by using the pre-built images created by SUSE.

# Requirements

Ruby is required to execute the sle2docker program.

Docker must be running on the system and the user invoking sle2docker must
have the rights to interact with it.

# Installation

The recommended way to install sle2docker is via zypper:

```
sudo zypper in sle2docker
```

However sle2docker can be installed via gem:

```
sudo gem install --no-format-exec sle2docker
```

The `--no-format-exec` is recommended otherwise the `sle2docker` binary will
be prefixed with the ruby version installed on the system (eg: the binary on
SLE12 would be called `sle2docker.ruby2.1`).

# How it works

sle2docker can be used either to build the Docker images from sources or to
use the pre-built ones shipped by SUSE via RPMs.

Using the pre-built images is the recommended way. Building images from sources
is going to be removed in the future.

## Using the pre-built images

SUSE publishes pre-built Docker images for different version of SUSE Linux
Enterprise via RPMs.

sle2docker takes care of importing the official images and activating them. The
activation process adds the right repositories and credentials to the image.

## Building the images from sources (deprecated)

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

This section covers both the process of building the images from sources (now
deprecated) and the new recommended way of activating the pre-built images
released by SUSE.

## Using the pre-built images

To use a pre-built image it is necessary to activate it. The activation process
imports the pre-built image and adds the right repositories to it.

To activate the pre-built image use the following command:

```
# sle2docker activate IMAGE_NAME
```

Note well: this command requires administrator privileges to run.


To list the available pre-built images use the following command:

```
$ sle2docker list
Available pre-built images:
 - sles11sp3-docker.x86_64-1.0.0-Build1.3
 - sles12-docker.x86_64-1.0.0-Build7.4

Available templates:
  - SLE11SP2
  - SLE11SP3
  - SLE12
```

### Activating SLE12 images

Currently the activation of a SLE12 image copies the SUSE Customer Center credentials
from the Docker host into the final image.

### Activating SLE11 images

The activation of a SLE11 image requires the user to enter his NCC credentials.
By default the mirror credentials of NCC are asked in an interactive way, however
it is also possible to specify them from the command line:

```
sle2docker activate -u <username> -p <password> IMAGE
```

It is possible to specify only the username and let sle2docker ask the password later
in the interactive way:

```
sle2docker activate -u <username> IMAGE
```

### Subscription Management Tool integration

It is possible to download all the required packages from a local
Subscription Management Tool (SMT) instance:

```
sle2docker activate -s SMT_SERVER_HOSTNAME/repo IMAGE
```

By default sle2docker assumes the contents of the SMT server are served over
HTTPS. To force the retrieval of the package over plain HTTP use the
following command:

```
sle2docker activate -s SMT_SERVER_HOSTNAME/repo --disable-https TEMPLATE
```

Example: Say the FQDN of your SMT is mysmt.company.com and you want to activate a SLE12 Docker image.
The corresponding call to sle2docker would look like this:

```
sle2docker activate -s mysmt.company.com/repo --disable-https sles12-docker.x86_64-1.0.0-Build7.4
```

By default sle2docker expects the SMT instance to not require any form of
authentication. However it is possible to specify the access credentials by
using the following command:

```
sle2docker activate -s SMT_SERVER_HOSTNAME -u USERNAME -p PASSWORD IMAGE
```

## Building the images from sources (deprecated)

To build a template just use the following command:

```
sle2docker build TEMPLATE
```

A list of the available templates may be obtained by running:

```
sle2docker list
```

A template rendered with user provided data can be printed by using the
following command:

```
sle2docker show TEMPLATE
```

### SUSE Customer Center integration

By default sle2docker downloads all the required packages from SUSE
Customer Center (SCC). Before the build starts sle2docker ask the user
his credentials. It is possible to start a build in a non interactive way by
using the following command:

```
sle2docker build -u USERNAME -p PASSWORD TEMPLATE_NAME
```


### Subscription Management Tool integration

It is possible to download all the required packages from a local
Subscription Management Tool (SMT) instance:

```
sle2docker build -s SMT_SERVER_HOSTNAME/repo TEMPLATE
```

By default sle2docker assumes the contents of the SMT server are served over
HTTPS. To force the retrieval of the package over plain HTTP use the
following command:

```
sle2docker build -s SMT_SERVER_HOSTNAME/repo --disable-https TEMPLATE
```

Example: Say the FQDN of your SMT is mysmt.company.com and you want to build a SLE12 Docker image.
The corresponding call to sle2docker would look like this:

```
sle2docker build -s mysmt.company.com/repo --disable-https SLE12
```

By default sle2docker expects the SMT instance to not require any form of
authentication. However it is possible to specify the access credentials by
using the following command:

```
sle2docker build -s SMT_SERVER_HOSTNAME -u USERNAME -p PASSWORD TEMPLATE
```

### Additional repos for the base image

When building images with `sle2docker`, only the main and updates repositories
is used for installing needed packages. If you want to obtain extra packages
you need to tweak the templates.

Templates are .erb files located under `lib/templates`. If you installed `sle2docker`
via `zypper`, the templates are located under
`/usr/lib64/ruby/gems/2.1.0/gems/sle2docker-0.2.4/lib/templates` (paths may differ).
You may then add your own `<repository>` section:

```
  <repository type="rpm-md" alias="YOUR_ALIAS" <%= 'imageinclude="true"' if include_build_repos %>>
    <source path="PATH_TO_YOUR_REPO"/>
  </repository>
```

### Preservation of repository information

If you want to preserve the repository information in the final image, you need
to supply the `--include-build-repos` parameter to the `build` command.


# License

sle2docker is released under the MIT license.
