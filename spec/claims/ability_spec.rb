# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Claims::Ability do
  subject do
    described_class.for permitted_claim_strings: permitted_claim_strings,
                        prohibited_claim_strings: prohibited_claim_strings
  end

  let(:permitted_claim_strings) { [] }
  let(:prohibited_claim_strings) { [] }

  describe 'cleans permitted and prohibited claims' do
    let(:prohibited_claim_strings) do
      [
        'wat:*', # forces its counterpart in permitted to be removed (global)
        'read:same.resource', # forces its counterpart in permitted to be removed (normal)
        'read:some.nested',
        'read:reverse.is.ok.nested',
      ]
    end

    let(:permitted_claim_strings) do
      [
        'do:*', # kept because we have nothing around this in prohibited (global)
        'keep:me', # kept because we have nothing around this in prohibited (global)
        'wat:*', # removed because we have the same in prohibited (global)
        'read:same.resource', # removed because we have the same in prohibited (normal)
        'read:some.nested.things', # removed because we have the parent in prohibited
        'read:reverse.is.ok', # kept because we just have a sub-resource in prohibited
      ]
    end

    let(:expected_permitted_claims) { ['do:*', 'keep:me', 'read:reverse.is.ok'] }

    it 'removes permitted claims if they prohibited by the prohibited claims' do
      expect(subject.permitted.as_json).to eq expected_permitted_claims.sort
    end
  end

  describe '#can? and #cannot?' do
    context 'when permitted and not prohibited' do
      let(:permitted_claim_strings) { ['read:clients'] }

      context '#can?' do
        it { expect(subject.can?(read: 'clients.acmeinc')).to eq true }
      end

      context '#cannot?' do
        it { expect(subject.cannot?(read: 'clients.acmeinc')).to eq false }
      end
    end

    context 'when permitted AND prohibited' do
      let(:permitted_claim_strings) { ['read:clients'] }
      let(:prohibited_claim_strings) { ['read:clients.acmeinc'] }

      context '#can?' do
        it { expect(subject.can?(read: 'clients.acmeinc')).to eq false }
      end

      context '#cannot?' do
        it { expect(subject.cannot?(read: 'clients.acmeinc')).to eq true }
      end
    end

    context 'when permitted AND prohibited have the same claim' do
      let(:permitted_claim_strings) { ['admin:clients.acmeinc.dashboards'] }
      let(:prohibited_claim_strings) { ['admin:clients.acmeinc.dashboards'] }

      context '#can?' do
        it { expect(subject.can?(admin: 'clients.acmeinc.dashboards')).to eq false }
      end

      context '#cannot?' do
        it { expect(subject.cannot?(admin: 'clients.acmeinc.dashboards')).to eq true }
      end
    end

    context 'when a general prohibited claim beats a specific permitted claim' do
      let(:permitted_claim_strings) { ['admin:clients.acmeinc.dashboards.client'] }
      let(:prohibited_claim_strings) { ['admin:clients.acmeinc.dashboards'] }

      context '#can?' do
        it { expect(subject.can?(admin: 'clients.acmeinc.dashboards.client')).to eq false }
      end

      context '#cannot?' do
        it { expect(subject.cannot?(admin: 'clients.acmeinc.dashboards.client')).to eq true }
      end
    end
  end

  describe '#access_to_client_keys' do
    context 'permitted: ["read:clients.*"], prohibited: []' do
      let(:permitted_claim_strings) { ['read:clients.*'] }
      let(:prohibited_claim_strings) { [] }

      let(:result) { subject.access_to_client_keys }

      it { expect(result).to be_a KeySet::All }
      it { expect(result).to be_represents_all }
    end

    context 'permitted: ["read:clients.*"], prohibited: ["read:clients"]' do
      let(:permitted_claim_strings) { ['read:clients.*'] }
      let(:prohibited_claim_strings) { ['read:clients'] }

      let(:result) { subject.access_to_client_keys }

      it { expect(result).to be_a KeySet::None }
      it { expect(result).to be_represents_none }
    end

    context 'permitted: ["read:clients.*"], prohibited: ["read:clients.first", "read:clients.second"]' do
      let(:permitted_claim_strings) { ['read:clients.*'] }
      let(:prohibited_claim_strings) { ['read:clients.first', 'read:clients.second'] }

      let(:result) { subject.access_to_client_keys }

      it { expect(result).to be_a KeySet::AllExceptSome }
      it { expect(result.keys.to_a).to eq ['first', 'second'].sort }
    end

    context 'permitted: ["read:clients.first.some.stuff", "read:clients.third.other.things"], prohibited: ["read:clients.first", "read:clients.second"]' do
      let(:permitted_claim_strings) { ['read:clients.first.some.stuff', 'read:clients.third.other.things'] }
      let(:prohibited_claim_strings) { ['read:clients.first', 'read:clients.second'] }

      let(:result) { subject.access_to_client_keys }

      it { expect(result).to be_a KeySet::Some }
      it { expect(result.keys.to_a).to eq ['third'].sort }
    end

    context 'permitted: ["read:clients.first.some.stuff", "read:clients.third.other.things"], prohibited: ["read:clients.first", "read:clients.second"]' do
      let(:permitted_claim_strings) { ['read:clients.first.some.stuff', 'read:clients.third.other.things'] }
      let(:prohibited_claim_strings) { ['read:clients.first', 'read:clients.second'] }

      let(:result) { subject.access_to_client_keys }

      it { expect(result).to be_a KeySet::Some }
      it { expect(result.keys.to_a).to eq ['third'].sort }
    end

    context 'permitted: ["read:clients.first", "read:clients.third"], prohibited: ["read:clients"]' do
      let(:permitted_claim_strings) { ['read:clients.first', 'read:clients.third'] }
      let(:prohibited_claim_strings) { ['read:clients'] }

      let(:result) { subject.access_to_client_keys }

      it { expect(result).to be_a KeySet::None }
      it { expect(result).to be_represents_none }
    end

    context 'permitted: ["read:clients.first", "read:clients.third"], prohibited: ["read:clients.third.people"]' do
      let(:permitted_claim_strings) { ['read:clients.first', 'read:clients.third'] }
      let(:prohibited_claim_strings) { ['read:clients.third.people'] }

      let(:result) { subject.access_to_client_keys }

      it { expect(result).to be_a KeySet::Some }
      it { expect(result.keys.to_a).to eq ['first', 'third'].sort }
    end
  end

  describe '#access_to_business_group_keys' do
    context 'permitted: ["read:business-groups.*"], prohibited: []' do
      let(:permitted_claim_strings) { ['read:business-groups.*'] }
      let(:prohibited_claim_strings) { [] }

      let(:result) { subject.access_to_business_group_keys }

      it { expect(result).to be_a KeySet::All }
      it { expect(result).to be_represents_all }
    end

    context 'permitted: ["read:business-groups.*"], prohibited: ["read:business-groups"]' do
      let(:permitted_claim_strings) { ['read:business-groups.*'] }
      let(:prohibited_claim_strings) { ['read:business-groups'] }

      let(:result) { subject.access_to_business_group_keys }

      it { expect(result).to be_a KeySet::None }
      it { expect(result).to be_represents_none }
    end

    context 'permitted: ["read:business-groups.*"], prohibited: ["read:business-groups.first", "read:business-groups.second"]' do
      let(:permitted_claim_strings) { ['read:business-groups.*'] }
      let(:prohibited_claim_strings) { ['read:business-groups.first', 'read:business-groups.second'] }

      let(:result) { subject.access_to_business_group_keys }

      it { expect(result).to be_a KeySet::AllExceptSome }
      it { expect(result.keys.to_a).to eq ['first', 'second'].sort }
    end

    context 'permitted: ["read:business-groups.first.some.stuff", "read:business-groups.third.other.things"], prohibited: ["read:business-groups.first", "read:business-groups.second"]' do
      let(:permitted_claim_strings) { ['read:business-groups.first.some.stuff', 'read:business-groups.third.other.things'] }
      let(:prohibited_claim_strings) { ['read:business-groups.first', 'read:business-groups.second'] }

      let(:result) { subject.access_to_business_group_keys }

      it { expect(result).to be_a KeySet::Some }
      it { expect(result.keys.to_a).to eq ['third'].sort }
    end

    context 'permitted: ["read:business-groups.first.some.stuff", "read:business-groups.third.other.things"], prohibited: ["read:business-groups.first", "read:business-groups.second"]' do
      let(:permitted_claim_strings) { ['read:business-groups.first.some.stuff', 'read:business-groups.third.other.things'] }
      let(:prohibited_claim_strings) { ['read:business-groups.first', 'read:business-groups.second'] }

      let(:result) { subject.access_to_business_group_keys }

      it { expect(result).to be_a KeySet::Some }
      it { expect(result.keys.to_a).to eq ['third'].sort }
    end

    context 'permitted: ["read:business-groups.first", "read:business-groups.third"], prohibited: ["read:business-groups"]' do
      let(:permitted_claim_strings) { ['read:business-groups.first', 'read:business-groups.third'] }
      let(:prohibited_claim_strings) { ['read:business-groups'] }

      let(:result) { subject.access_to_business_group_keys }

      it { expect(result).to be_a KeySet::None }
      it { expect(result).to be_represents_none }
    end

    context 'permitted: ["read:business-groups.first", "read:business-groups.third"], prohibited: ["read:business-groups.third.people"]' do
      let(:permitted_claim_strings) { ['read:business-groups.first', 'read:business-groups.third'] }
      let(:prohibited_claim_strings) { ['read:business-groups.third.people'] }

      let(:result) { subject.access_to_business_group_keys }

      it { expect(result).to be_a KeySet::Some }
      it { expect(result.keys.to_a).to eq ['first', 'third'].sort }
    end
  end

  describe '#access_to_project_keys(client_key)' do
    context 'permitted: ["read:clients.*"], prohibited: []' do
      let(:permitted_claim_strings) { ['read:clients.*'] }
      let(:prohibited_claim_strings) { [] }

      let(:client_key) { 'my-client' }

      let(:result) { subject.access_to_project_keys(client_key) }

      it { expect(result).to be_a KeySet::All }
      it { expect(result).to be_represents_all }
    end

    context 'permitted: ["read:clients.*"], prohibited: ["read:clients.my-client.projects"]' do
      let(:permitted_claim_strings) { ['read:clients.*'] }
      let(:prohibited_claim_strings) { ['read:clients.my-client.projects'] }

      let(:client_key) { 'my-client' }

      let(:result) { subject.access_to_project_keys(client_key) }

      it { expect(result).to be_a KeySet::None }
      it { expect(result).to be_represents_none }
    end

    context 'permitted: ["read:clients.*"], prohibited: ["read:clients.my-client.projects.project.bad-project"]' do
      let(:permitted_claim_strings) { ['read:clients.*'] }
      let(:prohibited_claim_strings) { ['read:clients.my-client.projects.project.bad-project'] }

      let(:client_key) { 'my-client' }

      let(:result) { subject.access_to_project_keys(client_key) }

      it { expect(result).to be_a KeySet::AllExceptSome }
      it { expect(result.keys.to_a).to eq ['bad-project'] }
    end

    context 'prohibiting people in one of the projects, it still counts that project' do
      let(:permitted_claim_strings) do
        [
          'read:clients.my-client.projects.project.one-project',
          'read:clients.my-client.projects.project.bad-project',
        ]
      end

      let(:prohibited_claim_strings) do
        [
          'read:clients.my-client.projects.project.one-project.people',
          'read:clients.my-client.projects.project.bad-project',
        ]
      end

      let(:client_key) { 'my-client' }

      let(:result) { subject.access_to_project_keys(client_key) }

      it { expect(result).to be_a KeySet::Some }
      it { expect(result.keys.to_a).to eq ['one-project'] }
    end
  end

  describe '#access_to_team_keys(client_key)' do
    context 'permitted: ["read:clients.*"], prohibited: []' do
      let(:permitted_claim_strings) { ['read:clients.*'] }
      let(:prohibited_claim_strings) { [] }

      let(:client_key) { 'my-client' }

      let(:result) { subject.access_to_team_keys(client_key) }

      it { expect(result).to be_a KeySet::All }
      it { expect(result).to be_represents_all }
    end

    context 'permitted: ["read:clients.*"], prohibited: ["read:clients.my-client.teams"]' do
      let(:permitted_claim_strings) { ['read:clients.*'] }
      let(:prohibited_claim_strings) { ['read:clients.my-client.teams'] }

      let(:client_key) { 'my-client' }

      let(:result) { subject.access_to_team_keys(client_key) }

      it { expect(result).to be_a KeySet::None }
      it { expect(result).to be_represents_none }
    end

    context 'permitted: ["read:clients.*"], prohibited: ["read:clients.my-client.teams.team.bad-team"]' do
      let(:permitted_claim_strings) { ['read:clients.*'] }
      let(:prohibited_claim_strings) { ['read:clients.my-client.teams.team.bad-team'] }

      let(:client_key) { 'my-client' }

      let(:result) { subject.access_to_team_keys(client_key) }

      it { expect(result).to be_a KeySet::AllExceptSome }
      it { expect(result.keys.to_a).to eq ['bad-team'] }
    end

    context 'prohibiting people in one of the teams, it still counts that team' do
      let(:permitted_claim_strings) do
        [
          'read:clients.my-client.teams.team.one-team',
          'read:clients.my-client.teams.team.bad-team',
        ]
      end

      let(:prohibited_claim_strings) do
        [
          'read:clients.my-client.teams.team.one-team.people',
          'read:clients.my-client.teams.team.bad-team',
        ]
      end

      let(:client_key) { 'my-client' }

      let(:result) { subject.access_to_team_keys(client_key) }

      it { expect(result).to be_a KeySet::Some }
      it { expect(result.keys.to_a).to eq ['one-team'] }
    end
  end

  describe '#access_to_people_ids(client_key)' do
    context 'permitted: ["read:clients.*"], prohibited: []' do
      let(:permitted_claim_strings) { ['read:clients.*'] }
      let(:prohibited_claim_strings) { [] }

      let(:client_key) { 'my-client' }

      let(:result) { subject.access_to_people_ids(client_key) }

      it { expect(result).to be_a KeySet::All }
      it { expect(result).to be_represents_all }
    end

    context 'permitted: ["read:clients.*"], prohibited: ["read:clients.my-client.people"]' do
      let(:permitted_claim_strings) { ['read:clients.*'] }
      let(:prohibited_claim_strings) { ['read:clients.my-client.people'] }

      let(:client_key) { 'my-client' }

      let(:result) { subject.access_to_people_ids(client_key) }

      it { expect(result).to be_a KeySet::None }
      it { expect(result).to be_represents_none }
    end

    context 'permitted: ["read:clients.*"], prohibited: ["read:clients.my-client.people.person.bad-person"]' do
      let(:permitted_claim_strings) { ['read:clients.*'] }
      let(:prohibited_claim_strings) { ['read:clients.my-client.people.person.bad-person'] }

      let(:client_key) { 'my-client' }

      let(:result) { subject.access_to_people_ids(client_key) }

      it { expect(result).to be_a KeySet::AllExceptSome }
      it { expect(result.keys.to_a).to eq ['bad-person'] }
    end

    context 'prohibiting teams in one of the people, it still counts that person' do
      let(:permitted_claim_strings) do
        [
          'read:clients.my-client.people.person.one-person',
          'read:clients.my-client.people.person.bad-person',
        ]
      end

      let(:prohibited_claim_strings) do
        [
          'read:clients.my-client.people.person.one-person.teams',
          'read:clients.my-client.people.person.bad-person',
        ]
      end

      let(:client_key) { 'my-client' }

      let(:result) { subject.access_to_people_ids(client_key) }

      it { expect(result).to be_a KeySet::Some }
      it { expect(result.keys.to_a).to eq ['one-person'] }
    end
  end
end
