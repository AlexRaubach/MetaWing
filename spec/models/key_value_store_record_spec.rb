require 'rails_helper'

RSpec.describe KeyValueStoreRecord, type: :model do
  describe '.get' do
    it 'is nil for an unknown key' do
      expect(KeyValueStoreRecord.get('missing')).to be_nil
    end
  end

  describe '.set!' do
    it 'stores a value that .get reads back' do
      KeyValueStoreRecord.set!('xwing_data2_version', '2.0.1')

      expect(KeyValueStoreRecord.get('xwing_data2_version')).to eq('2.0.1')
    end

    it 'overwrites the existing record instead of adding another' do
      KeyValueStoreRecord.set!('maintenance', true)

      expect { KeyValueStoreRecord.set!('maintenance', false) }.not_to change(KeyValueStoreRecord, :count)
      expect(KeyValueStoreRecord.get('maintenance')).to be(false)
    end

    it 'round-trips structured JSON values' do
      KeyValueStoreRecord.set!('settings', { 'a' => [1, 2] })

      expect(KeyValueStoreRecord.get('settings')).to eq('a' => [1, 2])
    end
  end
end
