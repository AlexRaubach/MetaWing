module Generators
  module JSON
    class ShipsGenerator
      class << self

        def generate_ships(context, ships, ship_pilots, ids = [])
          ships.map.with_index do |ship, index|
            if ids.empty? || ids.map(&:to_i).include?(ship.id)
              generate_ship(context, ship, ship_pilots, index + 1)
            end
          end
        end

        private

        def generate_ship(context, ship, ship_pilots, position)
          {
            position:            position,
            id:                  ship.id,
            xws:                 ship.xws,
            name:                ship.name,
            link:                context.ship_url(ship.id, format: :json),
            pilots:              ship_pilots[ship.id].map do |pilot|
              {
                id:    pilot.id,
                name:  pilot.name,
                link:  context.pilot_url(pilot.id, format: :json),
              }
            end,
            squadron_count:      ship.squadrons,
            tournaments_count:   ship.tournaments,
            average_percentile: (ship.average_percentile * 10_000).to_i / 100.0,
            weight:              ship.weight,
            faction:             ship.faction_name
          }
        end

      end
    end
  end
end
