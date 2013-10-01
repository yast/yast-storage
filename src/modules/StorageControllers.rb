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

# Module: 		StorageControllers.ycp
#
# Authors:		Klaus Kaempf <kkaempf@suse.de> (initial)
#
# Purpose:
# This module does all floppy disk related stuff:
# - Detect the floppy devices
#
# SCR: Read(.probe.storage)
#
# $Id$
require "yast"

module Yast
  class StorageControllersClass < Module
    def main

      Yast.import "Arch"
      Yast.import "ModuleLoading"
      Yast.import "HwStatus"
      Yast.import "Storage"
      Yast.import "StorageDevices"
      Yast.import "StorageClients"
      Yast.import "Linuxrc"

      textdomain "storage"

      # list of loaded modules and arguments
      # needed for modules.conf writing
      # must be kept in order (-> no map !)
      # must be searchable (-> separate lists for names and args)

      @moduleNames = []
      @moduleArgs = []

      @ModToInitrdLx = []
      @ModToInitrd = []

      @controllers = [] # set by "Probe"
    end

    # Probe storage controllers
    # probing, loading modules
    #
    # @return [Fixnum]	number of controllers, 0 = none found
    def Probe
      Builtins.y2milestone("StorageControllers::Probe()")

      # probe 'storage' list

      @controllers = Convert.convert(
        SCR.Read(path(".probe.storage")),
        :from => "any",
        :to   => "list <map>"
      )

      if !Arch.s390 && Builtins.size(@controllers) == 0
        Builtins.y2milestone("no controllers")
      end
      Builtins.size(@controllers)
    end


    # start a controller (by loading its module)
    # return true if all necessary modules were actually loaded
    # return false if loading failed or was not necessary at all

    def StartController(controller)
      controller = deep_copy(controller)
      # check module information
      # skip controller if no module info available

      module_drivers = Ops.get_list(controller, "drivers", [])

      return false if Builtins.size(module_drivers) == 0

      # get list of modules from /proc/modules
      SCR.UnmountAgent(path(".proc.modules"))
      loaded_modules = Convert.to_map(SCR.Read(path(".proc.modules")))

      # loop through all drivers checking if one is already active
      # or if one is already listed in /proc/modules

      already_active = false
      Builtins.foreach(module_drivers) do |modulemap|
        if Ops.get_boolean(modulemap, "active", true) ||
            Ops.greater_than(
              Builtins.size(
                Ops.get_map(
                  loaded_modules,
                  Ops.get_string(modulemap, ["modules", 0, 0], ""),
                  {}
                )
              ),
              0
            )
          already_active = true
          if Ops.get_boolean(modulemap, "active", true)
            @ModToInitrdLx = Builtins.add(
              @ModToInitrdLx,
              [
                Ops.get_string(modulemap, ["modules", 0, 0], ""),
                Ops.get_string(modulemap, ["modules", 0, 1], "")
              ]
            )
            Builtins.y2milestone(
              "startController ModToInitrdLx %1",
              @ModToInitrdLx
            )
            Builtins.y2milestone("startController ModToInitrd %1", @ModToInitrd)
          end
        end
      end

      # save unique key for HwStatus::Set()
      unique_key = Ops.get_string(controller, "unique_key", "")

      if already_active
        HwStatus.Set(unique_key, :yes)
        return false
      end

      stop_loading = false
      one_module_failed = false

      # loop through all drivers defined for this controller
      # break after first successful load
      #   no need to check "active", already done before !
      Builtins.foreach(module_drivers) do |modulemap|
        Builtins.y2milestone("startController modulemap: %1", modulemap)
        module_modprobe = Ops.get_boolean(modulemap, "modprobe", false)
        all_modules_loaded = true
        if !stop_loading
          Builtins.foreach(Ops.get_list(modulemap, "modules", [])) do |module_entry|
            module_name = Ops.get_string(module_entry, 0, "")
            module_args = Ops.get_string(module_entry, 1, "")
            # load module if not yet loaded
            if !Builtins.contains(@moduleNames, module_name)
              load_result = :ok
              if Linuxrc.manual
                vendor_device = ModuleLoading.prepareVendorDeviceInfo(
                  controller
                )
                load_result = ModuleLoading.Load(
                  module_name,
                  module_args,
                  Ops.get_string(vendor_device, 0, ""),
                  Ops.get_string(vendor_device, 1, ""),
                  true,
                  module_modprobe
                )
              else
                load_result = ModuleLoading.Load(
                  module_name,
                  module_args,
                  "",
                  "",
                  false,
                  module_modprobe
                )
              end
              Builtins.y2milestone(
                "startController load_result %1",
                load_result
              )

              if load_result == :fail
                all_modules_loaded = false
              elsif load_result == :dont
                all_modules_loaded = true # load ok
              else
                # save data for modules.conf writing
                @moduleNames = Builtins.add(@moduleNames, module_name)
                @moduleArgs = Builtins.add(@moduleArgs, module_args)

                Builtins.y2milestone(
                  "startController moduleNames %1",
                  @moduleNames
                )
                Builtins.y2milestone(
                  "startController moduleArgs %1",
                  @moduleArgs
                )
                @ModToInitrd = Builtins.add(
                  @ModToInitrd,
                  [module_name, module_args]
                )
                Builtins.y2milestone(
                  "startController ModToInitrd %1",
                  @ModToInitrd
                )
                Builtins.y2milestone(
                  "startController ModToInitrdLx %1",
                  @ModToInitrdLx
                )
              end
            end # not yet loaded
            # break out of module load loop if one module failed
            one_module_failed = true if !all_modules_loaded
          end # foreach module of current driver info
        end # stop_loading
        # break out of driver load loop if all modules of
        #   the current driver loaded successfully
        stop_loading = true if all_modules_loaded
      end # foreach driver

      HwStatus.Set(unique_key, one_module_failed ? :no : :yes)

      !one_module_failed
    end


    # local function to go through list of resources (list of maps)
    # checking if '"active":true' is set.

    def AnyActive(resources)
      resources = deep_copy(resources)
      active = Builtins.size(resources) == 0

      Builtins.foreach(resources) do |res|
        active = true if Ops.get_boolean(res, "active", false)
      end

      active
    end

    # Start storage related USB and FireWire stuff
    #
    def StartHotplugStorage
      Yast.import "Hotplug"

      # If USB capable, there might be an usb storage device (i.e. ZIP)
      # activate the module _last_ since it might interfere with other
      # controllers (i.e. having usb-storage first might result in
      # /dev/sda == zip which is bad if the zip drive is removed :-}).

      if Hotplug.haveUSB
        # if loading of usb-storage is successful, re-probe for floppies
        # again since USB ZIP drives are regarded as floppies.

        if ModuleLoading.Load(
            "usb-storage",
            "",
            "",
            "USB Storage",
            Linuxrc.manual,
            true
          ) == :ok
          StorageDevices.FloppyReady
        end
      end

      if Hotplug.haveFireWire
        # load sbp2
        ModuleLoading.Load(
          "sbp2",
          "",
          "",
          "SBP2 Protocol",
          Linuxrc.manual,
          true
        )
      end

      nil
    end

    #  * @param	none
    #  * @returns void
    #  * Init storage controllers (module loading)
    #  * Must have called StorageControllers::probe() before !
    # // O: list of [ loaded modules, module argument ]

    def Initialize
      @moduleNames = []
      @moduleArgs = []
      cindex = 0
      module_loaded = false

      @ModToInitrd = []
      @ModToInitrdLx = []

      Builtins.y2milestone("Initialize controllers: %1", @controllers)

      # loop through all controller descriptions from hwprobe

      # use while(), continue not allowed in foreach()
      while !Arch.s390 && Ops.less_than(cindex, Builtins.size(@controllers))
        controller = Ops.get(@controllers, cindex, {})
        Builtins.y2milestone("Initialize controller %1", controller)

        if !Builtins.isempty(Ops.get_list(controller, "requires", []))
          Storage.AddHwPackages(Ops.get_list(controller, "requires", []))
        end

        cindex = Ops.add(cindex, 1)

        # check BIOS resources on 'wintel' compatible systems
        if Arch.board_wintel
          # for every controller it is checked whether
          # the controller is disabled in BIOS
          # this is done by checking for an active IO or memory resource

          if !(AnyActive(Ops.get_list(controller, ["resource", "io"], [])) ||
              AnyActive(Ops.get_list(controller, ["resource", "mem"], [])))
            Builtins.y2milestone(
              "Initialize controller %1 disabled in BIOS",
              Ops.get_string(controller, "device", "")
            )

            # continue if disabled in BIOS
            next
          end
        end

        module_loaded = StartController(controller) || module_loaded
      end # while (controller)

      Builtins.y2milestone("Initialize module_loaded %1", module_loaded)
      Builtins.y2milestone(
        "Initialize ModToInitrdLx %1 ModToInitrd %2 ",
        @ModToInitrdLx,
        @ModToInitrd
      )
      @ModToInitrd = Convert.convert(
        Builtins.union(@ModToInitrdLx, @ModToInitrd),
        :from => "list",
        :to   => "list <list>"
      )
      Builtins.y2milestone("Initialize ModToInitrd %1", @ModToInitrd)

      if Ops.greater_than(Builtins.size(@ModToInitrd), 1)
        ls = Builtins.filter(
          Builtins.splitstring(
            Convert.to_string(SCR.Read(path(".etc.install_inf.InitrdModules"))),
            " "
          )
        ) { |s| Ops.greater_than(Builtins.size(s), 0) }
        Builtins.y2milestone("Initialize ls=%1", ls)
        i = 0
        lrmods = Builtins.listmap(ls) do |s|
          i = Ops.add(i, 1)
          { s => i }
        end
        Builtins.y2milestone("Initialize lrmods=%1", lrmods)
        i = 0
        while Ops.less_than(i, Builtins.size(@ModToInitrd))
          j = Ops.add(i, 1)
          while Ops.less_than(j, Builtins.size(@ModToInitrd))
            if Builtins.haskey(lrmods, Ops.get_string(@ModToInitrd, [i, 0], "")) &&
                Builtins.haskey(
                  lrmods,
                  Ops.get_string(@ModToInitrd, [j, 0], "")
                ) &&
                Ops.greater_than(
                  Ops.get_integer(
                    lrmods,
                    Ops.get_string(@ModToInitrd, [i, 0], ""),
                    0
                  ),
                  Ops.get_integer(
                    lrmods,
                    Ops.get_string(@ModToInitrd, [j, 0], ""),
                    0
                  )
                )
              tmp = Ops.get(@ModToInitrd, i, [])
              Ops.set(@ModToInitrd, i, Ops.get(@ModToInitrd, j, []))
              Ops.set(@ModToInitrd, j, tmp)
            end
            j = Ops.add(j, 1)
          end
          i = Ops.add(i, 1)
        end
        Builtins.y2milestone("Initialize ModToInitrd %1", @ModToInitrd)
      end
      # Builtins.foreach(@ModToInitrd) do |s|
      #   Initrd.AddModule(Ops.get_string(s, 0, ""), Ops.get_string(s, 1, ""))
      # end

      # load all raid personalities
      SCR.Execute(path(".target.modprobe"), "raid0", "")
      SCR.Execute(path(".target.modprobe"), "raid1", "")
      SCR.Execute(path(".target.modprobe"), "raid5", "")
      SCR.Execute(path(".target.modprobe"), "raid6", "")
      SCR.Execute(path(".target.modprobe"), "raid10", "")
      SCR.Execute(path(".target.modprobe"), "multipath", "")

      StartHotplugStorage()

      Builtins.y2milestone(
        "Initialize all controllers initialized module_loaded:%1",
        module_loaded
      )

      StorageDevices.InitDone
      Storage.ReReadTargetMap if module_loaded
      Builtins.y2milestone("Initialize calling EnablePopup()")
      StorageClients.EnablePopup

      nil
    end

    publish :function => :Probe, :type => "integer ()"
    publish :function => :StartHotplugStorage, :type => "void ()"
    publish :function => :Initialize, :type => "void ()"
  end

  StorageControllers = StorageControllersClass.new
  StorageControllers.main
end
