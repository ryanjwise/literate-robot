module Dev
  # Serves lib/dev/console.html, injecting FINANCE_API_KEY from the environment.
  # Unauthenticated by design, so it is refused outside development/test.
  class ConsoleController < ApplicationController
    def show
      return head :not_found if Rails.env.production?

      key = ENV["FINANCE_API_KEY"].to_s
      html = Rails.root.join("lib/dev/console.html").read
                  .sub("__INJECTED_KEY__", ERB::Util.json_escape(key.to_json))
      render body: html, content_type: "text/html"
    end
  end
end
