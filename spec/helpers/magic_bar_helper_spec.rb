require 'rails_helper'

RSpec.describe MagicBarHelper, type: :helper do
  def bar_width(weight, max_weight)
    helper.magic_bar(weight, max_weight)[/width: ([\d.]+)%/, 1].to_f
  end

  it 'sizes the bar relative to the maximum weight' do
    expect(bar_width(1.5, 3.0)).to eq(50.0)
    expect(bar_width(3.0, 3.0)).to eq(100.0)
  end

  it 'draws a full bar when there is no usable maximum' do
    expect(bar_width(1.5, nil)).to eq(100.0)
    expect(bar_width(1.5, 0)).to eq(100.0)
  end

  it 'returns html-safe markup' do
    html = helper.magic_bar(1, 2)

    expect(html).to be_html_safe
    expect(html).to include('class="magic-bar-container"', 'class="inner-bar"')
  end
end
