#!/bin/bash
#
#  Author(Origin): Rick Boykin
#  Modifier : Doohoon Kim(Gabriel Kim, invi.dh.kim@gmail.com)
#
#  Installs a gcc cross compiler for compiling code for raspberry pi on OSX.
#  This script is based on several scripts and forum posts I've found around
#  the web, the most significant being: 
#
#  http://okertanov.github.com/2012/12/24/osx-crosstool-ng/
#  http://crosstool-ng.org/hg/crosstool-ng/file/715b711da3ab/docs/MacOS-X.txt
#  http://gnuarmeclipse.livius.net/wiki/Toolchain_installation_on_OS_X
#  http://elinux.org/RPi_Kernel_Compilation
#
#
#  And serveral articles that mostly dealt with the MentorGraphics tool, which I
#  I abandoned in favor of crosstool-ng
#
#  The process:
#      Install HomeBrew and packages: gnu-sed binutils gawk automake libtool bash and grep
#      Homebrew is installed in $GrewHome so as not to interfere with macports or fink
#
#      Create case sensitive volume using hdiutil and mount it to /Volumes/$ImageName
#
#      Download, patch and build crosstool-ng
#
#      Configure and build the toolchain.
#
#  License:
#      Permission is hereby granted, free of charge, to any person obtaining a copy of
#      this software and associated documentation files (the "Software"), to deal in
#      the Software without restriction, including without limitation the rights to use,
#      copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
#      and to permit persons to whom the Software is furnished to do so,
#      subject to the following conditions:
#
#      The above copyright notice and this permission notice shall be included in all copies or
#      substantial portions of the Software.
#
#      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
#      INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR
#      A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
#      BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
#      TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
#      OR OTHER DEALINGS IN THE SOFTWARE.
#
set -e -u

#
# Config. Update here to suite your specific needs. I've
#

#
# Config of CrossToolNG Basement for installations.
# It will modifying by user.
#

InstallCrossToolNGRoot=/Users/invi/System_Development/SDKs
Version=1.19.0

#
# Can't modifying this section by user!!!!!!
# It can only for CrossToolNG installations.
#

# Install Base
InstallBase=`pwd`

# Config for Local Directory Name
SystemUsrDir=/usr
UsrLocalDir=$SystemUsrDir/local
UsrLocalBinDir=$UsrLocalDir/bin

# Config of brew base directory
BrewHome=$UsrLocalBinDir
# for find of brew install dir
BrewHomeOthers=$SystemUsrDir

# List of installation Tools by brew
BrewTools="gnu-sed binutils gawk automake libtool bash"
# URL of Brew Extratools
BrewToolsExtra="https://raw.github.com/Homebrew/homebrew-dupes/master/grep.rb"

# CrossToolNG Image name.
ImageName=CrossTool2NG
ImageNameExt=${ImageName}.sparseimage

# CrossToolNG Version.
CrossToolName=crosstool-ng
CrossToolVersion=${CrossToolName}-${Version}

# CrossToolNG Toolchain name
ToolChainName=arm-unknown-linux-gnueabi

#
# If $BrewHome does not alread contain HomeBrew, download and install it. 
# Install the required HomeBrew packages.
#
# Modified by Gabriel.Kim.
# If brew File doesn't exist, then execute of brew installation sequence.
# And update and upgrade.
#
function buildBrewDepends()
{
	if [ ! -f "$BrewHome/brew" ]
    then
      echo "If asked, enter your sudo password to create the $BrewHome folder"
	  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    fi
    echo "Updating HomeBrew tools..."
    brew update
    brew upgrade
    set +e
	brew install $BrewTools && true
	brew install $BrewToolsExtra && true
    set -e
}

# 
# modified by Grabriel.Kim
# I'll not use this function.
#
function createCaseSensitiveVolume()
{
    echo "Creating sparse volume mounted on /Volumes/${ImageName}..."
    ImageNameExt=${ImageName}.sparseimage
    diskutil umount force /Volumes/${ImageName} && true
    rm -f ${ImageNameExt} && true
    hdiutil create ${ImageName} -volname ${ImageName} -type SPARSE -size 8g -fs HFSX
    hdiutil mount ${ImageNameExt}
}

function downloadCrossTool()
{
	cd $InstallCrossToolNGRoot
	mkdir $ImageName 
    cd ./$ImageName
    echo "Downloading crosstool-ng..."
    CrossToolArchive=${CrossToolVersion}.tar.bz2
    CrossToolUrl=http://crosstool-ng.org/download/crosstool-ng/${CrossToolArchive}
    curl -L -o ${CrossToolArchive} $CrossToolUrl
    tar xvf $CrossToolArchive
    #rm -f $CrossToolArchive
}

function patchCrosstool()
{
    cd /$InstallCrossToolNGRoot/$ImageName/$CrossToolVersion
    echo "Patching crosstool-ng..."
    sed -i .bak '6i\
#include <stddef.h>' kconfig/zconf.y
}

function buildCrosstool()
{
    echo "Configuring crosstool-ng..."
    ./configure --enable-local \
	--with-objcopy=$UsrLocalBinDir/gobjcopy        \
	--with-objdump=$UsrLocalBinDir/gobjdump        \
	--with-ranlib=$UsrLocalBinDir/granlib          \
	--with-readelf=$UsrLocalBinDir/greadelf        \
	--with-libtool=$UsrLocalBinDir/glibtool        \
	--with-libtoolize=$UsrLocalBinDir/glibtoolize  \
	--with-sed=$UsrLocalBinDir/gsed                \
	--with-awk=$UsrLocalBinDir/gawk                \
	--with-automake=$UsrLocalBinDir/automake       \
	--with-bash=$UsrLocalBinDir/bash               \
	CFLAGS="-std=c99 -Doffsetof=__builtin_offsetof"
    make
}

function createToolchain()
{
    echo "Creating ARM toolchain $ToolChainName..."
    cd /$InstallCrossToolNGRoot/$ImageName
    mkdir $ToolChainName
    cd $ToolChainName

    # the process seems to opena a lot of files at once. The default is 256. Bump it to 1024.
    ulimit -n 1024

    echo "Selecting arm-unknown-linux-gnueabi toolchain..."
    PATH=$BrewHome:$PATH ../${CrossToolVersion}/ct-ng $ToolChainName

    echo "Cleaning toolchain..."
    PATH=$BrewHome:$PATH ../${CrossToolVersion}/ct-ng clean

    echo "Copying my working toolchain configuration"
    cp $InstallBase/${ToolChainName}.config ./.config

    echo "Manually Configuring toolchain"
    echo "        Select 'Force unwind support'"
    echo "        Unselect 'Link libstdc++ statically onto the gcc binary'"
    echo "        Unselect 'Debugging -> dmalloc or fix its build'"

    # Use 'menuconfig' target for the fine tuning.
    PATH=$BrewHome:$PATH ../${CrossToolVersion}/ct-ng menuconfig
}

function buildToolchain()
{
    cd /$InstallCrossToolNGRoot/$ImageName/$ToolChainName
    echo "Building toolchain..."
    PATH=$BrewHome:$PATH ../${CrossToolVersion}/ct-ng build.4
    echo "And if all went well, you are done! Go forth and compile."
}

buildBrewDepends
#createCaseSensitiveVolume
downloadCrossTool
patchCrosstool
buildCrosstool
createToolchain
buildToolchain
