require 'rails_helper'

RSpec.describe DirectQuery do
  describe '.fetch_query' do
    before do
      create_ship('T-65 X-wing', xws: 't65xwing', size: 'small')
      create_ship('YT-1300', xws: 'yt1300', size: 'large')
    end

    it 'returns one result per row, keyed by the requested attribute names' do
      rows = Ship.fetch_query(Ship.order(:name), label: 'ships.name', key: 'ships.xws')

      expect(rows).to eq([
        { label: 'T-65 X-wing', key: 't65xwing' },
        { label: 'YT-1300', key: 'yt1300' },
      ])
    end

    it 'exposes the attributes as methods' do
      row = Ship.fetch_query(Ship.where(xws: 'yt1300'), label: 'ships.name', base_size: 'ships.size').first

      expect(row.label).to eq('YT-1300')
      expect(row.base_size).to eq('large')
    end

    it 'supports aggregate expressions' do
      row = Ship.fetch_query(Ship.all, total: 'count(*)').first

      expect(row.total).to eq(2)
    end
  end

  describe DirectQuery::ResultHash do
    subject(:result) { described_class.new(name: 'Luke', weight: nil) }

    it 'returns nil for a key that is present but nil' do
      expect(result.weight).to be_nil
    end

    it 'raises NoMethodError for unknown keys' do
      expect { result.missing }.to raise_error(NoMethodError)
    end
  end
end
