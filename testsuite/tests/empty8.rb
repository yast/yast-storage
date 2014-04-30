# encoding: utf-8

# testedfiles: helper.rb

module Yast

  class TestClient < Client

    def main

      Yast.include self, "setup-system.rb"

      setup_system("empty")

      def setup2()
        ProductFeatures.SetBooleanFeature("partitioning", "try_separate_home", true)
        ProductFeatures.SetBooleanFeature("partitioning", "proposal_lvm", false)
        ProductFeatures.SetBooleanFeature("partitioning", "proposal_snapshots", true)
        ProductFeatures.SetStringFeature("partitioning", "vm_desired_size", "30 GB")
        ProductFeatures.SetStringFeature("partitioning", "root_base_size", "3 GB")
        ProductFeatures.SetStringFeature("partitioning", "root_max_size", "10 GB")
        ProductFeatures.SetIntegerFeature("partitioning", "btrfs_increase_percentage", 300)
      end

      def setup3()
      end

      Yast.include self, "helper.rb"

    end

  end

end

Yast::TestClient.new.main
