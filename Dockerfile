# This file builds a Docker base image for its use in FORCE

# Copyright (C) 2020-2025 Gergely Padányi-Gulyás (github user fegyi001),
#                         David Frantz
#                         Fabian Lehmann
#                         Wilfried Weber
#                         Peter A. Jonsson

FROM ghcr.io/osgeo/gdal:ubuntu-small-3.11.3 AS builder

# disable interactive frontends
ENV DEBIAN_FRONTEND=noninteractive 

# Install folder for custom builds
ENV INSTALL_DIR=/opt/install/src

# Refresh package list & upgrade existing packages 
RUN apt-get -y update && apt-get -y upgrade && \
#
# Install wget and add Key for R 4.0
apt-get -y install \
  wget && \
  wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | \
  tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc && \
#
# Install remaining required tools
apt-get -y install \
  ca-certificates \
  dirmngr \
  gpg \
  software-properties-common \
  dos2unix \
  git \
  build-essential \
  cmake \
  libgsl0-dev \
  libjansson-dev \
  libssl-dev \
  libudunits2-dev \
  lockfile-progs \
  rename \
  libcurl4-openssl-dev \
  python3-pip \
  python-is-python3 \
  parallel \
  r-base \
  aria2 && \
#
# Install Python packages
# NumPy is needed for OpenCV, gsutil for level1-csd, landsatlinks for level1-landsat (requires gdal/requests/tqdm)
#==1.26.4  # test latest version
#==1.14.1 # test latest version
pip3 install --break-system-packages --no-cache-dir \
    numpy \
    gsutil \
    scipy \
    gdal==$(gdal-config --version) \
    git+https://github.com/ernstste/landsatlinks.git && \
#
# Install R packages
Rscript -e 'install.packages("rmarkdown",   repos="https://cloud.r-project.org")' && \
Rscript -e 'install.packages("plotly",      repos="https://cloud.r-project.org")' && \
Rscript -e 'install.packages("sf",          repos="https://cloud.r-project.org")' && \
Rscript -e 'install.packages("snow",        repos="https://cloud.r-project.org")' && \
Rscript -e 'install.packages("snowfall",    repos="https://cloud.r-project.org")' && \
Rscript -e 'install.packages("getopt",      repos="https://cloud.r-project.org")' && \
#
# Build OpenCV from source, only required parts
mkdir -p $INSTALL_DIR/opencv && cd $INSTALL_DIR/opencv && \
wget https://github.com/opencv/opencv/archive/4.12.0.zip \
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
  && make -j7 \
  && make install \
  && make clean && \
#
# Cleanup after successfull builds
cd && rm -rf $INSTALL_DIR && \
apt-get clean && \
rm -r /var/cache/ /var/lib/apt/lists/* && \
#
# set permissions
chmod -R 0777 /home/ubuntu

# De-sudo this image
ENV HOME=/home/ubuntu \
    PATH="$PATH:/home/ubuntu/bin"

# Use this user by default
USER ubuntu

WORKDIR /home/ubuntu
