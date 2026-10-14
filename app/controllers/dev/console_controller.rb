module Dev
  # Serves lib/dev/console.html, injecting FINANCE_API_KEY and UP_API_TOKEN from the environment.
  # Unauthenticated by design, so it is refused outside development/test.
  class ConsoleController < ApplicationController
    def show
      return head :not_found if Rails.env.production?

      html = Rails.root.join("lib/dev/console.html").read
                  .sub("__INJECTED_KEY__", ERB::Util.json_escape(ENV["FINANCE_API_KEY"].to_s.to_json))
                  .sub("__INJECTED_UP_TOKEN__", ERB::Util.json_escape(ENV["UP_API_TOKEN"].to_s.to_json))
      render body: html, content_type: "text/html"
    end
  end
end
