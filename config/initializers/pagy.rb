# frozen_string_literal: true

# Pagy configuration
# See https://ddnexus.github.io/pagy/docs/api/pagy

# Instance variables
Pagy::DEFAULT[:limit] = 20      # items per page
Pagy::DEFAULT[:size] = 5        # nav bar links

# Extras
require "pagy/extras/overflow"
Pagy::DEFAULT[:overflow] = :last_page  # :empty_page, :last_page, :exception

require "pagy/extras/metadata"
