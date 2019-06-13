# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Claims::Checker, type: :model do
  describe '.query_claims' do
    it 'passes with exact match' do
      query = 'read:clients.artirix'
      claims = ['read:clients.artirix', 'read:clients.acmeinc']
      expect(described_class.query_claims(query: query, claims: claims)).to eq true
    end

    it 'fails with non-match' do
      claims = [
        'read:clients.betacorp',
        'read:clients.betacorp.access',
        'read:clients.acmeinc',
        'read:clients.acmeinc.access',
      ]

      expect(described_class.query_claims(query: 'read:clients.artirix', claims: claims)).to eq false
      expect(described_class.query_claims(query: 'read:clients.artirix.access', claims: claims)).to eq false
    end

    it 'passes with wildcard match' do
      claims = ['read:clients.overview.data.*']

      expect(described_class.query_claims(query: 'read:clients.overview.data', claims: claims)).to eq true
      expect(described_class.query_claims(query: 'read:clients.overview.data.teams', claims: claims)).to eq true

      expect(described_class.query_claims(query: 'read:clients.overview', claims: claims)).to eq false
      expect(described_class.query_claims(query: 'read:clients.overview.teams', claims: claims)).to eq false
    end

    it 'passes with implied wildcard match' do
      claims = ['read:clients.overview.data']

      expect(described_class.query_claims(query: 'read:clients.overview.data', claims: claims)).to eq true
      expect(described_class.query_claims(query: 'read:clients.overview.data.teams', claims: claims)).to eq true

      expect(described_class.query_claims(query: 'read:clients.overview', claims: claims)).to eq false
      expect(described_class.query_claims(query: 'read:clients.overview.teams', claims: claims)).to eq false
    end
  end

  describe '.sub_claims' do
    let(:query) { 'read:clients.this-guy' }
    let(:claims) { [] }
    let(:result) { described_class.sub_claims(query: query, claims: claims) }

    context 'with no claims' do
      it 'returns empty array' do
        expect(result).to eq []
      end
    end

    context 'no claim has query as substring' do
      let(:claims) { ['read:clients.this-guy-but-not-the-same', 'read:clients.another-guy', 'admin:stufff'] }

      it 'returns empty array' do
        expect(result).to eq []
      end
    end

    context 'with the exact match' do
      let(:claims) { ['read:clients.this-guy', 'read:clients.another-guy', 'admin:stufff'] }

      it 'returns an array with :all `[:all]`' do
        expect(result).to eq [:all]
      end
    end

    context 'with `MY_QUERY.*`' do
      let(:claims) do
        ['read:clients.this-guy-but-not-the-same',
         'read:clients.another-guy',
         'read:clients.this-guy.*',
         'read:clients.this-guy.stuff',
         'admin:stufff',
        ]
      end

      it 'returns an array with :all `[:all]`' do
        expect(result).to eq [:all]
      end
    end

    context 'with some claims with the query as the prefix' do
      let(:claims) do
        ['read:clients.this-guy-but-not-the-same',
         'read:clients.another-guy',
         'read:clients.this-guy.stuff',
         'read:clients.this-guy.wooa',
         'read:clients.this-guy.wat.is.this',
         'admin:stufff',
        ]
      end

      let(:expected) do
        [
          'read:clients.this-guy.stuff',
          'read:clients.this-guy.wooa',
          'read:clients.this-guy.wat.is.this',
        ]
      end

      it 'returns the list of subclaims' do
        expect(result).to eq expected
      end
    end
  end

  describe '.exact_or_ancestor?' do
    let(:query) { raise 'define it in each context' }
    let(:claims) { raise 'define it in each context' }

    let(:result) { described_class.exact_or_ancestor?(query: query, claims: claims) }

    context 'with an exact' do
      let(:query) { 'read:clients.this-guy' }
      let(:claims) { ['read:clients.this-guy', 'whatever:stuff'] }

      it 'returns true' do
        expect(result).to be_truthy
      end
    end

    context 'with a parent.*' do
      let(:query) { 'read:clients.this-guy' }
      let(:claims) { ['read:clients.*', 'whatever:stuff'] }

      it 'returns true' do
        expect(result).to be_truthy
      end
    end

    context 'with a parent' do
      let(:query) { 'read:clients.this-guy' }
      let(:claims) { ['read:clients', 'whatever:stuff'] }

      it 'returns true' do
        expect(result).to be_truthy
      end
    end

    context 'with an ancestor' do
      let(:query) { 'read:clients.this-guy' }
      let(:claims) { ['read:*', 'whatever:stuff'] }

      it 'returns true' do
        expect(result).to be_truthy
      end
    end

    context 'with a descendant' do
      let(:query) { 'read:clients.this-guy' }
      let(:claims) { ['read:clients.this-guy.something.else', 'whatever:stuff'] }

      it 'returns false' do
        expect(result).to be_falsey
      end
    end

    context 'with a nothing in common' do
      let(:query) { 'read:clients.this-guy' }
      let(:claims) { ['read:clients.another-guy.something.else', 'whatever:stuff'] }

      it 'returns false' do
        expect(result).to be_falsey
      end
    end
  end

  describe '.sub_claims_direct_children' do
    let(:query) { 'read:clients.this-guy' }
    let(:claims) { [] }

    context 'only_direct: true' do
      let(:result) { described_class.sub_claims_direct_children(query: query, claims: claims, only_direct: true) }

      context 'with no claims' do
        it 'returns empty array' do
          expect(result).to eq []
        end
      end

      context 'no claim has query as substring' do
        let(:claims) { ['read:clients.this-guy-but-not-the-same', 'read:clients.another-guy', 'admin:stufff'] }

        it 'returns empty array' do
          expect(result).to eq []
        end
      end

      context 'with the exact match' do
        let(:claims) { ['read:clients.this-guy', 'read:clients.another-guy', 'admin:stufff'] }

        it 'returns an array with :all `[:all]`' do
          expect(result).to eq [:all]
        end
      end

      context 'with an ancestor of the query' do
        let(:claims) { ['read:*'] }

        it 'returns an array with :all `[:all]`' do
          expect(result).to eq [:all]
        end
      end

      context 'with `MY_QUERY.*`' do
        let(:claims) do
          ['read:clients.this-guy-but-not-the-same',
           'read:clients.another-guy',
           'read:clients.this-guy.*',
           'read:clients.this-guy.stuff',
           'admin:stufff',
          ]
        end

        it 'returns an array with :all `[:all]`' do
          expect(result).to eq [:all]
        end
      end

      context 'with some claims with the query as the prefix' do
        let(:claims) do
          ['read:clients.this-guy-but-not-the-same',
           'read:clients.another-guy',
           'read:clients.this-guy.stuff',
           'read:clients.this-guy.wooa',
           'read:clients.this-guy.wooa.and.another',
           'read:clients.this-guy.wat.is.this',
           'admin:stufff',
          ]
        end

        let(:expected) do
          [
            'stuff',
            'wooa',
          ]
        end

        it 'returns the uniq list children nodes where direct (ignoring the claims that are more than one level down), sorted' do
          expect(result).to eq expected
        end
      end
    end

    context 'only_direct: false (default)' do
      let(:result) { described_class.sub_claims_direct_children(query: query, claims: claims, only_direct: false) }

      context 'with no claims' do
        it 'returns empty array' do
          expect(result).to eq []
        end
      end

      context 'no claim has query as substring' do
        let(:claims) { ['read:clients.this-guy-but-not-the-same', 'read:clients.another-guy', 'admin:stufff'] }

        it 'returns empty array' do
          expect(result).to eq []
        end
      end

      context 'with the exact match' do
        let(:claims) { ['read:clients.this-guy', 'read:clients.another-guy', 'admin:stufff'] }

        it 'returns an array with :all `[:all]`' do
          expect(result).to eq [:all]
        end
      end

      context 'with `MY_QUERY.*`' do
        let(:claims) do
          ['read:clients.this-guy-but-not-the-same',
           'read:clients.another-guy',
           'read:clients.this-guy.*',
           'read:clients.this-guy.stuff',
           'admin:stufff',
          ]
        end

        it 'returns an array with :all `[:all]`' do
          expect(result).to eq [:all]
        end
      end

      context 'with some claims with the query as the prefix' do
        let(:claims) do
          ['read:clients.this-guy-but-not-the-same',
           'read:clients.another-guy',
           'read:clients.this-guy.stuff',
           'read:clients.this-guy.wooa',
           'read:clients.this-guy.wooa.and.another',
           'read:clients.this-guy.wat.is.this',
           'admin:stufff',
          ]
        end

        let(:expected) do
          [
            'stuff',
            'wat',
            'wooa',
          ]
        end

        it 'returns the uniq list children nodes where direct (including the claims that are more than one level down), sorted' do
          expect(result).to eq expected
        end
      end
    end
  end
end
