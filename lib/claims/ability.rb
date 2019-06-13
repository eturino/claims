# frozen_string_literal: true

module Claims
  class Ability
    def self.for(permitted_claim_strings:, prohibited_claim_strings:)
      permitted = ClaimSet.for permitted_claim_strings
      prohibited = ClaimSet.for prohibited_claim_strings

      new permitted: permitted, prohibited: prohibited
    end

    def self.for_claims(permitted_claims:, prohibited_claims:)
      permitted = ClaimSet.for_claims permitted_claims
      prohibited = ClaimSet.for_claims prohibited_claims

      new permitted: permitted, prohibited: prohibited
    end

    private_class_method :new

    attr_reader :permitted, :prohibited

    # @param permitted [Claims::ClaimSet]
    # @param prohibited [Claims::ClaimSet]
    def initialize(permitted:, prohibited:)
      @permitted = permitted.reject { |claim| prohibited.query_claim? claim }
      @prohibited = prohibited
    end

    # @param query_hash [Hash<Symbol,String>] single argument to be used in the form `can?(read: 'some.stuff')`
    def can?(query_hash)
      permitted.query?(query_hash) && !prohibited.query?(query_hash)
    rescue ArgumentError => _e
      raise InvalidClaimError, "#{query_hash.inspect} is not a valid claim"
    end

    # @param query_hash [Hash<Symbol,String>] single argument to be used in the form `cannot?(read: 'some.stuff')`
    def cannot?(query_hash)
      !can? query_hash
    end

    # @param query_hash [Hash<Symbol,String>] single argument to be used in the form `cannot?(read: 'some.stuff')`
    def explicitly_prohibited?(query_hash)
      prohibited.query?(query_hash)
    rescue ArgumentError => _e
      raise InvalidClaimError, "#{query_hash.inspect} is not a valid claim"
    end

    def clone
      Ability.for_claims permitted_claims: permitted.claims, prohibited_claims: prohibited.claims
    end

    def freeze
      permitted.freeze
      prohibited.freeze
      super
    end

    # EQUALITY AND COMPARISON

    def hash
      [permitted.hash, prohibited.hash].hash
    end

    def <=>(another_ability)
      [permitted, prohibited] <=> [another_ability.permitted, another_ability.prohibited]
    end

    def ===(another_ability)
      eql? another_ability
    end

    def ==(another_ability)
      eql? another_ability
    end

    def eql?(another_ability)
      another_ability.is_a?(Ability) && another_ability.permitted == permitted && another_ability.prohibited == prohibited
    end

    # returns the KeySet that represents the resources that we have access to,
    # similar to querying with a wildcard and an optional suffix check:
    # e.g
    #   ability.access_to_resources(read: "clients")
    # would be the same as to check for `read:clients.*`, giving the KeySet that has
    # @return [KeySet]
    def access_to_resources(query_hash)
      allowed_key_set = if permitted.query?(query_hash)
                          KeySet.all
                        else
                          KeySet.some(permitted.direct_descendants(query_hash))
                        end

      forbidden_key_set = if prohibited.query?(query_hash)
                            KeySet.all
                          else
                            KeySet.some(prohibited.direct_children(query_hash))
                          end

      allowed_key_set.remove(forbidden_key_set)
    end

    # @return [KeySet]
    def access_to_client_keys
      access_to_resources read: 'clients'
    end

    # @return [KeySet]
    def access_to_business_group_keys
      access_to_resources read: 'business-groups'
    end

    # @return [KeySet]
    def access_to_programme_keys(client_key)
      access_to_resources read: "clients.#{client_key}.programmes.programme"
    end

    # @return [KeySet]
    def access_to_project_keys(client_key)
      access_to_resources read: "clients.#{client_key}.projects.project"
    end

    # @return [KeySet]
    def access_to_team_keys(client_key)
      access_to_resources read: "clients.#{client_key}.teams.team"
    end

    # @return [KeySet]
    def access_to_people_ids(client_key)
      access_to_resources read: "clients.#{client_key}.people.person"
    end
  end
end
