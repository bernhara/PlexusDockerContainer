#

# docker build -t plexus_gpu .
# nvidia-docker run -ti --rm plexus_gpu

FROM nvidia/cudagl:9.2-devel-ubuntu18.04

ENV NVIDIA_REQUIRE_DRIVER "driver>=390"

RUN apt-get update && \
    apt-get -y install \
       cmake \
       git \
       emacs-nox && \
    apt-get clean

RUN apt-get -y install \
       libceres-dev \
       libeigen3-dev \
       libgoogle-glog-dev \
       libboost-dev libboost-program-options-dev libboost-filesystem-dev libboost-graph-dev libboost-regex-dev libboost-system-dev \
       libfreeimage-dev \
       libglew-dev \
       libgflags-dev \
       libqt5opengl5-dev \
       libcgal-dev \
       && \
    apt-get clean

#
# Get plexus source code
# FIXME: should be take from it's source respistory
#
COPY plexus.tar.xz /tmp/plexus.tar.xz
RUN mkdir -p /opt/PlexusSrc && xzcat /tmp/plexus.tar.xz | tar --extract --directory=/opt/PlexusSrc --file=-

#
# Plexus GPU compilation
#
WORKDIR /opt/PlexusSrc

RUN mkdir build && cd build && cmake -D BOOST_STATIC=OFF .. && make
 
#

#
# additional files
#

COPY opt/ /opt/

#
# still useful?
#
ENV MESU_FLAG=0
ENV OPT=/opt
ENV WORKDIR_ROOT=/tmp
ENV DEPTH=1
ENV IMAGE_SOURCE_DIR=/data/source
ENV IMAGE_OUTPUT_DIR=/data/output
