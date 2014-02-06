# encoding: utf-8

# Copyright (c) 2012 Novell, Inc.
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.

# Module:		inst_prepdisk.ycp
#
# Authors:		Mathias Kettner (kettner@suse.de) (initial)
#			Stefan Schubert (schubi@suse.de)
#			Klaus Kaempf (kkaempf@suse.de)
#
# Purpose:
# Displays a progress bar showing progress of disk preparation.
# The user has the opportunity to cancel the installation. The
# disks are partitioned. Swap is created and used. File systems
# are created for the new partitions. Mount points are created
# and mounted for the targets / and /boot.
#
#
# possible return values: `back, `abort `next
module Yast
  class InstPrepdiskClient < Client
    def main
      textdomain "storage"

      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "Storage"
      Yast.import "String"
      Yast.import "SlideShow"
      Yast.import "StorageClients"
      Yast.import "FileUtils"

      return :auto if Mode.update

      SCR.Write(
        path(".target.ycp"),
        Storage.SaveDumpPath("targetMap_ps"),
        Storage.GetTargetMap
      )

      Builtins.y2milestone("BEGINNING of inst_prepdisk")

      if Mode.normal
        # we need to open dialog and set up slideshow
        SlideShow.Setup(
          [
            {
              "name"        => "disk",
              "description" => _("Preparing disks..."),
              "value"       => Mode.update ? 0 : 120, # FIXME: 2 minutes
              "units"       => :sec
            }
          ]
        )

        SlideShow.OpenDialog
      end

      # They are usually more than twice the reported value
      # create, format, mount ...
      StorageClients.total_actions = Convert.convert(
        Ops.multiply(
          Convert.convert(
            Builtins.size(Storage.GetCommitInfos),
            :from => "integer",
            :to   => "float"
          ),
          2.5
        ),
        :from => "float",
        :to   => "integer"
      )
      Builtins.y2milestone(
        "StorageClients::total_actions: %1",
        StorageClients.total_actions
      )

      SlideShow.MoveToStage("disk")

      Builtins.y2milestone("installation=%1", Stage.initial)
      @ret_val = :next

      @ret = Storage.CommitChanges
      Builtins.y2milestone("CommitChanges ret:%1", @ret)
      @ret_val = :abort if @ret != 0

      if Stage.initial

        # If a kernel without initrd is booted, then there is a small window
        # between mounting the root filesystem until /etc/init.d/boot
        # mounts /dev as tmpfs mount. A few device nodes have to be on-disk,
        # like /dev/console, /dev/null etc.
        # During install time, provide the same set of device nodes to the chroot
        # They are needed at the end for the bootloader installation.
        @cmd = Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(
                  Ops.add(
                    Ops.add(
                      Ops.add(
                        "mkdir -vp '",
                        String.Quote(Storage.PathToDestdir("/dev"))
                      ),
                      "'; "
                    ),
                    "cp --preserve=all --recursive --remove-destination /lib/udev/devices/* '"
                  ),
                  String.Quote(Storage.PathToDestdir("/dev"))
                ),
                "'; "
              ),
              "mount -v --bind /dev '"
            ),
            String.Quote(Storage.PathToDestdir("/dev"))
          ),
          "'"
        )
        Builtins.y2milestone("cmd %1", @cmd)
        @m = Convert.to_map(SCR.Execute(path(".target.bash_output"), @cmd))
        Builtins.y2milestone("ret %1", @m)

        MountTarget("/proc", "proc", "-t proc")
        MountTarget("/sys", "sysfs", "-t sysfs")

        # mounting /run for udev (bnc#717321)
        @cmd = Ops.add(
          Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(
                  "mkdir -vp '",
                  String.Quote(Storage.PathToDestdir("/run"))
                ),
                "'; "
              ),
              "mount -v --bind /run '"
            ),
            String.Quote(Storage.PathToDestdir("/run"))
          ),
          "'"
        )
        Builtins.y2milestone("cmd %1", @cmd)
        @m = Convert.to_map(SCR.Execute(path(".target.bash_output"), @cmd))
        Builtins.y2milestone("ret %1", @m)
      else
        Storage.FinishInstall
      end

      # close progress on running system
      SlideShow.CloseDialog if Mode.normal

      Builtins.y2debug("writing target-map %1", Storage.GetTargetMap)

      SCR.Write(
        path(".target.ycp"),
        Storage.SaveDumpPath("targetMap_pe"),
        Storage.GetTargetMap
      )

      Builtins.y2milestone("END of inst_prepdisk.ycp")

      @ret_val
    end

    def MountTarget(dir, device, options)
      dest = Storage.PathToDestdir(dir)

      SCR.Execute(path(".target.mkdir"), dest) if !FileUtils.Exists(dest)

      SCR.Execute(path(".target.mount"), [device, dest], options)

      nil
    end
  end
end

Yast::InstPrepdiskClient.new.main
