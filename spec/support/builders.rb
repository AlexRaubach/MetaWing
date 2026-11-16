# Plain-Ruby record builders for specs. Each one creates the minimum valid
# record and lets the caller override whatever the example cares about.
module Builders
  def create_faction(name = 'Rebel Alliance', xws: name.downcase.delete(' '))
    Faction.create!(name: name, xws: xws)
  end

  def create_ship(name, xws: name.downcase.gsub(/[^a-z0-9]/, ''), **attributes)
    Ship.create!({ name: name, xws: xws, size: 'small' }.merge(attributes))
  end

  def create_pilot(name, ship:, faction:, xws: name.downcase.gsub(/[^a-z0-9]/, ''), **attributes)
    Pilot.create!({ name: name, xws: xws, ship: ship, faction: faction }.merge(attributes))
  end

  # Creates the upgrade together with its (single) card side
  def create_upgrade(name, type: 'Talent', xws: name.downcase.gsub(/[^a-z0-9]/, ''), image: nil, **attributes)
    upgrade = Upgrade.create!({ name: name, xws: xws }.merge(attributes))
    UpgradeSide.create!(upgrade: upgrade, title: name, upgrade_type: type, image: image)
    upgrade
  end

  def create_tournament(**attributes)
    @lists_juggler_sequence = (@lists_juggler_sequence || 1000) + 1
    Tournament.create!({
      name:             "Tournament #{@lists_juggler_sequence}",
      lists_juggler_id: @lists_juggler_sequence,
      date:             Time.current.to_date - 7,
      num_players:      8,
      tournament_type:  TournamentType.find_or_create_by!(name: 'Store Championship'),
      format:           Format.find_or_create_by!(name: 'Extended'),
    }.merge(attributes))
  end

  # `ships` is a list of pilots; give a pilot upgrades with [pilot, upgrade, ...]
  def create_squadron(tournament:, faction:, ships: [], **attributes)
    squadron = Squadron.create!({ tournament: tournament, faction_id: faction.id }.merge(attributes))
    ships.each do |pilot, *upgrades|
      ShipConfiguration.create!(squadron: squadron, pilot: pilot, upgrades: upgrades)
    end
    squadron
  end

  def create_ship_combo(*ships, **attributes)
    ShipCombo.create!({ ships: ships }.merge(attributes))
  end

  def create_game(winner:, loser:, **attributes)
    Game.create!({
      tournament:       winner.tournament,
      winning_squadron: winner,
      losing_squadron:  loser,
      winning_combo:    winner.ship_combo,
      losing_combo:     loser.ship_combo,
      round_type:       'swiss',
      round_number:     1,
    }.merge(attributes))
  end

  # The hash ApplicationController#ranking_configuration hands to the rankers
  def ranking_config(**overrides)
    {
      large_tournament_multiplier: false,
      widespread_use_multiplier:   false,
      use_ranking_data:            'swiss',
      ranking_start:               Time.current.to_date - 30,
      ranking_end:                 Time.current.to_date,
      tournament_type:             nil,
      format_id:                   nil,
    }.merge(overrides)
  end

  # Splits mixed options into what a ranker takes: [ranking configuration, filter keywords]
  def ranker_arguments(options)
    configuration_keys = ranking_config.keys
    [ranking_config(**options.slice(*configuration_keys)), options.except(*configuration_keys)]
  end
end

RSpec.configure do |config|
  config.include Builders
end
