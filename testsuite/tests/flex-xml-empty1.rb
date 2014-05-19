# encoding: utf-8

# testedfiles: helper.rb

module Yast

  class TestClient < Client

    def main

      def setup1()
        setup_system("empty")
      end

      def setup2()
        ProductFeatures.SetBooleanFeature("partitioning", "use_flexible_partitioning", true)
        ProductFeatures.SetFeature("partitioning", "flexible_partitioning", {
          "partitions" => [
            { "mount" => "/", "size" => "8GB" },
            { "mount" => "swap", "size" => "1GB" },
            { "mount" => "/data", "sizepct" => "100" }
          ]
        })
      end

      def setup3()
      end

      Yast.include self, "helper.rb"

    end

  end

end

Yast::TestClient.new.main
