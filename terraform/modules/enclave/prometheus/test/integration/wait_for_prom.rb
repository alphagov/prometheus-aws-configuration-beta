#!/usr/bin/ruby

module WaitForProm
    MaxAttempts = 14

    def WaitForProm.wait(prometheus_dns)
        uri = URI.parse("http://#{prometheus_dns}:9090/metrics")

        puts "waiting for #{uri} to be ready"

        request = Net::HTTP::Get.new(uri)
        
        attempts = 1
        
        loop do
          response = Net::HTTP.start(uri.hostname, uri.port) do |http|
            http.request(request)
          end
        
          break if response.code == "200" || attempts > MaxAttempts
          sleep(10)
        end
        
        raise "Timeout waiting for prometheus to start" unless attempts <= MaxAttempts
    end
end
