module Importers
  class Ranking
    def initialize
      @all_ship_combos = ShipCombo.all.includes(:ships).to_a
    end

    def rebuild_all_ranking_data(minimum_id: nil, start_date: nil)
      begin
        Tournament.includes(:squadrons).all.each do |tournament|
          if minimum_id.nil? || tournament.lists_juggler_id >= minimum_id
            if start_date.nil? || tournament.date.nil? || tournament.date >= DateTime.parse(start_date.to_s).beginning_of_day
              build_ranking_data(tournament.lists_juggler_id)
            end
          end
        end
      rescue => e
        puts "Error rebuilding all ranking data with #{e.message}"
        puts e.backtrace
      end
    end

    def build_ranking_data(tournament_id)
      if (tournament_id % 50).zero?
        print "#{tournament_id}."
      else
        print '.'
      end
      tournament          = Tournament.find_by(lists_juggler_id: tournament_id)
      number_of_squadrons = [tournament.num_players, tournament.squadrons.count].compact.max
      ignore_cut          = tournament.squadrons.select { |s| s.elimination_standing.present? }.count.in?([0, number_of_squadrons])
      number_in_cut       = tournament.squadrons.map { |s| s.elimination_standing }.compact.max
      ignore_cut          ||= number_in_cut == 0
      unless ignore_cut
        number_in_cut = 2**(Math.log(number_in_cut, 2).ceil(0)) # round up to the next power of two
      end
      tournament.squadrons.each do |squadron|
        if squadron.swiss_standing.present? && squadron.swiss_standing > 0
          squadron.swiss_percentile = [(number_of_squadrons.to_f - squadron.swiss_standing.to_f + 1) / number_of_squadrons.to_f, 0].max
        end
        if !ignore_cut && squadron.elimination_standing.present? && squadron.elimination_standing > 0 && number_in_cut > 0
          squadron.elimination_percentile = [(number_in_cut.to_f - squadron.elimination_standing.to_f + 1) / number_in_cut.to_f, 0].max
        end
        ship_combo = find_or_create_ship_combo(squadron.ships)
        ship_combo.squadrons << squadron
        squadron.save!
      end
      squadron_win_loss_rations = Hash[tournament.squadrons.map do |squadron|
        [squadron, { swiss_wins: 0, swiss_losses: 0, elimination_wins: 0, elimination_losses: 0 }]
      end]
      tournament.games.each do |game|
        game.round_type = 'swiss' unless %w[swiss elimination].include?(game.round_type)
        game.update({
                      winning_combo: game.winning_squadron.ship_combo,
                      losing_combo:  game.losing_squadron.ship_combo,
                    })
        squadron_win_loss_rations[game.winning_squadron]["#{game.round_type}_wins".to_sym]  += 1
        squadron_win_loss_rations[game.losing_squadron]["#{game.round_type}_losses".to_sym] += 1
      end
      squadron_win_loss_rations.each do |squadron, results|
        %w[swiss elimination].each do |type|
          wins   = results["#{type}_wins".to_sym]
          losses = results["#{type}_losses".to_sym]
          if (wins > 0) || (losses > 0)
            ratio = wins.to_f / (wins.to_f + losses.to_f)
            squadron.update("win_loss_ratio_#{type}".to_sym => ratio)
          else
            squadron.update("win_loss_ratio_#{type}".to_sym => nil)
          end
        end
      end
    end

    def find_or_create_ship_combo(ships)
      found_combo = @all_ship_combos.detect do |potential_combo|
        potential_combo.ships.map(&:id).sort == ships.map(&:id).sort
      end
      return found_combo if found_combo.present?

      new_combo = ShipCombo.create!(ships: ships)
      @all_ship_combos << new_combo
      new_combo
    end
  end
end
