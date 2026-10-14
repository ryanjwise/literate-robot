require "openapi_first"

# Every response produced by a request spec under /finance is checked against
# openapi/finance.yaml, so the spec cannot drift from the API: a new field, a changed
# status, or an undocumented response fails the test that triggered it.
module OpenapiContract
  DEFINITION = OpenapiFirst.load(Rails.root.join("openapi/finance.yaml").to_s)

  # "METHOD /spec/path -> status" for every response validated, to report coverage.
  SEEN = Set.new

  def process(method, path, **kwargs)
    status = super
    return status unless path.to_s.start_with?("/finance")

    # Most specs send form-encoded params; the API documents JSON bodies. Only the response is
    # validated here, so present the request as JSON for routing.
    env = request.env.dup
    env["CONTENT_TYPE"] = "application/json" if env["CONTENT_TYPE"].present?
    rack_request = Rack::Request.new(env)
    rack_response = Rack::Response.new(response.body, response.status, response.headers)
    validated = DEFINITION.validate_response(rack_request, rack_response)
    raise "#{method.to_s.upcase} #{path} is not described in openapi/finance.yaml" if validated.nil?

    if validated.invalid?
      raise "#{method.to_s.upcase} #{path} -> #{response.status} does not match openapi/finance.yaml: " \
            "#{validated.error&.message}\nbody: #{response.body.to_s[0, 300]}"
    end
    OpenapiContract::SEEN << [method.to_s.upcase, path.to_s.sub(%r{\?.*}, "")]
    status
  end
end

ActionDispatch::Integration::Session.prepend(OpenapiContract)

# Print which documented operations no spec exercised (their part of the spec is unchecked):
#   OPENAPI_COVERAGE=1 bundle exec rspec
RSpec.configure do |config|
  config.after(:suite) do
    next unless ENV["OPENAPI_COVERAGE"]

    spec_paths = YAML.load_file(Rails.root.join("openapi/finance.yaml"))["paths"]
    # Most specific template first, so /transactions/confirm_auto wins over /transactions/{id}.
    matchers = spec_paths.keys.sort_by { |t| t.count("{") }.map do |template|
      [template, Regexp.new("\\A#{Regexp.escape(template).gsub(/\\\{\w+\\\}/, '[^/]+')}\\z")]
    end
    covered = OpenapiContract::SEEN.filter_map do |verb, path|
      template = matchers.find { |_, re| re.match?(path) }&.first
      [verb, template] if template
    end.to_set
    verbs = %w[get post put patch delete]
    missing = spec_paths.flat_map { |path, ops| ops.keys.select { verbs.include?(_1) }.map { [_1.upcase, path] } }
                        .reject { covered.include?(_1) }
    puts "\nOpenAPI operations no spec exercised: #{missing.size}"
    missing.each { |verb, path| puts "  #{verb} #{path}" }
  end
end
