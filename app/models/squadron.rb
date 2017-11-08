class Squadron < ApplicationRecord

  belongs_to :tournament, optional: true
  belongs_to :ship_combo, optional: true

  has_many :ship_configurations, dependent: :destroy
  has_many :pilots, through: :ship_configurations
  has_many :ships, through: :pilots

  has_many :won_games, class_name: 'Game', foreign_key: :winning_squadron_id, inverse_of: :winning_squadron
  has_many :lost_games, class_name: 'Game', foreign_key: :losing_squadron_id, inverse_of: :losing_squadron

  def xws
    # remove proprietary XWS format extensions for export - if you need the raw proprietary format, use attributes['xws'] instead
    JSON.parse(attributes['xws'].to_json.gsub(/{"name":"([^"]+)","points":[\d]+}/, '"\1"'))
  end

end
