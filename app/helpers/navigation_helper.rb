module NavigationHelper
  def nav_link_class(page, current_page)
    base = "flex items-center gap-3 px-3 py-2.5 text-sm font-medium rounded-lg transition-colors"
    if page == current_page
      "#{base} bg-primary-50 text-primary-700"
    else
      "#{base} text-gray-700 hover:bg-gray-100"
    end
  end

  def mobile_nav_link_class(page, current_page)
    if page == current_page
      "flex flex-col items-center justify-center text-primary-600"
    else
      "flex flex-col items-center justify-center text-gray-500"
    end
  end
end
