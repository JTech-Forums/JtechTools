# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseModElections::Stv do
  def ballot(weight, *ranking)
    described_class::Ballot.new(weight, ranking)
  end

  def count(candidates, ballots, seats: 3, seed: 1, excluded: [])
    described_class.count(
      candidates: candidates,
      ballots: ballots,
      seats: seats,
      seed: seed,
      excluded: excluded,
    )
  end

  # The worked example on Wikipedia's "Single transferable vote" page.
  let(:food) do
    [
      ballot(4, "orange"),
      ballot(2, "pear", "orange"),
      ballot(8, "chocolate", "strawberry"),
      ballot(4, "chocolate", "burger"),
      ballot(1, "strawberry"),
      ballot(1, "burger"),
    ]
  end
  let(:dishes) { %w[orange pear chocolate strawberry burger] }

  it "elects the textbook winners, stage by stage" do
    result = count(dishes, food)

    expect(result.quota).to eq(6)
    expect(result.elected).to eq(%w[chocolate orange strawberry])
    expect(result.stages.map(&:action)).to eq(%i[first surplus exclusion exclusion])
    expect(result.stages[0].elected).to eq(%w[chocolate])
    # Chocolate's 6 surplus votes move on at half value.
    expect(result.stages[1].tallies).to include("chocolate" => 6, "strawberry" => 5, "burger" => 3)
    expect(result.stages[2].candidate).to eq("pear")
    expect(result.stages[2].elected).to eq(%w[orange])
    expect(result.stages[3].elected).to eq(%w[strawberry])
    expect(result.exhausted).to eq(3)
  end

  it "counts a ballot of weight 3 exactly like three ballots of weight 1" do
    unweighted = food.flat_map { |b| Array.new(b.weight) { ballot(1, *b.ranking) } }

    weighted = count(dishes, food)
    split = count(dishes, unweighted)

    expect(split.elected).to eq(weighted.elected)
    expect(split.stages.map(&:tallies)).to eq(weighted.stages.map(&:tallies))
  end

  it "lets weight decide: one trust level 4 vote outweighs three trust level 1 votes" do
    result =
      count(%w[a b], [ballot(4, "a"), ballot(1, "b"), ballot(1, "b"), ballot(1, "b")], seats: 1)
    expect(result.elected).to eq(%w[a])
  end

  it "never counts a lower choice against a higher one" do
    # Adding a second choice to the ballots that elect "a" can't stop "a".
    plain = count(%w[a b c], [ballot(3, "a"), ballot(2, "b"), ballot(2, "c")], seats: 1)
    with_seconds = count(%w[a b c], [ballot(3, "a", "b"), ballot(2, "b"), ballot(2, "c")], seats: 1)

    expect(plain.elected).to eq(%w[a])
    expect(with_seconds.elected).to eq(%w[a])
  end

  it "ignores names that aren't running, repeats, and empty or weightless ballots" do
    result =
      count(
        %w[a b c d],
        [
          ballot(2, "ghost", "a", "a", "b"),
          ballot(0, "c"),
          ballot(3),
          ballot(1, "d"),
          ballot(1, "c"),
        ],
        seats: 1,
      )

    expect(result.ballots).to eq(3)
    expect(result.total).to eq(4)
    expect(result.elected).to eq(%w[a])
  end

  it "elects everyone unopposed when there are no more candidates than seats" do
    result = count(%w[a b], [ballot(2, "a")])

    expect(result.outcome).to eq(:unopposed)
    expect(result.elected).to contain_exactly("a", "b")
  end

  it "elects nobody in a contested election nobody voted in" do
    result = count(%w[a b c d], [])

    expect(result.outcome).to eq(:no_votes)
    expect(result.elected).to be_empty
  end

  describe "ties" do
    it "excludes whoever did worse at the earliest stage they differed" do
      # After a's surplus moves, b and c are level, but c had fewer first
      # preferences, so c goes.
      result =
        count(
          %w[a b c d],
          [ballot(7, "a", "c"), ballot(3, "b"), ballot(2, "c"), ballot(4, "d")],
          seats: 2,
        )

      exclusion = result.stages.find { |s| s.action == :exclusion }
      expect(exclusion.candidate).to eq("c")
      expect(exclusion.tie).to include(method: :earlier_stage, chosen: "c")
    end

    it "draws lots when the candidates were level at every stage" do
      ballots = %w[a b c d].map { |id| ballot(1, id) }

      results = (1..20).map { |seed| count(%w[a b c d], ballots, seed: seed) }
      excluded = results.map { |r| r.stages.find { |s| s.action == :exclusion }.candidate }

      expect(results.first.stages.last.tie).to include(method: :lot)
      # Same seed, same draw.
      expect(count(%w[a b c d], ballots, seed: 7).elected).to eq(
        count(%w[a b c d], ballots, seed: 7).elected,
      )
      # And the draw isn't always the same person.
      expect(excluded.uniq.size).to be > 1
    end
  end

  it "recounts as if a candidate never ran (a countback)" do
    result = count(dishes, food, excluded: %w[chocolate])

    expect(result.elected).not_to include("chocolate")
    expect(result.stages.first.tallies.keys).not_to include("chocolate")
    expect(result.elected.size).to eq(3)
  end
end
