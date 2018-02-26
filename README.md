[![Build Status](https://travis-ci.org/SUSE/sle2docker.svg)](https://travis-ci.org/SUSE/sle2docker)
[![Code Climate](https://codeclimate.com/github/SUSE/sle2docker/badges/gpa.svg)](https://codeclimate.com/github/SUSE/sle2docker)
[![Test Coverage](https://codeclimate.com/github/SUSE/sle2docker/badges/coverage.svg)](https://codeclimate.com/github/SUSE/sle2docker)

sle2docker is a convenience tool which imports the pre-built SUSE Linux Enterprise
images for Docker.

The tool takes advantage of pre-built Docker images distributed by SUSE to
create the base Docker image that users can later customize using Docker's
integrated build system. The pre-built images are distributed by SUSE as RPMs.

Pre-built images do not have repositories configured but zypper will
automatically have access to the right repositories when the Docker host has a
SLE subscription that provides access to the product used in the image. For
more details read the "Customizing the images" section below.

Previous versions of the tool built the Docker images from KIWI templates
distributed by SUSE. This is no longer possible.

# Requirements

Ruby is required to execute the sle2docker program.

Docker must be running on the system and the user invoking sle2docker must
have the rights to interact with it.

# Installation

The recommended way to install sle2docker is via zypper:

```
sudo zypper in sle2docker
```

However sle2docker can also be installed via gem:

```
sudo gem install --no-format-exec sle2docker
```

The `--no-format-exec` is recommended otherwise the `sle2docker` binary will
be prefixed with the ruby version installed on the system (e.g.: the binary on
SLE12 would be called `sle2docker.ruby2.1`).

# Usage

To list the available pre-built images use the following command:

```
sle2docker list
Available pre-built images:
 - sles11sp3-docker.x86_64-1.0.0-Build1.3
 - sles12-docker.x86_64-1.0.0-Build7.4
```

To activate the pre-built image use the following command:

`sle2docker activate IMAGE_NAME`

# Customizing the images

To create custom Docker images based on the official ones use
[Docker's integrated build system](http://docs.docker.com/reference/builder/).

The pre-built images do not have any repository configured. They
contain a [zypper service](https://github.com/SUSE/container-suseconnect) that
contacts either the SUSE Customer Center (SCC) or your Subscription
Management Tool (SMT) server according to the configuration of the SLE host
running the Docker container. The service obtains the list of repositories
available for the product used by the Docker image.

There is no need to add any credential to the Docker image because the machine
credentials are automatically injected into the container by the docker daemon.
These are injected inside of the `/run/secrets` directory. The same applies to
the `/etc/SUSEConnect` file of the host system, which is automatically injected
into the `/run/secrets`.

The contents of the `/run/secrets` directory are never committed to a Docker
image, hence there's no risk of leaking your credentials.

To obtain the list of repositories invoke:

`zypper ref -s`

This will automatically add all the repositories to your container. For each
repository added to the system a new file is going to be created under
`/etc/zypp/repos.d`. The URLs of these repositories include an access token
that automatically expires after 12 hours. To renew the token just call the
`zypper ref -s` command. It is totally fine, and secure, to commit these files
to a Docker image.

If you want to use a different set of credentials, place a custom
`/etc/zypp/credentials.d/SCCcredentials` with the machine credentials
having the subscription you want to use inside of the Docker image.
The same applies to the `SUSEConnect` file: if you want to override the one
available on the host system running the Docker container you have to add a
custom `/etc/SUSEConnect` file inside of the Docker image.

## Creating a custom SLE12 image

This Dockerfile creates a simple Docker image based on SLE12:

```
FROM suse/sles12:latest

RUN zypper ref -s
RUN zypper -n in vim
```

When the Docker host machine is registered against an internal SMT
server the Docker image requires the ssl certificate used by SMT:

```
FROM suse/sles12:latest

# Import the crt file of our private SMT server
ADD http://smt.test.lan/smt.crt /etc/pki/trust/anchors/smt.crt
RUN update-ca-certificates

RUN zypper ref -s
RUN zypper -n in vim
```

## Creating a custom SLE11SP3 image

This Dockerfile creates a simple Docker image based on SLE11:

```
FROM suse/sles11sp3:latest

RUN zypper ref -s
RUN zypper -n in vim
```

When the Docker host machine is registered against an internal SMT
server the Docker image requires the ssl certificate used by SMT:

```
FROM suse/sles11sp3:latest

# Import the crt file of our private SMT server
ADD http://smt.test.lan/smt.crt /etc/ssl/certs/smt.pem
RUN c_rehash /etc/ssl/certs

RUN zypper ref -s
RUN zypper -n in vim
```

# Additional documentation

For more information visit the
[SUSE's Docker documentation](https://www.suse.com/documentation/sles-12/book_sles_docker/data/book_sles_docker.html)
page.

# License

sle2docker is released under the MIT license.
