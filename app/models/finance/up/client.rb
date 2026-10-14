require "net/http"
require "json"

module Finance
  module Up
    class Error < StandardError
      attr_reader :status

      def initialize(message, status: nil)
        super(message)
        @status = status
      end
    end

    # Minimal read-only client for the UP Bank API. The token lives only in this
    # object for the duration of one request; it is never stored or logged, and
    # is only ever sent to the configured UP host.
    class Client
      BASE_URL = ENV.fetch("UP_API_URL", "https://api.up.com.au/api/v1")
      MAX_PAGES = 100

      def initialize(token, base_url: BASE_URL)
        @token = token
        @base = URI.parse(base_url)
      end

      # All records of a list endpoint, following `links.next` until it is null.
      def paginate(path, params = {})
        url = "#{@base}#{path}?#{URI.encode_www_form(params)}"
        records = []
        MAX_PAGES.times do
          body = get_url(url)
          records.concat(body.fetch("data", []))
          url = body.dig("links", "next")
          return records unless url
        end
        raise Error, "UP returned more than #{MAX_PAGES} pages; narrow the date range"
      end

      def get_url(url)
        uri = URI.parse(url)
        raise Error, "refusing to follow a link to another host" unless same_origin?(uri)

        response = request(uri)
        case response.code.to_i
        when 200 then JSON.parse(response.body)
        when 401 then raise Error.new("UP rejected the token", status: 401)
        when 429 then raise Error.new("UP rate limit reached; try again shortly", status: 429)
        else raise Error.new("UP returned HTTP #{response.code}", status: response.code.to_i)
        end
      rescue JSON::ParserError, Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError
        raise Error, "could not reach UP"
      end

      private

      def request(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 10
        http.read_timeout = 20
        req = Net::HTTP::Get.new(uri)
        req["Authorization"] = "Bearer #{@token}"
        req["Accept"] = "application/json"
        http.request(req)
      end

      def same_origin?(uri)
        [uri.scheme, uri.host, uri.port] == [@base.scheme, @base.host, @base.port]
      end
    end
  end
end
