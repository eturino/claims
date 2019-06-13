# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Claims::ClaimSet, type: :model do
  subject { described_class.for string_list }

  let(:string_list) { [string] }

  let(:string_list) { [string_global, string_normal, string_with_wildcard] }
  let(:string_global) { 'do:*' }
  let(:string_normal) { 'read:some.stuff' }
  let(:string_with_wildcard) { 'read:another.thing.*' }

  let(:clean_strings) { [clean_string_global, clean_string_normal, clean_string_with_wildcard].sort }
  let(:clean_string_global) { 'do:*' }
  let(:clean_string_normal) { 'read:some.stuff' }
  let(:clean_string_with_wildcard) { 'read:another.thing' }

  describe '#as_json' do
    it do
      expect(subject.as_json).to eq clean_strings
    end
  end

  describe '#to_json' do
    it do
      expect(subject.to_json).to eq clean_strings.to_json
    end
  end

  describe '.for' do
    context 'all valid strings' do
      let(:string_list) { [string_global, string_normal, string_global, string_with_wildcard, string_normal_same] }
      let(:string_global) { 'do:*' }
      let(:string_normal) { 'read:some.stuff' }
      let(:string_normal_same) { 'read:some.stuff.*' }
      let(:string_with_wildcard) { 'read:another.thing.*' }

      let(:clean_strings) { [clean_string_global, clean_string_normal, clean_string_with_wildcard].sort }
      let(:clean_string_global) { 'do:*' }
      let(:clean_string_normal) { 'read:some.stuff' }
      let(:clean_string_with_wildcard) { 'read:another.thing' }

      it 'creates sorted list of Claim objects, removing effective duplicates' do
        expect(subject).to be_a described_class
        expect(subject.map(&:clean_string)).to eq clean_strings
      end
    end

    context 'with an invalid string' do
      let(:string_list) { [string_bad, string_global, string_normal, string_with_wildcard] }
      let(:string_global) { 'do:*' }
      let(:string_normal) { 'read:some.stuff' }
      let(:string_with_wildcard) { 'read:another.thing.*' }
      let(:string_bad) { 'read-only-verb' }

      let(:clean_strings) { [clean_string_global, clean_string_normal, clean_string_with_wildcard].sort }
      let(:clean_string_global) { 'do:*' }
      let(:clean_string_normal) { 'read:some.stuff' }
      let(:clean_string_with_wildcard) { 'read:another.thing' }

      context 'with strict: true (default)' do
        subject { described_class.for string_list }
        it do
          expect { subject }.to raise_error(Claims::InvalidClaimError)
        end
      end

      context 'with strict: false' do
        subject { described_class.for string_list, strict: false }
        it 'creates sorted list of Claim objects, ignoring the bad ones' do
          expect(subject).to be_a described_class
          expect(subject.map(&:clean_string)).to eq clean_strings
        end
      end
    end
  end

  describe '#query?(read: something)' do
    context 'requesting something covered by some claim' do
      it do
        expect(subject.query?(do: 'whatever')).to be_truthy
      end
    end

    context 'requesting something that is not covered by any of the claims' do
      it do
        expect(subject.query?(read: 'yet.another.thing')).to be_falsey
      end
    end
  end

  describe 'equal if they have the same claims (not the same objects but objects representing the same claims)' do
    let(:a) { described_class.for ['a:stuff', 'b:*', 'c:wat.*'] }
    let(:b) { described_class.for ['a:stuff', 'b:*', 'c:wat'] }

    context '#==' do
      it { expect(a == b).to be_truthy }
    end

    context '#===' do
      it { expect(a === b).to be_truthy }
    end

    context '#<=>' do
      it { expect(a <=> b).to eq 0 }
    end

    context '#eql?' do
      it { expect(a.eql?(b)).to be_truthy }
    end
  end
end
