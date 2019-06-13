# frozen_string_literal: true

require 'active_support/all'
require 'key_set'

module Claims
  ALL = '*'
  READ = 'read'
  ADMIN = 'admin'
  COLON = ':'
  DOT = '.'
  EMPTY = ''
end

require 'claims/version'

require 'claims/invalid_claim_error'

require 'claims/claim'
require 'claims/claim_set'
require 'claims/checker'
require 'claims/ability'
