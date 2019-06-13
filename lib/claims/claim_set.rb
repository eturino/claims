# frozen_string_literal: true

module Claims
  class ClaimSet
    include Enumerable

    def self.for(string_list, strict: true)
      string_list = string_list
      claims = Array(string_list).map do |string|
        begin
          Claim.for string
        rescue InvalidClaimError => e
          raise e if strict

          nil
        end
      end

      new claims: SortedSet.new(claims.compact)
    end

    def self.for_claims(claims)
      unless claims.respond_to?(:all?) && claims.all? { |c| c.is_a? Claims::Claim }
        raise ArgumentError, "needs a list of Claim objects, given #{claims.inspect}"
      end

      new claims: SortedSet.new(claims.to_a)
    end

    private_class_method :new

    attr_reader :claims

    def initialize(claims:)
      @claims = claims
    end

    delegate :each, to: :claims

    def select(*args, &block)
      list = claims.send(:select, *args, &block)
      ClaimSet.for_claims list
    end

    def reject(*args, &block)
      list = claims.send(:reject, *args, &block)
      ClaimSet.for_claims list
    end

    def add(claim)
      raise ArgumentError, "invalid claim, expected Claim object, given #{claim.inspect}" unless claim.is_a? Claims::Claim

      claims << claim
      self
    end

    def inspect
      cs = claims.map { |c| "      - #{c.clean_string}" }.join("\n")

      "#<#{self.class}: [\n#{cs}\n    ]>"
    end

    def as_json(*opts)
      map { |c| c.as_json(*opts) }.tap do |array|
        array.freeze if frozen?
      end
    end

    def query?(query_hash)
      claims.any? { |c| c.query?(query_hash) }
    end

    def query_claim?(claim)
      claims.any? { |c| c.query_claim?(claim) }
    end

    def exact?(query_hash)
      claims.any? { |c| c.exact? query_hash }
    end

    def direct_children(query_hash)
      SortedSet.new(claims.map { |c| c.direct_child query_hash }.compact)
    end

    def direct_descendants(query_hash)
      SortedSet.new(claims.map { |c| c.direct_descendant query_hash }.compact)
    end

    # EQUALITY AND COMPARISON

    def hash
      claims.map(&:hash).hash
    end

    def <=>(other)
      claims.map(&:clean_string) <=> other.claims.map(&:clean_string)
    end

    def ===(other)
      claims.map(&:clean_string) === other.claims.map(&:clean_string) # rubocop:disable Style/CaseEquality
    end

    def ==(other)
      claims.map(&:clean_string) == other.claims.map(&:clean_string)
    end

    def eql?(other)
      other.is_a?(ClaimSet) && claims.to_a == other.claims.to_a
    end
  end
end
