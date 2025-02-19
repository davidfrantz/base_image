# This file builds a Docker base image for its use in other projects

# Copyright (C) 2020-2025 Gergely Padányi-Gulyás (github user fegyi001),
#                         David Frantz
#                         Fabian Lehmann
#                         Wilfried Weber
#                         Peter A. Jonsson

FROM ghcr.io/osgeo/gdal:ubuntu-small-3.10.2 AS builder

# disable interactive frontends
ENV DEBIAN_FRONTEND=noninteractive 

# Refresh package list & upgrade existing packages 
RUN apt-get -y update && apt-get -y upgrade && \
#
# Add PPA for Python 3.x and R 4.0
apt-get -y install \
  ca-certificates \
  curl \
  dirmngr \
  gpg \
  software-properties-common && \
curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xE298A3A825C0D65DFD57CBB651716619E084DAB9" | gpg --dearmor -o /etc/apt/keyrings/r-project-keyring.gpg && \
add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -sc)-cran40/" && \
#
# Install libraries
apt-get -y install \
  wget \
  dos2unix \
  git \
  build-essential \
  libgdal-dev \
  autoconf \
  autoconf-archive \
  automake \
  libgsl0-dev \
  lockfile-progs \
  rename \
  apt-utils \
  sysstat \
  cmake \
  libgtk2.0-dev \
  pkg-config \
  libcurl4-openssl-dev \
  libxml2-dev \
  gfortran \
  libglpk-dev \
  libavcodec-dev \
  libavformat-dev \
  libopencv-dev \
  libswscale-dev \
  python3-pip \
  python-is-python3 \
  pandoc \
  parallel \
  libudunits2-dev \
  r-base \
  aria2 && \
#
# NumPy is needed for OpenCV, gsutil for level1-csd, landsatlinks for level1-landsat (requires gdal/requests/tqdm)
pip3 install --break-system-packages --no-cache-dir \
    numpy==1.26.4  \
    gsutil \
    scipy==1.14.1 \
    gdal==$(gdal-config --version) \
    git+https://github.com/ernstste/landsatlinks.git && \
#
# Install R packages
Rscript -e "install.packages('pak', repos='https://r-lib.github.io/p/pak/dev/')" && \
Rscript -e "pak::pkg_install(c('rmarkdown','plotly', 'sf', 'snow', 'snowfall', 'getopt'))" && \
#
# Clear installation data
apt-get clean && rm -r /var/cache/ /root/.cache /tmp/Rtmp*

# Install folder
ENV INSTALL_DIR=/opt/install/src \
    HOME=/home/ubuntu \
    PATH="$PATH:/home/ubuntu/bin"

# Cleanup after successfull builds
RUN rm -rf $INSTALL_DIR
#RUN apt-get purge -y --auto-remove apt-utils cmake git build-essential software-properties-common

RUN chgrp ubuntu /usr/local/bin && \
  install -d -o ubuntu -g ubuntu -m 755 /home/ubuntu/bin

# Use this user by default
USER ubuntu

WORKDIR /home/ubuntu
