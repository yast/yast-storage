# encoding: utf-8

# testedfiles: helper.rb

module Yast

  class TestClient < Client

    def main

      Yast.include self, "setup-system.rb"

      setup_system("empty-small")

      def setup2()
        ProductFeatures.SetBooleanFeature("partitioning", "try_separate_home", true)
        ProductFeatures.SetBooleanFeature("partitioning", "proposal_lvm", false)
        ProductFeatures.SetBooleanFeature("partitioning", "proposal_snapshots", true)
        ProductFeatures.SetStringFeature("partitioning", "root_base_size", "10 GB")
      end

      def setup3()
      end

      Yast.include self, "helper.rb"

    end

  end

end

Yast::TestClient.new.main
