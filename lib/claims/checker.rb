# frozen_string_literal: true

module Claims
  module Checker
    ALL = Claims::ALL
    EMPTY = Claims::EMPTY
    DOT = Claims::DOT
    COLON = Claims::COLON
    SEPARATOR_REGEX = /[.:]/.freeze
    SEPARATOR_CAPTURE_REGEX = /([.:])/.freeze

    DOT_COLON = [DOT, COLON].freeze

    class << self
      def query_claims(query:, claims:)
        query_parts = query.split SEPARATOR_REGEX

        claims.any? do |claim_string|
          rule_parts = claim_string.split SEPARATOR_REGEX
          parts = rule_parts.zip(query_parts)
                    .map { |pair| { rule: pair.first, query: pair.last } }

          return true if parts.all? { |h| h[:rule] == h[:query] }

          non_matching = parts.reverse.take_while { |h| h[:rule] != h[:query] }
          return false if non_matching.empty?
          return true if non_matching.last[:rule] == ALL

          false
        end
      end

      def sub_claims(query:, claims:)
        return [:all] if exact_or_ancestor?(query: query, claims: claims)

        prefix_dot = "#{query}#{DOT}"
        prefix_colon = "#{query}#{COLON}"
        claims.select { |claim| claim.start_with?(prefix_dot) || claim.start_with?(prefix_colon) }
      end

      def sub_claims_direct_children(query:, claims:, only_direct: false)
        subs = sub_claims(query: query, claims: claims)
        return subs if subs.blank? || subs.include?(:all)

        length_to_remove = query.size + 1 # for the : or the .

        clean = subs.map { |s| s[length_to_remove..-1] }

        parted = clean.map { |s| s.split(SEPARATOR_REGEX) }

        if only_direct
          parted = parted.select do |parts|
            parts.size == 1 || (parts.size == 2 && parts.last == ALL)
          end
        end

        direct = parted.map(&:first)
        direct.uniq.sort
      end

      def exact_or_ancestor?(query:, claims:)
        parts_and_separators = query.split SEPARATOR_CAPTURE_REGEX
        found_ancestor = catch(:found_ancestor) do
          parts_and_separators.each_with_index do |part, index|
            next if DOT_COLON.include?(part)

            ancestor = parts_and_separators[0..index].join
            throw :found_ancestor, ancestor if exact?(query: ancestor, claims: claims)
          end

          nil # nothing was found
        end

        found_ancestor.present?
      end

      private

      def exact?(query:, claims:)
        claims.include?(query) || claims.include?("#{query}#{COLON}#{ALL}") || claims.include?("#{query}#{DOT}#{ALL}")
      end
    end
  end
end