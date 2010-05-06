#!/bin/sh
DIR=`dirname "$0"`/..
ORIGIN=git@gitorious.org:beagleboard-validation
#ORIGIN=git://gitorious.org/beagleboard-validation
OMAPZOOM=git://git.omapzoom.org/repo
DENX=git://git.denx.de
KERNEL=git://git.kernel.org/pub/scm/linux/kernel/git
PSP=git://arago-project.org/git/people

function update {
 git checkout $1
 git pull --ff-only
 git push origin $1
}

#
# x-load
#
echo Updating x-load...
cd $DIR/x-load
update omapzoom/master
update sakoman/master
update psp/master
git checkout master
git pull --ff-only
git show-ref

#
# u-boot
#
echo Updating u-boot...
cd $DIR/u-boot
update upstream/master
update upstream-ti/master
update sakoman/master
update omapzoom/master
update psp/master
git checkout master
git pull --ff-only
git show-ref

#
# Linux
#
echo Updating Linux...
cd $DIR/linux-2.6
update upstream/master
update linux-omap/master
update linux-omap-pm/master
update psp/master
update psp-video/master
update koen/master
update koen/beagleboardXM
git checkout master
git pull --ff-only
git show-ref

