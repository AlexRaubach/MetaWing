module FilterHelper

  def show_filter?(controller, action)
    %w[ships pilots ship_combos upgrades squadrons].include?(controller) && %w[index show].include?(action)
  end

  def preset_dates
    [
      ['', nil],
      [I18n.t('shared.filter_configurator.dates.launch'), Date.new(2018, 9, 13)],
      [I18n.t('shared.filter_configurator.dates.wave_2'), Date.new(2018, 12,13)],
      [I18n.t('shared.filter_configurator.dates.jan_19_points_update'), Date.new(2019, 1, 28)],
      [I18n.t('shared.filter_configurator.dates.upsilon_nerf'), Date.new(2019, 2, 28)],
      [I18n.t('shared.filter_configurator.dates.wave_3'), Date.new(2019, 3, 20)],
      [I18n.t('shared.filter_configurator.dates.wave_4'), Date.new(2019, 7, 10)],
      [I18n.t('shared.filter_configurator.dates.wave_5'), Date.new(2019, 9, 13)],
      [I18n.t('shared.filter_configurator.dates.jan_20_points_update'), Date.new(2020, 1, 20)],
      [I18n.t('shared.filter_configurator.dates.wave_6'), Date.new(2020, 1, 31)],
      [I18n.t('shared.filter_configurator.dates.today'), Date.today],
    ]
  end

  def preset_ranking_data
    [
      [I18n.t('shared.filter_configurator.data_uses.swiss'), 'swiss'],
      [I18n.t('shared.filter_configurator.data_uses.elimination'), 'elimination'],
      [I18n.t('shared.filter_configurator.data_uses.all'), 'all'],
    ]
  end

end
