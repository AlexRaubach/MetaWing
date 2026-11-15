module MagicBarHelper
  # Rendered once per table row, so this is a helper rather than a partial
  def magic_bar(weight, max_weight)
    width = max_weight.present? && max_weight > 0 ? weight / max_weight * 100 : 100
    %(<div class="magic-bar-container"><div class="outer-bar"></div><div class="inner-bar" style="width: #{width.to_f}%"></div></div>).html_safe
  end
end
