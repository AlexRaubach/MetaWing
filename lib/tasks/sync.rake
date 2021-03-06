require 'csv'

namespace :sync do

  desc 'reset_pilots'
  task reset_pilots: :environment do
    Importers::XwingData2.new.reset_pilots
  end

  desc 'xwing_data2'
  task xwing_data2: :environment do
    Importers::XwingData2.new.sync_all
  end

  desc 'list fortress remove deleted tournaments'
  task clean_tournaments: :environment do
    Importers::ListsJuggler.new.clean_tournaments()
  end

  desc 'list fortress delete tournament'
  task :tournament_delete, [:tournament_id] => :environment do |_t, args|
    tournament_id = args[:tournament_id].to_i
    Importers::ListsJuggler.new.remove_tournament(tournament_id)
  end

  desc 'lists fortress'
  task :tournaments, [:minimum_id] => :environment do |_t, args|
    Importers::ListsJuggler.new.sync_tournaments(minimum_id: args[:minimum_id].to_i, add_missing: false, use_updated: false)
  end

  desc 'lists fortress'
  task :tournaments_updated, [:minimum_id] => :environment do |_t, args|
    Importers::ListsJuggler.new.sync_tournaments(minimum_id: args[:minimum_id].to_i, add_missing: false, use_updated: true)
  end

  desc 'lists fortress, last month'
  task recent_tournaments: :environment do
    Importers::ListsJuggler.new.sync_tournaments(start_date: 1.month.ago.iso8601, add_missing: true)
  end

  desc 'rankings'
  task :rebuild_rankings, [:minimum_id] => :environment do |_t, args|
    Importers::Ranking.new.rebuild_all_ranking_data(minimum_id: args[:minimum_id].to_i)
  end

  desc 'rankings, last month'
  task rebuild_recent_rankings: :environment do
    Importers::Ranking.new.rebuild_all_ranking_data(start_date: 1.month.ago.iso8601)
  end

  desc 'enable sync mode'
  task enable: :environment do
    KeyValueStoreRecord.set!('syncing', true)
  end

  desc 'disable sync mode'
  task disable: :environment do
    KeyValueStoreRecord.set!('syncing', false)
    KeyValueStoreRecord.set!('last_sync', Time.current.iso8601)
  end

end
