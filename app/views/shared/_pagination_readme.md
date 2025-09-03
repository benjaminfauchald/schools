# Enhanced Pagination System

## Overview

This enhanced pagination system replaces the basic Kaminari pagination with a comprehensive, user-friendly solution that follows Tailwind CSS and Flowbite best practices.

## Features

### 🎨 Visual Enhancements
- **Modern Design**: Clean, professional appearance with proper visual hierarchy
- **Hover Effects**: Subtle animations and state changes for better interaction feedback
- **Loading States**: Visual feedback during page transitions
- **Responsive Design**: Optimized layouts for mobile and desktop

### 🚀 Functionality Improvements
- **Per-page Selection**: Choose from 25, 50, 100, or 200 results per page
- **Quick Jump**: Direct page navigation input for large datasets
- **Smart Navigation**: First/Last page buttons for datasets with many pages
- **Enhanced Information**: Clear display of current range and total results

### 📱 Mobile Optimization
- **Compact Mobile View**: Essential controls only on small screens
- **Touch-friendly**: Appropriately sized buttons and controls
- **Page Selector**: Dropdown for easy page selection on mobile

### ♿ Accessibility Features
- **ARIA Labels**: Screen reader support throughout
- **Keyboard Navigation**: Full keyboard accessibility
- **High Contrast**: Clear visual distinctions for all states
- **Focus Management**: Proper focus indicators and behavior

## Usage

### Basic Implementation

```erb
<%= render 'shared/enhanced_pagination', collection: @schools %>
```

### Advanced Implementation

```erb
<%= render 'shared/enhanced_pagination', 
      collection: @schools,
      total_count: @filtered_count,
      per_page_options: [25, 50, 100, 200],
      container_classes: 'mt-6',
      ajax_target: 'schools' %>
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `collection` | Kaminari Collection | Required | The paginated collection |
| `total_count` | Integer | `collection.total_count` | Total number of items |
| `per_page_options` | Array | `[25, 50, 100, 200]` | Available per-page options |
| `container_classes` | String | `""` | Additional CSS classes |
| `ajax_target` | String | `nil` | Stimulus target for AJAX updates |

## Controller Integration

### Required Changes

```ruby
def filter_params
  params.permit(:radius, :show_all, :page, :per_page).tap do |p|
    # ... other params
    p[:per_page] = [p[:per_page]&.to_i || 25, 200].min.clamp(10, 200)
  end
end

def filtered_schools
  # Use @filter_params[:per_page] instead of hardcoded value
  School.published
        .page(@filter_params[:page])
        .per(@filter_params[:per_page])
end
```

## File Structure

```
app/
├── views/
│   ├── shared/
│   │   └── _enhanced_pagination.html.erb     # Main component
│   └── kaminari/
│       ├── enhanced_desktop/                 # Desktop theme
│       │   ├── _paginator.html.erb
│       │   ├── _page.html.erb
│       │   ├── _prev_page.html.erb
│       │   ├── _next_page.html.erb
│       │   └── _gap.html.erb
│       └── mobile_enhanced/                  # Mobile theme
│           ├── _paginator.html.erb
│           ├── _prev_page.html.erb
│           └── _next_page.html.erb
└── javascript/
    └── controllers/
        └── enhanced_pagination_controller.js  # Stimulus controller
```

## Kaminari Themes

### Desktop Theme (`enhanced_desktop`)
- **Full Navigation**: Previous, pages, next, first/last buttons
- **Smart Ellipsis**: Shows gaps for large page counts
- **Page Information**: Current page and total pages display

### Mobile Theme (`mobile_enhanced`)
- **Simplified Navigation**: Previous/next buttons only
- **Page Selector**: Dropdown for direct page access
- **Current Page Display**: Clear indication of current position

## Styling

### CSS Classes Used
- **Tailwind CSS**: Complete styling with Tailwind utilities
- **Flowbite Compatible**: Follows Flowbite design patterns
- **Custom Enhancements**: Additional CSS for animations and transitions

### Key Style Features
- Smooth transitions and hover effects
- Loading state animations
- Focus indicators for accessibility
- Responsive breakpoints

## JavaScript Enhancement

### Stimulus Controller Features
- **Loading States**: Visual feedback during navigation
- **Input Validation**: Real-time validation for page jump
- **Error Handling**: User-friendly error messages
- **Auto-selection**: Input fields auto-select for easy editing

### Methods Available
- `goToFirstPage()`: Navigate to first page
- `goToLastPage()`: Navigate to last page
- `goToPreviousPage()`: Navigate to previous page
- `goToNextPage()`: Navigate to next page

## Browser Support

- **Modern Browsers**: Full support for Chrome, Firefox, Safari, Edge
- **Progressive Enhancement**: Graceful degradation for older browsers
- **Mobile Browsers**: Optimized for mobile Safari and Chrome

## Performance Considerations

- **Minimal JavaScript**: Lightweight Stimulus controller
- **CSS Transitions**: Hardware-accelerated animations
- **Efficient Rendering**: Smart template rendering logic

## Customization

### Per-page Options
Modify the `per_page_options` parameter to change available options:

```erb
<%= render 'shared/enhanced_pagination', 
      per_page_options: [10, 25, 50, 100] %>
```

### Styling Customization
Override CSS classes in your application stylesheet:

```css
.pagination-link {
  /* Custom styling */
}
```

### Theme Customization
Create custom Kaminari themes by copying and modifying the existing templates.

## Testing

### Manual Testing Checklist
- [ ] Page navigation works correctly
- [ ] Per-page selection updates results
- [ ] Quick jump validates input properly
- [ ] Mobile view displays correctly
- [ ] Loading states show during transitions
- [ ] Accessibility features work with screen readers

### Browser Testing
- [ ] Chrome (latest)
- [ ] Firefox (latest)
- [ ] Safari (latest)
- [ ] Edge (latest)
- [ ] Mobile browsers (iOS Safari, Android Chrome)

## Troubleshooting

### Common Issues

**Pagination not updating**: Ensure controller accepts `per_page` parameter
**Styling issues**: Check that Tailwind CSS is properly loaded
**JavaScript errors**: Verify Stimulus is configured correctly

### Debug Steps

1. Check browser console for JavaScript errors
2. Verify Stimulus controller is connected
3. Ensure Kaminari themes are in correct directories
4. Validate controller parameter handling