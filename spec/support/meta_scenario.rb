# A small, fully ranked metagame shared by the ranker and request specs.
#
#   store_championship (8 players, Extended, 10 days ago)
#     luke_and_wedge  Rebel   Luke (Proton Torpedoes) + Wedge   swiss 1st (1.0), cut 1st (1.0)
#     howl_swarm      Empire  Howlrunner (Crack Shot)           swiss 4th (0.5), missed the cut
#   casual_night (4 players, Hyperspace, 5 days ago)
#     solo_luke       Rebel   Luke (Crack Shot)                 swiss 2nd (0.75)
#   ancient_tournament (400 days ago, outside the default date range)
#     ancient_howl    Empire  Howlrunner                        swiss 1st (1.0)
#
# luke_and_wedge beat howl_swarm twice and lost to it once.
RSpec.shared_context 'meta scenario' do
  let!(:rebels)  { create_faction('Rebel Alliance') }
  let!(:empire)  { create_faction('Galactic Empire') }

  let!(:xwing)       { create_ship('T-65 X-wing', xws: 't65xwing') }
  let!(:tie_fighter) { create_ship('TIE/ln Fighter', xws: 'tielnfighter') }

  let!(:luke)       { create_pilot('Luke Skywalker', ship: xwing, faction: rebels) }
  let!(:wedge)      { create_pilot('Wedge Antilles', ship: xwing, faction: rebels) }
  let!(:howlrunner) { create_pilot('Howlrunner', ship: tie_fighter, faction: empire) }

  let!(:proton_torpedoes) { create_upgrade('Proton Torpedoes', type: 'Torpedo', image: 'https://example.test/proton.png') }
  let!(:crack_shot)       { create_upgrade('Crack Shot', type: 'Talent', image: 'https://example.test/crack.png') }

  let!(:store_type)  { TournamentType.create!(name: 'Store Championship') }
  let!(:casual_type) { TournamentType.create!(name: 'Casual') }
  let!(:extended)    { Format.create!(name: 'Extended') }
  let!(:hyperspace)  { Format.create!(name: 'Hyperspace') }

  let!(:double_xwing_combo) { create_ship_combo(xwing, xwing, archetype_name: 'Double X') }
  let!(:single_xwing_combo) { create_ship_combo(xwing) }
  let!(:tie_combo)          { create_ship_combo(tie_fighter, archetype_name: 'Howl Swarm') }

  let(:today) { Time.current.to_date }

  let!(:store_championship) do
    create_tournament(name: 'Store Championship', date: today - 10, num_players: 8, tournament_type: store_type, format: extended)
  end
  let!(:casual_night) do
    create_tournament(name: 'Casual Night', date: today - 5, num_players: 4, tournament_type: casual_type, format: hyperspace)
  end
  let!(:ancient_tournament) do
    create_tournament(name: 'Ancient', date: today - 400, num_players: 8, tournament_type: store_type, format: extended)
  end

  let!(:luke_and_wedge) do
    create_squadron(tournament: store_championship, faction: rebels, ship_combo: double_xwing_combo,
                    ships: [[luke, proton_torpedoes], wedge], player_name: 'Alice', name: 'Red Squadron',
                    swiss_standing: 1, swiss_percentile: 1.0, elimination_standing: 1, elimination_percentile: 1.0,
                    win_loss_ratio_swiss: 0.75,
                    xws: { 'faction' => 'rebelalliance', 'name' => 'Red Squadron',
                           'pilots' => [{ 'name' => 'lukeskywalker', 'ship' => 't65xwing',
                                          'upgrades' => { 'torpedo' => [{ 'name' => 'protontorpedoes', 'points' => 13 }] } },
                                        { 'name' => 'wedgeantilles', 'ship' => 't65xwing' }] })
  end
  let!(:howl_swarm) do
    create_squadron(tournament: store_championship, faction: empire, ship_combo: tie_combo,
                    ships: [[howlrunner, crack_shot]], player_name: 'Bob',
                    swiss_standing: 4, swiss_percentile: 0.5, win_loss_ratio_swiss: 0.25)
  end
  let!(:solo_luke) do
    create_squadron(tournament: casual_night, faction: rebels, ship_combo: single_xwing_combo,
                    ships: [[luke, crack_shot]], player_name: 'Carol',
                    swiss_standing: 2, swiss_percentile: 0.75)
  end
  let!(:ancient_howl) do
    create_squadron(tournament: ancient_tournament, faction: empire, ship_combo: tie_combo,
                    ships: [howlrunner], player_name: 'Dave',
                    swiss_standing: 1, swiss_percentile: 1.0)
  end

  let!(:games) do
    [
      create_game(winner: luke_and_wedge, loser: howl_swarm, round_number: 1),
      create_game(winner: luke_and_wedge, loser: howl_swarm, round_number: 2),
      create_game(winner: howl_swarm, loser: luke_and_wedge, round_number: 3),
    ]
  end
end
