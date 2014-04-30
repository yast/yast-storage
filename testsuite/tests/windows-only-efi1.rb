# encoding: utf-8

# testedfiles: helper.rb

module Yast

  class TestClient < Client

    def main

      Yast.include self, "setup-system.rb"

      setup_system("windows-only-efi")

      def setup2()
        ProductFeatures.SetBooleanFeature("partitioning", "try_separate_home", true)
        ProductFeatures.SetBooleanFeature("partitioning", "proposal_lvm", false)
        ProductFeatures.SetStringFeature("partitioning", "root_max_size", "20 GB")
        ProductFeatures.SetStringFeature("partitioning", "root_base_size", "15 GB")
        ProductFeatures.SetBooleanFeature("partitioning", "proposal_snapshots", false)
      end

      def setup3()
      end

      Yast.include self, "helper.rb"

    end

  end

end

Yast::TestClient.new.main
