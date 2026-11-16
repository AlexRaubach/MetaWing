require 'rails_helper'

RSpec.describe FontHelper, type: :helper do
  describe '#faction_icon' do
    {
      'First Order'         => 'firstorder',
      'Galactic Empire'     => 'empire',
      'Rebel Alliance'      => 'rebel',
      'Resistance'          => 'rebel-outline',
      'Scum and Villainy'   => 'scum',
      'Galactic Republic'   => 'republic',
      'Separatist Alliance' => 'separatists',
    }.each do |faction, icon|
      it "maps #{faction} to #{icon}" do
        expect(helper.faction_icon(faction)).to eq(icon)
      end
    end

    it 'raises for an unknown faction' do
      expect { helper.faction_icon('Hutt Cartel') }.to raise_error(RuntimeError, /Hutt Cartel/)
    end
  end

  describe '#ship_icon' do
    it 'translates the xws ids whose font glyph is named differently' do
      expect(helper.ship_icon('tieininterceptor')).to eq('tieinterceptor')
      expect(helper.ship_icon('upsilonclassshuttle')).to eq('upsilonclasscommandshuttle')
    end

    it 'uses the xws id as is otherwise' do
      expect(helper.ship_icon('t65xwing')).to eq('t65xwing')
    end
  end

  describe '#upgrade_type_icon' do
    it 'maps known upgrade types to their glyph names' do
      expect(helper.upgrade_type_icon('Talent')).to eq('talent')
      expect(helper.upgrade_type_icon('Configuration')).to eq('config')
      expect(helper.upgrade_type_icon('Force Power')).to eq('forcepower')
      expect(helper.upgrade_type_icon('Tactical Relay')).to eq('tacticalrelay')
    end

    it 'derives a glyph name for types it does not know' do
      expect(helper.upgrade_type_icon('Hardpoint')).to eq('hardpoint')
      expect(helper.upgrade_type_icon('Super  Laser')).to eq('superlaser')
    end
  end
end
