# syntax=docker/dockerfile:1
# This file builds a Docker base image for its use in FORCE

# Copyright (C) 2020-2025 Gergely Padányi-Gulyás (github user fegyi001),
#                         David Frantz
#                         Fabian Lehmann
#                         Wilfried Weber
#                         Peter A. Jonsson

# Run "docker buildx imagetools inspect ghcr.io/osgeo/gdal:ubuntu-small-3.11.3"
# to get the sha256 of the manifest list so image is multi-arch.
FROM ghcr.io/osgeo/gdal:ubuntu-small-3.11.3@sha256:a7c6f68b9868420861be6dd51873ac464fc587ae3b6206b546408d67d697328e AS internal_base

# Keep deb packages in Docker cache and increase the number of retries
# when downloading the packages.
RUN rm -f /etc/apt/apt.conf.d/docker-clean && \
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache && \
    echo 'Acquire::Retries "10";' > /etc/apt/apt.conf.d/80-retries

FROM internal_base AS builder


# Install folder for custom builds
ENV INSTALL_DIR=/opt/install/src

# Add login-script for UID/GID-remapping.
COPY --chown=root:root --link remap-user.sh /usr/local/bin/remap-user.sh

# Refresh package list & upgrade existing packages
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
# Disable interactive frontends.
export DEBIAN_FRONTEND=noninteractive && \
apt-get -y update && apt-get -y upgrade && \
# Install required tools.
apt-get -y install \
  ca-certificates \
  ccache \
  curl \
  dirmngr \
  gpg \
  software-properties-common \
  dos2unix \
  git \
  build-essential \
  cmake \
  gosu \
  libgsl0-dev \
  libjansson-dev \
  libssl-dev \
#  libudunits2-dev \ required by sf package, but has gdal dependency issues, disabled for now
#  libproj-dev \     required by sf package, but has gdal dependency issues, disabled for now
#  libgdal-dev \     required by sf package, but has gdal dependency issues, disabled for now
#  libsqlite3-dev \  required by sf package, but has gdal dependency issues, disabled for now
#  libgeos-dev \     required by sf package, but has gdal dependency issues, disabled for now
  lockfile-progs \
  rename \
  libcurl4-openssl-dev \
  python3-pip \
  python-is-python3 \
  parallel \
  r-base \
  wget \
  tini \
  aria2

# Install Python packages
# NumPy is needed for OpenCV, gsutil for level1-csd, landsatlinks for level1-landsat (requires gdal/requests/tqdm)
#==1.26.4  # test latest version
#==1.14.1 # test latest version
RUN pip3 install --break-system-packages --no-cache-dir \
    numpy \
    gsutil \
    scipy \
    git+https://github.com/ernstste/landsatlinks.git

# Install R packages.
# Ccache size set from "ccache -s -v" after built from an empty cache.
# Other ccache settings from https://dirk.eddelbuettel.com/blog/2017/11/27/.
RUN --mount=type=cache,id=force-base-r,target=/root/.cache \
mkdir -p $HOME/.R $HOME/.config/ccache && \
echo -n "CCACHE=ccache\nCC=\$(CCACHE) gcc\nCXX=\$(CCACHE) g++\nCXX11=\$(CCACHE) g++\nCXX14=\$(CCACHE) g++\nCXX17=\$(CCACHE) g++\nFC=\$(CCACHE) gfortran\nF77=\$(CCACHE) gfortran\n" > $HOME/.R/Makevars && \
echo -n "max_size = 200M\nsloppiness = include_file_ctime\nhash_dir = false\n" > $HOME/.config/ccache/ccache.conf && \
Rscript -e 'install.packages("rmarkdown", Ncpus = parallel::detectCores(), repos="https://cloud.r-project.org"); if (!library(rmarkdown, logical.return=T)) quit(save="no", status=10)' && \
Rscript -e 'install.packages("plotly", Ncpus = parallel::detectCores(), repos="https://cloud.r-project.org"); if (!library(plotly, logical.return=T)) quit(save="no", status=10)' && \
# sf: gdal dependency issues, disabled for now
#Rscript -e 'install.packages("sf", repos="https://cloud.r-project.org"); if (!library(sf, logical.return=T)) quit(save="no", status=10)' && \
Rscript -e 'install.packages("snow", Ncpus = parallel::detectCores(), repos="https://cloud.r-project.org"); if (!library(snow, logical.return=T)) quit(save="no", status=10)' && \
Rscript -e 'install.packages("snowfall", Ncpus = parallel::detectCores(), repos="https://cloud.r-project.org"); if (!library(snowfall, logical.return=T)) quit(save="no", status=10)' && \
Rscript -e 'install.packages("getopt", Ncpus = parallel::detectCores(), repos="https://cloud.r-project.org"); if (!library(getopt, logical.return=T)) quit(save="no", status=10)' && \
rm -rf $HOME/.R $HOME/.config/ccache && \
#
# Build OpenCV from source, only required parts
mkdir -p $INSTALL_DIR/opencv && cd $INSTALL_DIR/opencv && \
curl -LO -fsS https://github.com/opencv/opencv/archive/4.12.0.zip \
  && unzip 4.12.0.zip && \
mkdir -p $INSTALL_DIR/opencv/opencv-4.12.0/build && \
cd $INSTALL_DIR/opencv/opencv-4.12.0/build && \
cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DBUILD_TESTS=OFF \
  -DBUILD_PERF_TESTS=OFF \
  -DBUILD_EXAMPLES=OFF \
  -DBUILD_LIST=ml,imgproc\
  -DWITH_GTK=OFF \
  -DWITH_V4L=OFF \
  -DWITH_ADE=OFF \
  -DWITH_PNG=OFF \
  -DWITH_JPEG=OFF \
  -DWITH_TIFF=OFF \
  -DWITH_WEBP=OFF \
  -DWITH_OPENJPEG=OFF \
  -DWITH_JASPER=OFF \
  -DWITH_OPENEXR=OFF \
  -DWITH_IMGCODEC_HDR=OFF \
  -DWITH_IMGCODEC_SUNRASTER=OFF \
  -DWITH_IMGCODEC_PFM=OFF \
  -DWITH_IMGCODEC_PXM=OFF \
  -DWITH_IMGCODEC_GIF=OFF \
  -DOPENCV_GENERATE_PKGCONFIG=ON \
  .. \
  && make -j$(nproc) \
  && make install \
  && make clean && \
#
# Cleanup after successfull builds
cd && rm -rf $INSTALL_DIR

# De-sudo this image
ENV HOME=/home/ubuntu

# Use this user by default
USER ubuntu

WORKDIR /home/ubuntu

USER root

ENTRYPOINT ["/usr/local/bin/remap-user.sh"]
