# encoding: utf-8

# testedfiles: helper.rb

module Yast

  class TestClient < Client

    def main

      def setup1()
        setup_system("empty")

        setup_part_info(<<-EOT)
PARTITION  mount=/boot  size=512MB
PARTITION  mount=/      size=8GB
PARTITION  mount=swap   size=1GB
PARTITION  mount=/data  sizepct=100
EOT
      end

      def setup2()
      end

      def setup3()
      end

      Yast.include self, "helper.rb"

    end

  end

end

Yast::TestClient.new.main
