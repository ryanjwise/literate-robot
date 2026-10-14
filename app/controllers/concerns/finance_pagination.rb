require "base64"
require "json"

# Cursor pagination shared by every list endpoint. Responses are
#   { "data": [...], "next_cursor": "opaque" | null }
# Newest first by default. The cursor is keyset-based on (sort value, id), so it stays
# correct while records change, and it only works with the sort and direction it was issued for.
module FinancePagination
  extend ActiveSupport::Concern

  DEFAULT_LIMIT = 100
  MAX_LIMIT = 500

  class BadParam < StandardError; end

  private

  # `sorts` are non-null columns that are safe to order by (they are interpolated into SQL,
  # so they are checked against this allowlist and never taken from the request).
  def paginate_relation(relation, sorts:, default_sort: "id")
    sort, dir, limit = page_params(sorts, default_sort)
    table = relation.klass.table_name
    relation = relation.reorder(Arel.sql("#{table}.#{sort} #{dir}, #{table}.id #{dir}"))
    if (cursor = decode_cursor(sort, dir))
      op = dir == "asc" ? ">" : "<"
      relation = relation.where("(#{table}.#{sort}, #{table}.id) #{op} (?, ?)", cursor[:v], cursor[:i])
    end
    rows = relation.limit(limit + 1).to_a
    page = rows.first(limit)
    { data: page, next_cursor: (encode_cursor(sort, dir, page.last, relation.klass) if rows.size > limit) }
  end

  # For lists computed in Ruby (transfers). `items` are hashes; `tie` is the unique key used as tie-breaker.
  def paginate_array(items, sorts:, default_sort:, tie:)
    sort, dir, limit = page_params(sorts, default_sort)
    key = ->(item) { [sortable(item[sort.to_sym]), item[tie].to_s] }
    ordered = items.sort_by(&key)
    ordered.reverse! if dir == "desc"
    if (cursor = decode_cursor(sort, dir))
      after = [cursor[:v], cursor[:i].to_s]
      ordered = ordered.drop_while { |item| dir == "asc" ? (key.(item) <=> after) <= 0 : (key.(item) <=> after) >= 0 }
    end
    page = ordered.first(limit)
    last = page.last
    { data: page, next_cursor: (ordered.size > limit ? build_cursor(sort, dir, sortable(last[sort.to_sym]), last[tie]) : nil) }
  end

  def page_params(sorts, default_sort)
    sort = params[:sort].presence || default_sort
    raise BadParam, "sort must be one of: #{sorts.join(', ')}" unless sorts.include?(sort)
    dir = params[:dir].presence || "desc"
    raise BadParam, "dir must be asc or desc" unless %w[asc desc].include?(dir)
    limit = params[:limit].present? ? Integer(params[:limit], exception: false) : DEFAULT_LIMIT
    raise BadParam, "limit must be a positive integer" unless limit&.positive?
    [sort, dir, [limit, MAX_LIMIT].min]
  end

  def int_param(name)
    Integer(params[name], exception: false) or raise BadParam, "#{name} must be an integer"
  end

  def sortable(value) = value.respond_to?(:iso8601) ? value.iso8601 : value

  def encode_cursor(sort, dir, record, klass)
    # The stored representation is compared in SQL, so use exactly what the database holds.
    build_cursor(sort, dir, record.read_attribute_before_type_cast(sort), record.id)
  end

  def build_cursor(sort, dir, value, id)
    Base64.urlsafe_encode64({ s: sort, d: dir, v: value, i: id }.to_json, padding: false)
  end

  def decode_cursor(sort, dir)
    return unless params[:cursor].present?
    data = JSON.parse(Base64.urlsafe_decode64(params[:cursor]), symbolize_names: true)
    raise BadParam, "cursor was issued for a different sort or direction" unless data[:s] == sort && data[:d] == dir
    data
  rescue ArgumentError, JSON::ParserError, TypeError
    raise BadParam, "invalid cursor"
  end
end
