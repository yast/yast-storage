# encoding: utf-8

require 'rexml/document'

module Yast
  module HelperInclude

    def initialize_helper(include_target)

      def setup_system(name)
        SCR.Execute(path(".target.bash"), "mkdir -p tmp")
        SCR.Execute(path(".target.bash"), "rm -rf tmp/*")
        SCR.Execute(path(".target.bash"), "cp data/#{name}/*.info tmp/")
      end

      @part_info_size = 0
      @part_info_string = nil

      def setup_part_info(content)
        @part_info_size = content.size()
        @part_info_string = content
      end

      setup1()

      Yast.import "Testsuite"

      @READ = {
        "probe"     => {
          "architecture" => "i386",
          "bios"         => [ { "lba_support" => true } ],
          "cdrom"        => [],
          "system"       => [ { "system" => "" } ]
        },
        "proc"      => {
          "swaps"   => [],
          "meminfo" => { "memtotal" => 256 * 1024 }
        },
        "sysconfig" => {
          "storage"    => { "DEFAULT_FS" => "btrfs" },
          "bootloader" => { "LOADER_TYPE" => "grub" },
          "language"   => { "RC_LANG" => "en_US.UTF-8", "RC_LC_MESSAGES" => "" }
        },
        "target"    => {
          "size"        => @part_info_size,
          "string"      => @part_info_string,
          "bash_output" => {},
          "yast2"       => {},
          "dir"         => []
        }
      }

      begin
        file = File.new("tmp/arch.info")
        doc = REXML::Document.new(file)
        arch = doc.elements["arch"].elements["arch"].text
        system = ""
        if arch == "s390x"
          arch = "s390_64"
        end
        if arch == "ppc64le"
          arch = "ppc64"
          system = "CHRP"
        end
        @READ["probe"]["architecture"] = arch
        @READ["probe"]["system"][0]["system"] = system
      rescue Errno::ENOENT
      end

      Testsuite.Init([@READ, {}, @READ], nil)

      Yast.import "Stage"
      Yast.import "Storage"
      Yast.import "StorageProposal"

      Stage.Set("initial")

      setup2()

      Storage.InitLibstorage(false)

      StorageProposal.GetControlCfg()

      target_map = Storage.GetTargetMap()

      setup3()

      prop = StorageProposal.get_inst_prop(target_map)

      if prop.fetch("ok", false)
        Storage.SetTargetMap(prop.fetch("target", {}))

        infos = Storage.GetCommitInfos

        Testsuite.Dump("Proposal:")
        infos.each do |info|
          text = info.fetch(:text, "")
          if info.fetch(:destructive, false)
            text += " [destructive]"
          end
          Testsuite.Dump(text)
        end

        Testsuite.Dump("")

        Testsuite.Dump("Target Map Excerpt:")
        prop["target"].each do |device, container|

          if Storage.IsDiskType(container.fetch("type", :CT_UNKNOWN))

            line = "device:#{container["device"]}"

            if container.fetch("label", "") != ""
              line << " label:#{container["label"]}"
            end

            Testsuite.Dump(line)

          end

          container["partitions"].each do |volume|

            line = "device:#{volume["device"]}"

            if volume.fetch("fsid", 0) != 0
              line << " fsid:0x#{volume["fsid"].to_s(16)}"
            end

            if !volume.fetch("userdata", {}).empty?
              line << " userdata:#{volume["userdata"]}"
            end

            Testsuite.Dump(line)

          end

        end

        Testsuite.Dump("")

        Testsuite.Dump("Proposal Feedback:")
        if StorageProposal.CouldNotDoSnapshots(prop["target"])
          Testsuite.Dump("Cound not do snapshots.")
        end

        if StorageProposal.CouldNotDoSeparateHome(prop["target"])
          Testsuite.Dump("Cound not do separate home.")
        end

      else
        Testsuite.Dump("No proposal.")
      end

      Storage.FinishLibstorage

    end

  end
end
