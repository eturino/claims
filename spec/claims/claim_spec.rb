# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Claims::Claim, type: :model do
  subject { described_class.for string }

  let(:string) { "#{verb}:#{resource}" }
  let(:resource) { 'some.stuff.nested' }
  let(:verb) { :read }

  describe '.for' do
    context 'without string argument on creation' do
      it 'fails with ArgumentError' do
        expect { described_class.for }.to raise_error(ArgumentError)
      end
    end

    context 'with nil string argument' do
      let(:string) { nil }

      it 'fails with InvalidClaimError' do
        expect { subject }.to raise_error(Claims::InvalidClaimError)
      end
    end

    context 'with empty string argument' do
      let(:string) { '' }

      it 'fails with InvalidClaimError' do
        expect { subject }.to raise_error(Claims::InvalidClaimError)
      end
    end

    context 'bad string argument: no colon' do
      let(:string) { 'verb.without.colon' }

      it 'fails with InvalidClaimError' do
        expect { subject }.to raise_error(Claims::InvalidClaimError)
      end
    end

    context 'bad string argument: multiple wildcards' do
      let(:string) { 'verb:stuff.*.bad' }

      it 'fails with InvalidClaimError' do
        expect { subject }.to raise_error(Claims::InvalidClaimError)
      end
    end

    context 'normal resource claim `verb:stuff`' do
      let(:string) { 'verb:stuff' }

      it 'returns a Claim, non global, with the string' do
        expect(subject).to be_a Claims::Claim
        expect(subject.global?).to be_falsey
        expect(subject.string).to eq string
      end
    end

    context 'normal resource claim `verb:stuff.like.this`' do
      let(:string) { 'verb:stuff.like.this' }

      it 'returns a Claim, non global, with the string' do
        expect(subject).to be_a Claims::Claim
        expect(subject.global?).to be_falsey
        expect(subject.string).to eq string
      end
    end

    context 'global resource claim `verb:stuff.like.this`' do
      let(:string) { "#{verb}:*" }
      let(:verb) { :verb }

      it 'returns a Claim, global, with the string' do
        expect(subject).to be_a Claims::Claim
        expect(subject.global?).to be_truthy
        expect(subject.string).to eq string
        expect(subject.verb).to eq verb.to_sym
        expect(subject.resource).to be_blank
      end
    end
  end

  describe '#verb' do
    it 'returns the verb of the claim, as a symbol' do
      expect(subject.verb).to eq verb.to_sym
    end
  end

  describe '#resource' do
    context 'normal resource' do
      it 'returns the resource of the claim, as a string' do
        expect(subject.resource).to eq resource
      end
    end

    context 'resource with wildcard at the end' do
      let(:clean_resource) { 'stuff.like.this' }
      let(:resource) { "#{clean_resource}.*" }

      it 'returns the resource of the claim, as a string, removing the `.*` at the end' do
        expect(subject.resource).to eq clean_resource
      end
    end
  end

  describe '#same_verb?' do
    context 'global claim' do
      let(:string) { "#{verb}:*" }
      let(:verb) { 'my-verb'.to_sym }

      context 'giving the same verb as the claim (as a string)' do
        it { expect(subject.same_verb?(verb.to_s)).to be_truthy }
      end

      context 'giving the same verb as the claim (as a symbol)' do
        it { expect(subject.same_verb?(verb.to_sym)).to be_truthy }
      end

      context 'giving a different verb as the claim (as a symbol)' do
        it { expect(subject.same_verb?(:another)).to be_falsey }
      end

      context 'giving a different verb as the claim (as a string)' do
        it { expect(subject.same_verb?('another')).to be_falsey }
      end
    end

    context 'normal claim' do
      let(:string) { "#{verb}:some.resource" }
      let(:verb) { 'my-verb'.to_sym }

      context 'giving the same verb as the claim (as a string)' do
        it { expect(subject.same_verb?(verb.to_s)).to be_truthy }
      end

      context 'giving the same verb as the claim (as a symbol)' do
        it { expect(subject.same_verb?(verb.to_sym)).to be_truthy }
      end

      context 'giving a different verb as the claim (as a symbol)' do
        it { expect(subject.same_verb?(:another)).to be_falsey }
      end

      context 'giving a different verb as the claim (as a string)' do
        it { expect(subject.same_verb?('another')).to be_falsey }
      end
    end
  end

  describe '#query?(some_verb: "the.resource.to.look.for")' do
    let(:verb) { :read }

    context 'global claim' do
      let(:string) { "#{verb}:*" }

      context 'wrong params' do
        context 'nil' do
          it { expect { subject.query? nil }.to raise_error(ArgumentError) }
        end

        context 'a string' do
          it { expect { subject.query? 'whatever:blah.blah' }.to raise_error(ArgumentError) }
        end

        context 'a symbol' do
          it { expect { subject.query? verb.to_sym }.to raise_error(ArgumentError) }
        end

        context 'an empty hash' do
          it { expect { subject.query?({}) }.to raise_error(ArgumentError) }
        end

        context 'a hash with more than one key' do
          it { expect { subject.query?({ something: 'a', another: 'blah' }) }.to raise_error(ArgumentError) }
        end
      end

      context 'passing the right verb (as string) and any resource name' do
        let(:params) { { verb.to_s => 'blah' } }

        it { expect(subject.query?(params)).to be_truthy }
      end

      context 'passing the right verb (as symbol) and any resource name' do
        let(:params) { { verb.to_sym => 'blah' } }

        it { expect(subject.query?(params)).to be_truthy }
      end

      context 'passing the right verb (as string) and nil as resource' do
        let(:params) { { verb.to_s => nil } }

        it { expect(subject.query?(params)).to be_truthy }
      end

      context 'passing the right verb (as symbol) and nil as resource' do
        let(:params) { { verb.to_sym => nil } }

        it { expect(subject.query?(params)).to be_truthy }
      end

      context 'passing the right verb (as string) and an empty string as resource' do
        let(:params) { { verb.to_s => '' } }

        it { expect(subject.query?(params)).to be_truthy }
      end

      context 'passing the right verb (as symbol) and an empty string as resource' do
        let(:params) { { verb.to_sym => '' } }

        it { expect(subject.query?(params)).to be_truthy }
      end

      context 'passing the wrong verb (as string) and an empty string as resource' do
        let(:params) { { 'another' => '' } }

        it { expect(subject.query?(params)).to be_falsey }
      end

      context 'passing the wrong verb (as symbol) and an empty string as resource' do
        let(:params) { { another: '' } }

        it { expect(subject.query?(params)).to be_falsey }
      end
    end

    context 'normal claim' do
      let(:resource) { 'some.resource' }
      let(:string) { "#{verb}:#{resource}" }

      context 'passing the wrong verb (symbol) and the exact resource' do
        it { expect(subject.query?(another: resource)).to be_falsey }
      end

      context 'passing the wrong verb (string) and the exact resource' do
        it { expect(subject.query?('another' => resource)).to be_falsey }
      end

      context 'passing the right verb (symbol) and the wrong resource' do
        it { expect(subject.query?(read: 'bad-resource')).to be_falsey }
      end

      context 'passing the right verb (string) and the wrong resource' do
        it { expect(subject.query?('read' => 'bad-resource')).to be_falsey }
      end

      context 'passing the right verb (symbol) and the exact resource' do
        it { expect(subject.query?(read: resource)).to be_truthy }
      end

      context 'passing the right verb (string) and the exact resource' do
        it { expect(subject.query?('read' => resource)).to be_truthy }
      end

      context 'passing the right verb (symbol) and the exact resource with wildcard' do
        it { expect(subject.query?(read: "#{resource}.*")).to be_truthy }
      end

      context 'passing the right verb (string) and the exact resource with wildcard' do
        it { expect(subject.query?('read' => "#{resource}.*")).to be_truthy }
      end

      context 'passing the right verb (symbol) and a sub resource' do
        it { expect(subject.query?(read: "#{resource}.something.inside")).to be_truthy }
      end

      context 'passing the right verb (string) and a sub resource' do
        it { expect(subject.query?('read' => "#{resource}.something.inside")).to be_truthy }
      end

      context 'passing the right verb (symbol) and a sub resource with wildcard' do
        it { expect(subject.query?(read: "#{resource}.something.inside.*")).to be_truthy }
      end

      context 'passing the right verb (string) and a sub resource with wildcard' do
        it { expect(subject.query?('read' => "#{resource}.something.inside.*")).to be_truthy }
      end
    end
  end

  describe '#exact?(some_verb: "the.resource.to.look.for"' do
    context 'global claim' do
      let(:string) { 'read:*' }

      context 'same verb, nil resource' do
        it do
          expect(subject.exact?(read: nil)).to be_truthy
        end
      end

      context 'same verb, empty string resource' do
        it do
          expect(subject.exact?(read: '')).to be_truthy
        end
      end

      context 'same verb, "*" resource' do
        it do
          expect(subject.exact?(read: '*')).to be_truthy
        end
      end

      context 'same verb, a present resource' do
        it do
          expect(subject.exact?(read: 'whatever')).to be_falsey
        end
      end
    end

    context 'normal claim' do
      let(:string) { 'read:some.stuff' }

      context 'same verb, nil resource' do
        it do
          expect(subject.exact?(read: nil)).to be_falsey
        end
      end

      context 'same verb, empty string resource' do
        it do
          expect(subject.exact?(read: '')).to be_falsey
        end
      end

      context 'same verb, "*" resource' do
        it do
          expect(subject.exact?(read: '*')).to be_falsey
        end
      end

      context 'same verb, the same resource' do
        it do
          expect(subject.exact?(read: 'some.stuff')).to be_truthy
        end
      end

      context 'same verb, a different resource' do
        it do
          expect(subject.exact?(read: 'some.another')).to be_falsey
        end
      end

      context 'same verb, a sub resource' do
        it do
          expect(subject.exact?(read: 'some.stuff.inside')).to be_falsey
        end
      end
    end
  end

  describe '#direct_child(some_verb: "the.resource.to.look.for"' do
    context 'global claim' do
      let(:string) { 'read:*' }

      context 'same verb, nil resource' do
        context '#direct_child' do
          it { expect(subject.direct_child(read: nil)).to be_nil }
        end

        context '#direct_child?' do
          it { expect(subject.direct_child?(read: nil)).to eq false }
        end
      end

      context 'same verb, empty string resource' do
        context '#direct_child' do
          it { expect(subject.direct_child(read: '')).to be_nil }
        end

        context '#direct_child?' do
          it { expect(subject.direct_child?(read: '')).to eq false }
        end
      end

      context 'same verb, "*" resource' do
        context '#direct_child' do
          it { expect(subject.direct_child(read: '*')).to be_nil }
        end

        context '#direct_child?' do
          it { expect(subject.direct_child?(read: '*')).to eq false }
        end
      end

      context 'same verb, a present resource' do
        context '#direct_child' do
          it { expect(subject.direct_child(read: 'whatever')).to be_nil }
        end

        context '#direct_child?' do
          it { expect(subject.direct_child?(read: 'whatever')).to eq false }
        end
      end
    end

    context 'normal claim' do
      context 'having a first level resource in the Claim' do
        let(:string) { "read:#{resource}" }
        let(:resource) { 'claim-resource' }

        context 'same verb, nil resource' do
          context '#direct_child' do
            it { expect(subject.direct_child(read: nil)).to eq resource }
          end

          context '#direct_child?' do
            it { expect(subject.direct_child?(read: nil)).to eq true }
          end
        end

        context 'same verb, empty string resource' do
          context '#direct_child' do
            it { expect(subject.direct_child(read: '')).to eq resource }
          end

          context '#direct_child?' do
            it { expect(subject.direct_child?(read: '')).to eq true }
          end
        end

        context 'same verb, "*" resource' do
          context '#direct_child' do
            it { expect(subject.direct_child(read: '*')).to eq resource }
          end

          context '#direct_child?' do
            it { expect(subject.direct_child?(read: '*')).to eq true }
          end
        end

        context 'same verb, the same resource' do
          context '#direct_child' do
            it { expect(subject.direct_child(read: 'this')).to be_nil }
          end

          context '#direct_child?' do
            it { expect(subject.direct_child?(read: 'this')).to eq false }
          end
        end

        context 'same verb, a different resource' do
          context '#direct_child' do
            it { expect(subject.direct_child(read: 'another')).to be_nil }
          end

          context '#direct_child?' do
            it { expect(subject.direct_child?(read: 'another')).to eq false }
          end
        end
      end

      context 'having a nested level resource in the Claim' do
        let(:string) { 'read:what.some.stuff' }

        context 'same verb, nil resource' do
          context '#direct_child' do
            it { expect(subject.direct_child(read: nil)).to be_nil }
          end

          context '#direct_child?' do
            it { expect(subject.direct_child?(read: nil)).to eq false }
          end
        end

        context 'same verb, empty string resource' do
          context '#direct_child' do
            it { expect(subject.direct_child(read: '')).to be_nil }
          end

          context '#direct_child?' do
            it { expect(subject.direct_child?(read: '')).to eq false }
          end
        end

        context 'same verb, "*" resource' do
          context '#direct_child' do
            it { expect(subject.direct_child(read: '*')).to be_nil }
          end

          context '#direct_child?' do
            it { expect(subject.direct_child?(read: '*')).to eq false }
          end
        end

        context 'same verb, a different resource' do
          context '#direct_child' do
            it { expect(subject.direct_child(read: 'another')).to be_nil }
          end

          context '#direct_child?' do
            it { expect(subject.direct_child?(read: 'another')).to eq false }
          end
        end

        context 'same verb, the same resource' do
          context '#direct_child' do
            it { expect(subject.direct_child(read: 'what.some.stuff')).to be_nil }
          end

          context '#direct_child?' do
            it { expect(subject.direct_child?(read: 'what.some.stuff')).to eq false }
          end
        end

        context 'same verb, a sub resource' do
          context '#direct_child' do
            it { expect(subject.direct_child(read: 'what.some.stuff.nested')).to be_nil }
          end

          context '#direct_child?' do
            it { expect(subject.direct_child?(read: 'what.some.stuff.nested')).to eq false }
          end
        end

        context 'same verb, a different resource, with a common ancestor' do
          context '#direct_child' do
            it { expect(subject.direct_child(read: 'what.xxx')).to be_nil }
          end

          context '#direct_child?' do
            it { expect(subject.direct_child?(read: 'what.xxx')).to eq false }
          end
        end

        context 'same verb, the parent resource' do
          context '#direct_child' do
            it { expect(subject.direct_child(read: 'what.some')).to eq 'stuff' }
          end

          context '#direct_child?' do
            it { expect(subject.direct_child?(read: 'what.some')).to eq true }
          end
        end

        context 'same verb, an ancestor resource' do
          context '#direct_child' do
            it { expect(subject.direct_child(read: 'what')).to be_nil }
          end

          context '#direct_child?' do
            it { expect(subject.direct_child?(read: 'what')).to eq false }
          end
        end
      end
    end
  end

  describe '#direct_descendant(some_verb: "the.resource.to.look.for"' do
    context 'global claim' do
      let(:string) { 'read:*' }

      context 'same verb, nil resource' do
        context '#direct_descendant' do
          it { expect(subject.direct_descendant(read: nil)).to be_nil }
        end

        context '#direct_descendant?' do
          it { expect(subject.direct_descendant?(read: nil)).to eq false }
        end
      end

      context 'same verb, empty string resource' do
        context '#direct_descendant' do
          it { expect(subject.direct_descendant(read: '')).to be_nil }
        end

        context '#direct_descendant?' do
          it { expect(subject.direct_descendant?(read: '')).to eq false }
        end
      end

      context 'same verb, "*" resource' do
        context '#direct_descendant' do
          it { expect(subject.direct_descendant(read: '*')).to be_nil }
        end

        context '#direct_descendant?' do
          it { expect(subject.direct_descendant?(read: '*')).to eq false }
        end
      end

      context 'same verb, a present resource' do
        context '#direct_descendant' do
          it { expect(subject.direct_descendant(read: 'whatever')).to be_nil }
        end

        context '#direct_descendant?' do
          it { expect(subject.direct_descendant?(read: 'whatever')).to eq false }
        end
      end
    end

    context 'normal claim' do
      context 'having a first level resource in the Claim' do
        let(:string) { "read:#{resource}" }
        let(:resource) { 'claim-resource' }

        context 'same verb, nil resource' do
          context '#direct_descendant' do
            it { expect(subject.direct_descendant(read: nil)).to eq resource }
          end

          context '#direct_descendant?' do
            it { expect(subject.direct_descendant?(read: nil)).to eq true }
          end
        end

        context 'same verb, empty string resource' do
          context '#direct_descendant' do
            it { expect(subject.direct_descendant(read: '')).to eq resource }
          end

          context '#direct_descendant?' do
            it { expect(subject.direct_descendant?(read: '')).to eq true }
          end
        end

        context 'same verb, "*" resource' do
          context '#direct_descendant' do
            it { expect(subject.direct_descendant(read: '*')).to eq resource }
          end

          context '#direct_descendant?' do
            it { expect(subject.direct_descendant?(read: '*')).to eq true }
          end
        end

        context 'same verb, the same resource' do
          context '#direct_descendant' do
            it { expect(subject.direct_descendant(read: 'this')).to be_nil }
          end

          context '#direct_descendant?' do
            it { expect(subject.direct_descendant?(read: 'this')).to eq false }
          end
        end

        context 'same verb, a different resource' do
          context '#direct_descendant' do
            it { expect(subject.direct_descendant(read: 'another')).to be_nil }
          end

          context '#direct_descendant?' do
            it { expect(subject.direct_descendant?(read: 'another')).to eq false }
          end
        end
      end

      context 'having a nested level resource in the Claim' do
        let(:string) { 'read:what.some.stuff' }

        context 'same verb, nil resource' do
          context '#direct_descendant' do
            it { expect(subject.direct_descendant(read: nil)).to eq 'what' }
          end

          context '#direct_descendant?' do
            it { expect(subject.direct_descendant?(read: nil)).to eq true }
          end
        end

        context 'same verb, empty string resource' do
          context '#direct_descendant' do
            it { expect(subject.direct_descendant(read: '')).to eq 'what' }
          end

          context '#direct_descendant?' do
            it { expect(subject.direct_descendant?(read: '')).to eq true }
          end
        end

        context 'same verb, "*" resource' do
          context '#direct_descendant' do
            it { expect(subject.direct_descendant(read: '*')).to eq 'what' }
          end

          context '#direct_descendant?' do
            it { expect(subject.direct_descendant?(read: '*')).to eq true }
          end
        end

        context 'same verb, a different resource' do
          context '#direct_descendant' do
            it { expect(subject.direct_descendant(read: 'another')).to be_nil }
          end

          context '#direct_descendant?' do
            it { expect(subject.direct_descendant?(read: 'another')).to eq false }
          end
        end

        context 'same verb, the same resource' do
          context '#direct_descendant' do
            it { expect(subject.direct_descendant(read: 'what.some.stuff')).to be_nil }
          end

          context '#direct_descendant?' do
            it { expect(subject.direct_descendant?(read: 'what.some.stuff')).to eq false }
          end
        end

        context 'same verb, a sub resource' do
          context '#direct_descendant' do
            it { expect(subject.direct_descendant(read: 'what.some.stuff.nested')).to be_nil }
          end

          context '#direct_descendant?' do
            it { expect(subject.direct_descendant?(read: 'what.some.stuff.nested')).to eq false }
          end
        end

        context 'same verb, a different resource, with a common ancestor' do
          context '#direct_descendant' do
            it { expect(subject.direct_descendant(read: 'what.xxx')).to be_nil }
          end

          context '#direct_descendant?' do
            it { expect(subject.direct_descendant?(read: 'what.xxx')).to eq false }
          end
        end

        context 'same verb, the parent resource' do
          context '#direct_descendant' do
            it { expect(subject.direct_descendant(read: 'what.some')).to eq 'stuff' }
          end

          context '#direct_descendant?' do
            it { expect(subject.direct_descendant?(read: 'what.some')).to eq true }
          end
        end

        context 'same verb, an ancestor resource' do
          context '#direct_descendant' do
            it { expect(subject.direct_descendant(read: 'what')).to eq 'some' }
          end

          context '#direct_descendant?' do
            it { expect(subject.direct_descendant?(read: 'what')).to eq true }
          end
        end
      end
    end
  end

  describe 'equality' do
    let(:claim) { described_class.for 'read:stuff' }
    let(:claim_same) { described_class.for 'read:stuff.*' }
    let(:claim_other_verb) { described_class.for 'admin:stuff' }
    let(:claim_other_resource) { described_class.for 'read:another' }

    it 'claim == claim_same' do
      expect(claim == claim_same).to be_truthy
    end

    it 'claim === claim_same' do
      expect(claim === claim_same).to be_truthy
    end

    it 'claim.eql? claim_same' do
      expect(claim.eql?(claim_same)).to be_truthy
    end

    it 'claim != claim_other_verb' do
      expect(claim == claim_other_verb).to be_falsey
    end

    it 'claim != claim_other_resource' do
      expect(claim == claim_other_resource).to be_falsey
    end

    it 'claim and claim_same, one of them removed because of .uniq' do
      expect([claim, claim_same, claim_other_resource].uniq).to eq [claim, claim_other_resource]
    end
  end

  describe '#clean_string' do
    context 'for a global claim `read:*`' do
      let(:string) { 'read:*' }

      it { expect(subject.clean_string).to eq string }
    end

    context 'for a normal claim `read:some.things`' do
      let(:string) { 'read:some.things' }

      it { expect(subject.clean_string).to eq string }
    end

    context 'for a normal claim, built with wildcard `read:some.stuff.*`' do
      let(:string) { "#{base}.*" }
      let(:base) { 'read:some.stuff' }

      it { expect(subject.clean_string).to eq base }
    end
  end

  describe '#as_json' do
    context 'for a global claim `read:*`' do
      let(:string) { 'read:*' }

      it { expect(subject.as_json).to eq string }
    end

    context 'for a normal claim `read:some.things`' do
      let(:string) { 'read:some.things' }

      it { expect(subject.as_json).to eq string }
    end

    context 'for a normal claim, built with wildcard `read:some.stuff.*`' do
      let(:string) { "#{base}.*" }
      let(:base) { 'read:some.stuff' }

      it { expect(subject.as_json).to eq base }
    end
  end

  describe '#to_json' do
    context 'for a global claim `read:*`' do
      let(:string) { 'read:*' }

      it { expect(subject.to_json).to eq string.to_json }
    end

    context 'for a normal claim `read:some.things`' do
      let(:string) { 'read:some.things' }

      it { expect(subject.to_json).to eq string.to_json }
    end

    context 'for a normal claim, built with wildcard `read:some.stuff.*`' do
      let(:string) { "#{base}.*" }
      let(:base) { 'read:some.stuff' }

      it { expect(subject.to_json).to eq base.to_json }
    end
  end
end
