#!/bin/bash


# Useful environment variables
# PREFIX - installation prefix
# RECIPE_DIR - path to recipe directory

SYSTEM_PREFIX=/usr

LOCAL_PREFIX=$PREFIX

# Uncomment the following line when debugging:
LOCAL_PREFIX=$RECIPE_DIR/local  # to cache succesful installations

mkdir -p $LOCAL_PREFIX

PYTHON=$SYS_PYTHON
PYTHON_INCLUDE_DIR=$($PYTHON -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())")
PYTHON_LIBRARY=$($PYTHON -c "import distutils.sysconfig as sc;print('{LIBDIR}/{LDLIBRARY}'.format_map(sc.get_config_vars()))")
echo "PYTHON_INCLUDE_DIR=$PYTHON_INCLUDE_DIR"
echo "PYTHON_LIBRARY=$PYTHON_LIBRARY"

export PATH=$LOCAL_PREFIX/bin:$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$SYSTEM_PREFIX/lib64:$SYSTEM_PREFIX/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=$LOCAL_PREFIX/lib64:$LOCAL_PREFIX/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=$PREFIX/lib64:$PREFIX/lib:$LD_LIBRARY_PATH

#
# Install system packages
#

# Installing system packages requires sudo
SUDO=
if [ ! -w $(dirname $SYSTEM_PREFIX) ] ; then
    SUDO=sudo
fi

# Make sure we have lsb_release
if ! [ -x "$(command -v lsb_release)" ]; then
  if [ -x "$(command -v yum)" ]; then
    $SUDO yum install --assumeyes redhat-lsb-core
  elif [ -x "$(command -v apt)" ]; then
    $SUDO apt install --assume-yes lsb-core
  else
    echo "Need lsb_release to continue. EXITING."
    exit 1
  fi
fi

TARGET=`lsb_release -i -s`-`lsb_release -c -s`
echo "TARGET=$TARGET" # e.g. Ubuntu-xenial, CentOS-Core

COMMON_SYSTEM_PACKAGES="wget make git autoconf autoconf-archive automake libtool"

case $TARGET in
CentOS*)
  SYSTEM_INSTALL_COMMAND="$SUDO yum install --assumeyes"
  #BOOST_PREFIX=$SYSTEM_PREFIX
  BOOST_PREFIX=$LOCAL_PREFIX
  BOOST_LIBDIR=$BOOST_PREFIX/lib
  BOOST_PACKAGES2="boost-context \
                  boost-thread \
                  boost-program-options \
                  boost-regex \
                  boost-system \
                  boost-chrono \
                  boost-filesystem \
                  boost-devel \
                  boost-static"
  SYSTEM_PACKAGES="$COMMON_SYSTEM_PACKAGES $BOOST_PACKAGES \
                   zlib-devel libpng-devel expat-devel \
                   gmp-devel mpfr-devel libmpc-devel \
                   unzip ncurses-devel \
                   libarchive-devel xz-devel bzip2-devel \
                   golang maven flex \
                   libedit-devel"
  ;;
Ubuntu*)
  SYSTEM_INSTALL_COMMAND="$SUDO apt install --assume-yes"
  BOOST_PREFIX=$SYSTEM_PREFIX
  BOOST_LIBDIR=$BOOST_PREFIX/lib/x86_64-linux-gnu
  BOOST_PACKAGES="libboost-context-dev \
                   libboost-thread-dev libboost-program-options-dev \
                   libboost-regex-dev \
                   libboost-system-dev libboost-chrono-dev \
                   libboost-filesystem-dev"
  SYSTEM_PACKAGES="$COMMON_SYSTEM_PACKAGES $BOOST_PACKAGES \
                   zlib1g-dev \
                   cmake \
                   gcc-5 g++-5 \
                   curl libcurl4-openssl-dev \
                   libdouble-conversion-dev \
                   "
  ;;
*)
  echo "NOTIMPL TARGET=$TARGET"
  exit 1

esac

$SYSTEM_INSTALL_COMMAND $SYSTEM_PACKAGES 

#
# Install packages from source
#


AWSCPP_VERSION=1.3.10
GCC_VERSION=5.5.0
THRIFT_VERSION=0.10.0
GFLAGS_VERSION=2.2.0
GLOG_VERSION=0.3.4
LIBEVENT_VERSION=2.0.22
FOLLY_VERSION=2017.10.16.00

RAPIDJSON_VERSION=1.1.0
FLATBUFFERS_VERSION=1.7.1
ARROW_VERSION=0.7.1
CURL_VERSION=7.50.0
PROJ_VERSION=4.9.3
GDAL_VERSION=2.2.4
EXPAT_VERSION=2.2.0
LIBARCHIVE_VERSION=3.3.2
LLVM_VERSION=3.9.1
MAPDCORE_VERSION=3.6.0
BISONPP_VERSION=1.21

source $RECIPE_DIR/packages.sh

case $TARGET in
CentOS*)
  # CentOS gcc-4.8 is too old:
  install_gcc $LOCAL_PREFIX $LOCAL_PREFIX/bin/gcc
  export CC=$LOCAL_PREFIX/bin/gcc
  export CXX=$LOCAL_PREFIX/bin/g++

  # CentOS cmake-2.8 is too old:
  download_make_install_local https://internal-dependencies.mapd.com/thirdparty/cmake-3.7.2.tar.gz "" "" $LOCAL_PREFIX/bin/cmake
  export CMAKE=$LOCAL_PREFIX/bin/cmake

  # CentOS boost is compiled with gcc-4 that uses old ABI:
  install_boost $LOCAL_PREFIX $LOCAL_PREFIX/include/boost/version.hpp

  download_make_install_local https://www.openssl.org/source/openssl-1.0.2n.tar.gz \
      "" "linux-$(uname -m) no-shared no-dso -fPIC" $LOCAL_PREFIX/bin/openssl
  download_make_install_local https://internal-dependencies.mapd.com/thirdparty/curl-$CURL_VERSION.tar.bz2 \
      "" "--disable-ldap --disable-ldaps --with-ssl=$LOCAL_PREFIX --enable-http" \
      $LOCAL_PREFIX/bin/curl

  ;;
Ubuntu*)
  export CC=gcc-5
  export CXX=g++-5
  export CMAKE=cmake
  ;;
*)
esac


install_thrift $LOCAL_PREFIX $LOCAL_PREFIX/include/thrift/Thrift.h
install_folly $LOCAL_PREFIX $LOCAL_PREFIX/include/folly/folly-config.h
install_awscpp $LOCAL_PREFIX $LOCAL_PREFIX/include/aws/core/Aws.h
install_arrow $LOCAL_PREFIX $LOCAL_PREFIX/include/arrow/api.h

#download_make_install_local https://internal-dependencies.mapd.com/thirdparty/expat-$EXPAT_VERSION.tar.bz2 \
#  "" "" $LOCAL_PREFIX/include/TODO

install_kml $LOCAL_PREFIX $LOCAL_PREFIX/include/kml/dom.h
download_make_install_local http://download.osgeo.org/proj/proj-$PROJ_VERSION.tar.gz \
  "" "" $LOCAL_PREFIX/include/proj_api.h
download_make_install_local http://download.osgeo.org/gdal/$GDAL_VERSION/gdal-$GDAL_VERSION.tar.xz \
  "" "--without-curl --without-geos --with-libkml=$LOCAL_PREFIX --with-static-proj4=$LOCAL_PREFIX" \
  $LOCAL_PREFIX/include/gdal.h

#download_make_install_local http://libarchive.org/downloads/libarchive-$LIBARCHIVE_VERSION.tar.gz \
#  "" "--without-openssl --disable-shared" $LOCAL_PREFIX/include/archive.h

download_make_install_local https://internal-dependencies.mapd.com/thirdparty/bisonpp-$BISONPP_VERSION-45.tar.gz \
  bison++-$BISONPP_VERSION "" $LOCAL_PREFIX/bin/bison++

install_llvm $LOCAL_PREFIX $LOCAL_PREFIX/bin/clang

install_mapdcore $LOCAL_PREFIX $PREFIX/SOMETHING
