# frozen_string_literal: true

module Claims
  class Claim
    include Comparable

    CLAIM_REGEX = /^([\w_\-]+):([\w_.\-]+\w)(\.\*)?$/.freeze # allows for the optional `.*` at the end, that will be ignored on the Claim creation
    GLOBAL_WILDCARD_CLAIM_REGEX = /^([\w_\-]+):\*$/.freeze # cater for `read:*` global claims
    QUERY_RESOURCE_REGEX = /^([\w_.\-]+\w)(\.\*)?$/.freeze # allows for the optional `.*` at the end, that will be ignored on the Claim creation

    def self.for(string)
      s = string.to_s

      # is this a global wildcard Claim?
      global_match = GLOBAL_WILDCARD_CLAIM_REGEX.match(s)

      if global_match
        return new string: s, verb: global_match[1].to_sym, resource: nil, resource_parts: []
      end

      match = CLAIM_REGEX.match(s)
      if match
        return new string: s,
                   verb: match[1].to_sym,
                   resource: match[2],
                   resource_parts: match[2].to_s.split(Claims::DOT).freeze
      end

      raise InvalidClaimError, "requires a valid claim with a string in the format of `verb:some.resource.identification` or `verb:some.resource.identification.*`, given: #{string.inspect}"
    end

    # @param [Symbol|String] verb
    # @return [Claims::Claim]
    def self.for_global(verb)
      raise ArgumentError, "needs a present verb, given: #{verb.inspect}" if verb.blank?

      new string: "#{verb}:*", verb: verb.to_sym, resource: nil, resource_parts: []
    end

    # @param query_hash [Hash<Symbol,String>] like `x.query? read: 'some.resource'`
    # @return [Claims::Claim]
    def self.for_resource(query_hash)
      parsed = parse_query_hash(query_hash)
      return for_global(parsed[:verb]) if parsed[:resource].blank?

      new string: "#{parsed[:verb]}:#{parsed[:resource]}",
          verb: parsed[:verb],
          resource: parsed[:resource],
          resource_parts: parsed[:resource_parts]
    end

    def self.parse_query_hash(query_hash)
      unless query_hash.is_a?(Hash) && query_hash.keys.size == 1 && query_hash.keys.first.present?
        raise ArgumentError, 'we expect only 1 param, a hash, with a single key being the verb and its value being the resource to check'
      end

      verb = query_hash.keys.first.to_sym
      resource = query_hash.values.first.to_s

      if resource.blank? || resource == Claims::ALL
        return { verb: verb, resource: nil, resource_parts: [].freeze }
      end

      match = QUERY_RESOURCE_REGEX.match(resource)
      unless match
        raise ArgumentError, 'we expect only 1 param, a hash, with a single key being the verb and its value being the resource to check, and it being either blank or a valid resource'
      end

      resource = match[1]
      { verb: verb, resource: resource, resource_parts: resource.to_s.split(Claims::DOT).freeze }
    end

    private_class_method :new

    attr_reader :string, :verb, :resource, :resource_parts

    def initialize(string:, verb:, resource:, resource_parts:)
      @string = string
      @verb = verb
      @resource = resource
      @resource_parts = resource_parts
    end

    def inspect
      "#<#{self.class}: #{clean_string.inspect}>"
    end

    def clean_string
      @clean_string ||= if resource.blank?
                          "#{verb}:*"
                        else
                          "#{verb}:#{resource}"
                        end
    end

    def as_json(*opts)
      clean_string.as_json(*opts)
    end

    ############
    # EQUALITY #
    ############

    def hash
      clean_string.hash
    end

    def <=>(another_claim)
      clean_string.<=>(another_claim.clean_string)
    end

    def eql?(another_claim)
      another_claim.is_a?(Claim) && another_claim.verb == verb && another_claim.resource == resource
    end

    ###########
    # QUERIES #
    ###########

    def same_verb?(verb)
      @verb == verb.to_sym
    end

    def global?
      resource.blank?
    end

    # @param query_hash [Hash<Symbol,String>] like `x.query? read: 'some.resource'`
    # @return [true|false]
    def query?(query_hash)
      check_query Claim.parse_query_hash(query_hash)
    end

    # @param claim [Claims::Claim] like `query?` using the claim verb and the claim resource
    # @return [true|false]
    def query_claim?(claim)
      check_query Claim.parse_query_hash({ claim.verb => claim.resource })
    end

    # @param query_hash [Hash<Symbol,String>] like `x.query? read: 'some.resource'`
    # @return [true|false]
    def exact?(query_hash)
      check_exact Claim.parse_query_hash(query_hash)
    end

    # if the Claim has a resource that is inside of the queried resource (with the same verb),
    # then this returns the next level of the resource, only if the claim is JUST ONE LEVEL INSIDE
    #
    # e.g. claim "read:some.stuff.nested"
    # `claim.direct_child read: 'some.stuff' # => 'nested'`
    # `claim.direct_child read: 'some' # => nil`
    # `claim.direct_child read: 'what' # => nil`
    # `claim.direct_child admin: 'some.stuff' # => nil`
    #
    # @param query_hash [Hash<Symbol,String>] like `x.query? read: 'some.resource'`
    # @return [String|NullClass]
    def direct_child(query_hash)
      lookup_direct_child Claim.parse_query_hash(query_hash)
    end

    # boolean version of `direct_child`
    # @param query_hash [Hash<Symbol,String>] like `x.query? read: 'some.resource'`
    # @return [true|false]
    # @see direct_child
    def direct_child?(query_hash)
      !!direct_child(query_hash)
    end

    # if the Claim has a resource that is inside of the queried resource (with the same verb),
    # then this returns the next level of the resource
    #
    # e.g. claim "read:some.stuff.nested"
    # `claim.query? read: 'some.stuff' # => 'nested'`
    # `claim.query? read: 'some' # => 'stuff'`
    # `claim.query? read: 'what' # => nil`
    # `claim.query? admin: 'some.stuff' # => nil`
    #
    # @param query_hash [Hash<Symbol,String>] like `x.query? read: 'some.resource'`
    # @return [String|NullClass] the single resource level after the query, or nil
    def direct_descendant(query_hash)
      lookup_direct_descendant Claim.parse_query_hash(query_hash)
    end

    # boolean version of `direct_descendant`
    # @param query_hash [Hash<Symbol,String>] like `x.query? read: 'some.resource'`
    # @return [true|false]
    # @see direct_descendant
    def direct_descendant?(query_hash)
      !!direct_descendant(query_hash)
    end

    private
    def check_query(verb:, resource:, resource_parts:)
      return false unless same_verb? verb

      return true if global?

      if global?
        true
      elsif resource.blank?
        false
      else
        self.resource == resource || resource.start_with?("#{self.resource}.")
      end
    end

    def check_exact(verb:, resource:, resource_parts:)
      return false unless same_verb? verb

      if global?
        resource.blank?
      else
        resource.present? && self.resource == resource
      end
    end

    def lookup_direct_child(verb:, resource:, resource_parts:)
      return nil if global?
      return nil unless same_verb? verb
      return nil unless self.resource_parts.size == resource_parts.size + 1

      return self.resource_parts.first if resource.blank?

      prefix = "#{resource}."
      return nil unless self.resource.start_with? prefix

      self.resource_parts.last
    end

    def lookup_direct_descendant(verb:, resource:, resource_parts:)
      return nil if global?
      return nil unless same_verb? verb

      return self.resource_parts.first if resource.blank?
      return nil unless self.resource.start_with? resource

      prefix = "#{resource}."
      return nil unless self.resource.start_with? prefix

      index = resource_parts.size
      self.resource_parts[index]
    end
  end
end