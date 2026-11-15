class UpgradeSide < ApplicationRecord
  # Sides imported before xwing-data2 dropped the `ffg` field still carry an
  # ffg id and point at dead fantasyflightgames.com image URLs. Sides synced
  # since then have no ffg id and current data, so prefer those.
  PREFERRED_ORDER_SQL = 'upgrade_sides.ffg IS NOT NULL, upgrade_sides.id'.freeze

  belongs_to :upgrade
  has_many :upgrade_side_slots
  has_many :upgrade_side_alts

  scope :preferred_first, -> { order(Arel.sql(PREFERRED_ORDER_SQL)) }
end
